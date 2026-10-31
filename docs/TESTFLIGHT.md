# TestFlight 准备清单

## 工程

1. `cd app && xcodegen generate && open Starbox.xcodeproj`
2. Signing & Capabilities → 选择你的 **Team**
3. 按需修改 Bundle ID（默认 `com.starbox.app`）
4. 替换 `Assets.xcassets/AppIcon.appiconset/AppIcon.png` 为正式 1024×1024 图标
5. Product → Archive → Distribute App → TestFlight

## 数据

1. 将仓库推到 GitHub，Settings → Pages → Source = **GitHub Actions**
2. 手动运行 workflow **Refresh feed**
3. 确认可打开：`https://<user>.github.io/starbox/v1/meta.json`
4. 在 App「我的 → 数据源地址」填写：`https://<user>.github.io/starbox/v1`

## 合规文案

- 对外说明使用「定时更新的趋势」，不要写「实时秒级」
- 隐私：无账号、无追踪；收藏与浏览记录仅本机
- 外链打开 GitHub / 项目主页；不托管第三方内容文件

## 本机验证

```bash
cd app
xcodegen generate
# 模拟器（若本机 codesign 异常，可在 Xcode GUI 直接 Run）
xcodebuild -project Starbox.xcodeproj -scheme Starbox \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
