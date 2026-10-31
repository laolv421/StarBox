# Starbox static API v1

App clients read only these public JSON files (GitHub Pages or Cloudflare Pages).

## `meta.json`

```json
{
  "schema_version": 1,
  "generated_at": "2026-10-31T12:00:00Z",
  "item_count": 42,
  "source": "starbox-pipeline"
}
```

## `categories.json`

```json
{
  "schema_version": 1,
  "categories": [
    {
      "id": "productivity",
      "name_zh": "效率办公",
      "subtitle_zh": "把琐事变少，把时间留给重要的事",
      "icon": "checkmark.circle"
    }
  ]
}
```

## `feed.json`

```json
{
  "schema_version": 1,
  "generated_at": "2026-10-31T12:00:00Z",
  "items": [
    {
      "id": "excalidraw/excalidraw",
      "full_name": "excalidraw/excalidraw",
      "name": "excalidraw",
      "title_zh": "Excalidraw",
      "summary_zh": "手绘风格在线白板…",
      "bullets_zh": ["打开浏览器就能画", "手绘感，不显得死板", "可分享链接一起改"],
      "category_ids": ["design"],
      "topics": ["drawing", "whiteboard"],
      "stars": 90000,
      "stars_delta_7d": 120,
      "forks": 8000,
      "language": "TypeScript",
      "homepage": "https://excalidraw.com",
      "html_url": "https://github.com/excalidraw/excalidraw",
      "avatar_url": "https://avatars.githubusercontent.com/u/…",
      "description": "Virtual whiteboard…",
      "source": "curated",
      "scene": "画草图",
      "updated_at": "2026-10-30T00:00:00Z"
    }
  ]
}
```

### Field notes

| Field | Meaning |
|-------|---------|
| `source` | `curated` or `trending` |
| `stars_delta_7d` | Approximate weekly star gain when available; else `0` |
| `scene` | Everyday use-case label for “工具盒” filters |

Base URL (replace after Pages is enabled):

`https://<owner>.github.io/starbox/v1/`
