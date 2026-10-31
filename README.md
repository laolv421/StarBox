# 星盒 Starbox

把 GitHub 上好用的开源工具与趋势，翻译成普通人能懂的话。  
**不自建服务器**：GitHub Actions 定时产出静态 JSON，iOS App 直读 Pages / 内置缓存。

## 仓库结构

```
data/           # 策展清单与类目（taxonomy / curated）
pipeline/       # 生成 site/v1/*.json 的脚本
site/v1/        # 静态 API（feed / categories / meta）
app/            # SwiftUI iOS（XcodeGen）
docs/api-v1.md  # 静态 API 约定
```

## 本地生成数据

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r pipeline/requirements.txt

# 有 GitHub Token 时拉取真实 star / 趋势
export GITHUB_TOKEN=ghp_xxx   # 可选；Actions 里用内置 GITHUB_TOKEN
python pipeline/refresh_feed.py

# 无网络或限流时
python pipeline/refresh_feed.py --offline
```

生成结果写入 `site/v1/`。把同一批 JSON 同步到 App 内置资源：

```bash
cp site/v1/*.json app/Starbox/Resources/
```

## 启用 GitHub Pages

1. 推送本仓库到 GitHub  
2. Settings → Pages → Source 选 **GitHub Actions**  
3. 手动跑一次 workflow **Refresh feed**  
4. 站点形如 `https://<user>.github.io/starbox/`，API 在 `/v1/`  

在 App「我的 → 数据源地址」填：`https://<user>.github.io/starbox/v1`

## 打开 iOS 工程

```bash
cd app
xcodegen generate
open Starbox.xcodeproj
```

- 目标：iOS 17+  
- 在 Xcode 里设置你的 **Team** / Bundle ID  
- 模拟器或真机 Run；无 Pages 时会自动用内置 `Resources/*.json`

## 产品 Tab

| Tab | 作用 |
|-----|------|
| 发现 | 趋势 / 热度工具流 |
| 分类 | 效率、AI、学习等普通人能懂的类目 |
| 工具盒 | 策展长青工具，可按场景筛选 |
| 我的 | 本机收藏、浏览记录、刷新与数据源 |

## TestFlight 前检查

- [ ] 填好 Development Team，Archive 成功  
- [ ] Pages 已部署且 App 能拉到最新 `meta.json`  
- [ ] 准备 1024×1024 App Icon  
- [ ] 文案确认：写「定时更新」，不承诺秒级实时  
- [ ] 隐私说明：无账号；收藏仅本机  

## 许可

策展与 App 代码以本仓库为准；各开源项目版权归原作者，星盒仅做发现与解读。
