#!/usr/bin/env python3
"""Build starbox static v1 JSON from curated YAML + GitHub API."""

from __future__ import annotations

import json
import os
import re
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import requests
import yaml

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
OUT = ROOT / "site" / "v1"
SCHEMA_VERSION = 1

GITHUB_API = "https://api.github.com"
USER_AGENT = "starbox-pipeline/1.0"


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_yaml(path: Path) -> Any:
    with path.open(encoding="utf-8") as f:
        return yaml.safe_load(f)


def github_session() -> requests.Session:
    s = requests.Session()
    s.headers.update(
        {
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": USER_AGENT,
        }
    )
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        s.headers["Authorization"] = f"Bearer {token}"
    return s


def get_json(session: requests.Session, url: str, params: dict | None = None) -> Any:
    for attempt in range(3):
        r = session.get(url, params=params, timeout=30)
        if r.status_code == 403 and "rate limit" in r.text.lower():
            remaining = r.headers.get("X-RateLimit-Remaining", "?")
            print(
                f"rate limited (remaining={remaining}), skip further GitHub calls",
                file=sys.stderr,
            )
            return None
        if r.status_code >= 400:
            print(f"GET {url} -> {r.status_code}: {r.text[:200]}", file=sys.stderr)
            return None
        return r.json()
    return None


def fetch_repo(session: requests.Session, full_name: str) -> dict | None:
    return get_json(session, f"{GITHUB_API}/repos/{full_name}")


def search_trending(session: requests.Session, per_page: int = 25) -> list[dict]:
    """Approximate trending via recently created high-star repos + recently pushed popular repos."""
    items: list[dict] = []
    seen: set[str] = set()
    now = datetime.now(timezone.utc)
    created_since = (now - timedelta(days=60)).strftime("%Y-%m-%d")
    pushed_since = (now - timedelta(days=14)).strftime("%Y-%m-%d")
    queries = [
        f"stars:>50 created:>{created_since}",
        f"stars:>500 pushed:>{pushed_since}",
    ]
    for q in queries:
        data = get_json(
            session,
            f"{GITHUB_API}/search/repositories",
            params={"q": q, "sort": "stars", "order": "desc", "per_page": per_page},
        )
        if not data:
            continue
        for repo in data.get("items", []):
            name = repo.get("full_name")
            if not name or name in seen:
                continue
            seen.add(name)
            items.append(repo)
        time.sleep(0.4)
    return items


def topic_to_categories(topics: list[str], taxonomy: dict) -> list[str]:
    topics_l = {t.lower() for t in topics}
    matched: list[str] = []
    for cat in taxonomy.get("categories", []):
        cat_topics = {t.lower() for t in cat.get("topics", [])}
        if topics_l & cat_topics:
            matched.append(cat["id"])
    return matched or ["developer"]


def template_summary(name: str, description: str | None, topics: list[str]) -> str:
    desc = (description or "").strip()
    if desc:
        # Keep short for non-technical readers
        desc = re.sub(r"\s+", " ", desc)
        if len(desc) > 80:
            desc = desc[:77] + "…"
        return f"{name}：{desc}"
    if topics:
        return f"{name} 是一个与「{'、'.join(topics[:3])}」相关的开源项目，值得关注。"
    return f"{name} 是 GitHub 上正在受到关注的开源项目。"


def template_bullets(stars: int, language: str | None, topics: list[str]) -> list[str]:
    bullets = []
    if stars >= 1000:
        bullets.append(f"已有超过 {stars:,} 人星标，说明很多人在用或关注")
    elif stars > 0:
        bullets.append(f"目前约有 {stars} 个星标")
    else:
        bullets.append("新兴项目，可以先看看介绍再决定")
    if language:
        bullets.append(f"主要使用 {language} 开发")
    if topics:
        bullets.append(f"标签：{'、'.join(topics[:4])}")
    else:
        bullets.append("打开项目主页可了解详细用法")
    return bullets[:3]


def repo_to_item(
    repo: dict,
    *,
    source: str,
    curated: dict | None,
    taxonomy: dict,
) -> dict:
    full_name = repo["full_name"]
    name = repo.get("name") or full_name.split("/")[-1]
    topics = repo.get("topics") or []
    description = repo.get("description")
    stars = int(repo.get("stargazers_count") or 0)
    language = repo.get("language")
    owner = repo.get("owner") or {}

    title_zh = name
    summary_zh = template_summary(name, description, topics)
    bullets_zh = template_bullets(stars, language, topics)
    category_ids = topic_to_categories(topics, taxonomy)
    scene = None
    stars_delta = 0

    if curated:
        title_zh = curated.get("title_zh") or title_zh
        summary_zh = curated.get("summary_zh") or summary_zh
        bullets_zh = curated.get("bullets_zh") or bullets_zh
        category_ids = curated.get("category_ids") or category_ids
        scene = curated.get("scene")

    return {
        "id": full_name,
        "full_name": full_name,
        "name": name,
        "title_zh": title_zh,
        "summary_zh": summary_zh,
        "bullets_zh": bullets_zh,
        "category_ids": category_ids,
        "topics": topics,
        "stars": stars,
        "stars_delta_7d": stars_delta,
        "forks": int(repo.get("forks_count") or 0),
        "language": language,
        "homepage": repo.get("homepage") or None,
        "html_url": repo.get("html_url"),
        "avatar_url": owner.get("avatar_url"),
        "description": description,
        "source": source,
        "scene": scene,
        "updated_at": repo.get("updated_at") or repo.get("pushed_at") or utc_now(),
    }


def build_categories(taxonomy: dict) -> list[dict]:
    out = []
    for cat in taxonomy.get("categories", []):
        out.append(
            {
                "id": cat["id"],
                "name_zh": cat["name_zh"],
                "subtitle_zh": cat.get("subtitle_zh", ""),
                "icon": cat.get("icon", "square.grid.2x2"),
            }
        )
    return out


def seed_item_from_curated(entry: dict, taxonomy: dict) -> dict:
    """Offline fallback when GitHub API is unavailable."""
    full_name = entry["full_name"]
    name = full_name.split("/")[-1]
    owner = full_name.split("/")[0]
    topics: list[str] = []
    category_ids = entry.get("category_ids") or ["developer"]
    title_zh = entry.get("title_zh") or name
    summary_zh = entry.get("summary_zh") or template_summary(name, None, topics)
    bullets_zh = entry.get("bullets_zh") or template_bullets(0, None, topics)
    return {
        "id": full_name,
        "full_name": full_name,
        "name": name,
        "title_zh": title_zh,
        "summary_zh": summary_zh,
        "bullets_zh": bullets_zh,
        "category_ids": category_ids,
        "topics": topics,
        "stars": 0,
        "stars_delta_7d": 0,
        "forks": 0,
        "language": None,
        "homepage": None,
        "html_url": f"https://github.com/{full_name}",
        "avatar_url": f"https://github.com/{owner}.png",
        "description": entry.get("summary_zh"),
        "source": "curated",
        "scene": entry.get("scene"),
        "updated_at": utc_now(),
    }


def main() -> int:
    offline = "--offline" in sys.argv or os.environ.get("STARBOX_OFFLINE") == "1"
    taxonomy = load_yaml(DATA / "taxonomy.yaml")
    curated_doc = load_yaml(DATA / "curated.yaml")
    curated_items = curated_doc.get("items") or []

    session = github_session()
    items_by_id: dict[str, dict] = {}
    api_ok = not offline

    print(f"fetching {len(curated_items)} curated repos…")
    for entry in curated_items:
        full_name = entry["full_name"]
        repo = fetch_repo(session, full_name) if api_ok else None
        if not repo:
            if api_ok:
                # First hard failure after successes may be rate limit; switch to seed
                print(f"  seed fallback {full_name}", file=sys.stderr)
                api_ok = False
            items_by_id[full_name] = seed_item_from_curated(entry, taxonomy)
            continue
        items_by_id[full_name] = repo_to_item(
            repo, source="curated", curated=entry, taxonomy=taxonomy
        )
        time.sleep(0.15)

    if api_ok:
        print("searching approximate trending…")
        for repo in search_trending(session):
            full_name = repo["full_name"]
            if full_name in items_by_id:
                items_by_id[full_name]["stars_delta_7d"] = max(
                    items_by_id[full_name].get("stars_delta_7d", 0), 1
                )
                continue
            full = fetch_repo(session, full_name) or repo
            if not full:
                break
            items_by_id[full_name] = repo_to_item(
                full, source="trending", curated=None, taxonomy=taxonomy
            )
            time.sleep(0.15)
    else:
        print("skip trending search (offline / rate-limited)")

    items = sorted(
        items_by_id.values(),
        key=lambda x: (0 if x["source"] == "curated" else 1, -x["stars"]),
    )
    generated_at = utc_now()

    OUT.mkdir(parents=True, exist_ok=True)
    feed = {
        "schema_version": SCHEMA_VERSION,
        "generated_at": generated_at,
        "items": items,
    }
    categories = {
        "schema_version": SCHEMA_VERSION,
        "categories": build_categories(taxonomy),
    }
    meta = {
        "schema_version": SCHEMA_VERSION,
        "generated_at": generated_at,
        "item_count": len(items),
        "source": "starbox-pipeline",
    }

    (OUT / "feed.json").write_text(
        json.dumps(feed, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (OUT / "categories.json").write_text(
        json.dumps(categories, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (OUT / "meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    # GitHub Pages root helper
    (ROOT / "site" / "index.html").write_text(
        """<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <title>星盒 Starbox Data</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    body { font-family: system-ui, sans-serif; max-width: 40rem; margin: 3rem auto; padding: 0 1rem; line-height: 1.6; }
    a { color: #0b57d0; }
  </style>
</head>
<body>
  <h1>星盒 · 静态数据</h1>
  <p>iOS App 读取的公开 JSON：</p>
  <ul>
    <li><a href="v1/meta.json">v1/meta.json</a></li>
    <li><a href="v1/categories.json">v1/categories.json</a></li>
    <li><a href="v1/feed.json">v1/feed.json</a></li>
  </ul>
</body>
</html>
""",
        encoding="utf-8",
    )

    print(f"wrote {len(items)} items -> {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
