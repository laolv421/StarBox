# Starbox static API v1

App clients read only these public JSON files (GitHub Pages or Cloudflare Pages).

Base URL example: `https://laolv421.github.io/StarBox/v1/`

## `meta.json`

```json
{
  "schema_version": 1,
  "generated_at": "2026-11-16T12:00:00Z",
  "item_count": 90,
  "trend_counts": { "week": 30, "month": 30, "all": 30 },
  "refresh_hint_minutes": 60,
  "source": "starbox-pipeline"
}
```

`refresh_hint_minutes`：客户端超过该分钟数应自动再拉一次。

## `categories.json`

类目列表（效率办公、AI 等）。

## `feed.json`

策展工具 + 趋势条目的合集，供分类 / 工具盒 / 详情查找。

新增可选字段：

| Field | Meaning |
|-------|---------|
| `stars_delta_30d` | 近月热度近似 |
| `trend_periods` | `["week"]` / `["month"]` / `["all"]` 等 |

## `trends.json`

发现页专用：周 / 月 / 总三份列表。

```json
{
  "schema_version": 1,
  "generated_at": "2026-11-16T12:00:00Z",
  "week": [ /* RepoItem */ ],
  "month": [ /* RepoItem */ ],
  "all": [ /* RepoItem */ ]
}
```

- **week**：近 7 天新起势 / 高活跃
- **month**：近 30 天升温
- **all**：长期高星综合热度

流水线默认每小时刷新一次（GitHub Actions cron）。
