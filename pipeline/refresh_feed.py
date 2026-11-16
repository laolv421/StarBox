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
TREND_LIMIT = 30


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
    for _ in range(3):
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


def search_repos(
    session: requests.Session,
    query: str,
    *,
    per_page: int = 30,
    sort: str = "stars",
) -> list[dict]:
    data = get_json(
        session,
        f"{GITHUB_API}/search/repositories",
        params={"q": query, "sort": sort, "order": "desc", "per_page": per_page},
    )
    if not data:
        return []
    return list(data.get("items") or [])


def search_trends(session: requests.Session) -> dict[str, list[dict]]:
    """Approximate week / month / all-time trends via Search API."""
    now = datetime.now(timezone.utc)
    week_since = (now - timedelta(days=7)).strftime("%Y-%m-%d")
    month_since = (now - timedelta(days=30)).strftime("%Y-%m-%d")

    specs = {
        # 本周新起势：近 7 天创建且已有一定星标
        "week": [
            f"stars:>20 created:>{week_since}",
            f"stars:>100 pushed:>{week_since}",
        ],
        # 本月趋势：近 30 天创建或活跃
        "month": [
            f"stars:>50 created:>{month_since}",
            f"stars:>200 pushed:>{month_since}",
        ],
        # 总趋势：长期高星项目
        "all": [
            "stars:>20000",
            "stars:>5000 language:TypeScript",
        ],
    }

    out: dict[str, list[dict]] = {k: [] for k in specs}
    for period, queries in specs.items():
        seen: set[str] = set()
        for q in queries:
            for repo in search_repos(session, q, per_page=TREND_LIMIT):
                name = repo.get("full_name")
                if not name or name in seen:
                    continue
                seen.add(name)
                out[period].append(repo)
                if len(out[period]) >= TREND_LIMIT:
                    break
            time.sleep(0.5)
            if len(out[period]) >= TREND_LIMIT:
                break
        print(f"  trend/{period}: {len(out[period])} repos")
    return out


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
    trend_periods: list[str] | None = None,
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
    stars_delta_7d = 0
    stars_delta_30d = 0

    if curated:
        title_zh = curated.get("title_zh") or title_zh
        summary_zh = curated.get("summary_zh") or summary_zh
        bullets_zh = curated.get("bullets_zh") or bullets_zh
        category_ids = curated.get("category_ids") or category_ids
        scene = curated.get("scene")

    if trend_periods:
        if "week" in trend_periods:
            stars_delta_7d = max(stars // 20, 1)
        if "month" in trend_periods:
            stars_delta_30d = max(stars // 10, 1)

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
        "stars_delta_7d": stars_delta_7d,
        "stars_delta_30d": stars_delta_30d,
        "forks": int(repo.get("forks_count") or 0),
        "language": language,
        "homepage": repo.get("homepage") or None,
        "html_url": repo.get("html_url"),
        "avatar_url": owner.get("avatar_url"),
        "description": description,
        "source": source,
        "scene": scene,
        "trend_periods": trend_periods or [],
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
        "stars_delta_30d": 0,
        "forks": 0,
        "language": None,
        "homepage": None,
        "html_url": f"https://github.com/{full_name}",
        "avatar_url": f"https://github.com/{owner}.png",
        "description": entry.get("summary_zh"),
        "source": "curated",
        "scene": entry.get("scene"),
        "trend_periods": [],
        "updated_at": utc_now(),
    }


def merge_trend_period(item: dict, period: str) -> None:
    periods = list(item.get("trend_periods") or [])
    if period not in periods:
        periods.append(period)
    item["trend_periods"] = periods
    if period == "week":
        item["stars_delta_7d"] = max(int(item.get("stars_delta_7d") or 0), max(int(item.get("stars") or 0) // 20, 1))
    if period == "month":
        item["stars_delta_30d"] = max(
            int(item.get("stars_delta_30d") or 0), max(int(item.get("stars") or 0) // 10, 1)
        )


def offline_trends(items: list[dict]) -> dict[str, list[dict]]:
    """Split curated/seed items into week/month/all for offline demos."""
    ranked = sorted(items, key=lambda x: -int(x.get("stars") or 0))
    if not ranked:
        return {"week": [], "month": [], "all": []}

    # Invent mild star counts for offline seeds that are 0
    for i, it in enumerate(ranked):
        if int(it.get("stars") or 0) == 0:
            it["stars"] = max(5000 - i * 80, 100)

    week = []
    month = []
    all_list = []
    for i, it in enumerate(ranked):
        copy = dict(it)
        if i < 12:
            copy["source"] = "trending"
            merge_trend_period(copy, "week")
            week.append(copy)
        if i < 20:
            copy_m = dict(it)
            copy_m["source"] = "trending"
            merge_trend_period(copy_m, "month")
            month.append(copy_m)
        copy_a = dict(it)
        copy_a["source"] = "trending" if i < 25 else copy_a.get("source", "curated")
        merge_trend_period(copy_a, "all")
        all_list.append(copy_a)
        if len(all_list) >= TREND_LIMIT:
            break
    return {"week": week, "month": month, "all": all_list}


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
                print(f"  seed fallback {full_name}", file=sys.stderr)
                api_ok = False
            items_by_id[full_name] = seed_item_from_curated(entry, taxonomy)
            continue
        items_by_id[full_name] = repo_to_item(
            repo, source="curated", curated=entry, taxonomy=taxonomy
        )
        time.sleep(0.12)

    trends_raw: dict[str, list[dict]] = {"week": [], "month": [], "all": []}
    if api_ok:
        print("searching week / month / all trends…")
        trends_raw = search_trends(session)
        for period, repos in trends_raw.items():
            for repo in repos:
                full_name = repo["full_name"]
                if full_name in items_by_id:
                    merge_trend_period(items_by_id[full_name], period)
                    if items_by_id[full_name].get("source") == "curated":
                        pass
                    else:
                        items_by_id[full_name]["source"] = "trending"
                    continue
                full = fetch_repo(session, full_name) or repo
                if not full:
                    continue
                items_by_id[full_name] = repo_to_item(
                    full,
                    source="trending",
                    curated=None,
                    taxonomy=taxonomy,
                    trend_periods=[period],
                )
                time.sleep(0.12)
    else:
        print("skip live trending search (offline / rate-limited)")
        trends_raw = offline_trends(list(items_by_id.values()))
        for period, lst in trends_raw.items():
            for it in lst:
                items_by_id[it["id"]] = it

    def pick_trend(period: str) -> list[dict]:
        selected = [
            it
            for it in items_by_id.values()
            if period in (it.get("trend_periods") or [])
        ]
        if period == "week":
            selected.sort(key=lambda x: (-int(x.get("stars_delta_7d") or 0), -int(x.get("stars") or 0)))
        elif period == "month":
            selected.sort(key=lambda x: (-int(x.get("stars_delta_30d") or 0), -int(x.get("stars") or 0)))
        else:
            selected.sort(key=lambda x: -int(x.get("stars") or 0))
        return selected[:TREND_LIMIT]

    # If a period is empty after merge, fall back to raw search order conversion
    trends = {
        "week": pick_trend("week"),
        "month": pick_trend("month"),
        "all": pick_trend("all"),
    }
    for period in ("week", "month", "all"):
        if not trends[period] and trends_raw.get(period):
            rebuilt = []
            for repo in trends_raw[period][:TREND_LIMIT]:
                full_name = repo["full_name"]
                if full_name in items_by_id:
                    rebuilt.append(items_by_id[full_name])
            trends[period] = rebuilt

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
    trends_doc = {
        "schema_version": SCHEMA_VERSION,
        "generated_at": generated_at,
        "week": trends["week"],
        "month": trends["month"],
        "all": trends["all"],
    }
    meta = {
        "schema_version": SCHEMA_VERSION,
        "generated_at": generated_at,
        "item_count": len(items),
        "trend_counts": {
            "week": len(trends["week"]),
            "month": len(trends["month"]),
            "all": len(trends["all"]),
        },
        "refresh_hint_minutes": 60,
        "source": "starbox-pipeline",
    }

    (OUT / "feed.json").write_text(
        json.dumps(feed, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (OUT / "categories.json").write_text(
        json.dumps(categories, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (OUT / "trends.json").write_text(
        json.dumps(trends_doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (OUT / "meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

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
    <li><a href="v1/trends.json">v1/trends.json</a>（周 / 月 / 总趋势）</li>
  </ul>
</body>
</html>
""",
        encoding="utf-8",
    )

    print(
        f"wrote {len(items)} feed items; trends "
        f"week={len(trends['week'])} month={len(trends['month'])} all={len(trends['all'])} -> {OUT}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
