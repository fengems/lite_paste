# Lite Paste

Lite Paste 是一个原生 macOS 剪贴板管理器，目标是提供接近 Paste 的视觉体验、Maccy 的轻量效率，以及隐私优先的本地数据策略。

当前项目已具备 SwiftPM 可运行入口，并提供本地 `.app` bundle 打包脚本。正式 Xcode target 的配置基线放在 `Config/LitePaste/`。

## 当前能力

- 菜单栏常驻应用骨架。
- 菜单栏右键菜单可打开面板、打开设置和退出应用。
- 可配置全局快捷键唤起浮动面板，默认 `⌘⇧V`。
- 卡片模式和列表模式，面板内切换会同步为默认视图。
- 卡片模式使用懒加载布局，降低大量历史下的首屏渲染压力。
- 面板历史列表默认分页读取，搜索、筛选和排序变化后按需加载更多记录。
- 应用启动默认只加载首屏历史，隐藏记录仍可通过仓库查询、去重和更新。
- 面板键盘浏览：方向键切换选中项、回车粘贴、`⌘C` 复制、Delete 删除、Escape 关闭。
- 置顶条目可分配 `⌘⌥1` 到 `⌘⌥9` 快捷键快速粘贴，快捷键注册和触发会按需从仓库查询置顶记录。
- 文本、URL、邮箱、颜色、文件、图片、HTML、RTF 捕获，payload 构建、捕获优先级和入库门禁有核心检查覆盖。
- 搜索、筛选、排序、收藏、置顶、备注、删除、清空历史，清空操作带二次确认，核心检查覆盖 5,000 条历史搜索。
- 图片、文件、颜色、富文本和 HTML 预览，文件预览会标记已移动或删除的路径，富文本/HTML 会尽量保留样式，富媒体使用外部 blob 存储。
- 复制回剪贴板和自动粘贴到上一个应用，恢复计划覆盖文本、文件、图片和富文本原格式。
- Lite Paste 自写入剪贴板会被监控器忽略，避免循环记录。
- 默认视图、面板位置、搜索自动聚焦、默认纯文本、粘贴后恢复剪贴板、重复内容处理、记录类型、最大历史数量、保留天数等运行设置。
- 面板快捷键、最大历史数量和保留天数会做边界规范化，避免导入异常设置破坏运行状态。
- 私密模式、默认忽略密码管理器、忽略应用、忽略剪贴板类型等隐私设置，支持一键忽略最近使用的应用。
- Accessibility 未授权时降级为复制并提示，设置页提供权限状态、请求授权和打开系统设置入口。
- 文件在 Finder 中显示、URL 打开浏览器、邮箱打开邮件、图片导出。
- 本地 SQLite 历史持久化，旧 `history.json` 会在首次读取时自动迁移。
- SQLite 仓库层支持搜索、筛选、排序和 limit 下推，并提供数据库维护入口。
- SQLite 仓库层已具备按 ID/hash 查找、单条 upsert、单条删除和清空的增量写入基础能力。
- `HistoryStore` 已优先使用增量写入路径，普通仓库仍保留整表保存 fallback。
- 历史去重、持久化加载清理和外部 blob 删除行为有核心检查覆盖。
- 本地备份导入导出，导入前校验备份完整性，导入后自动刷新历史和设置，外部 blob 路径随备份位置重写。
- 开机启动设置接入。
- 菜单栏使用项目内绘制的 template 图标，本地 `.app` bundle 打包脚本会生成 AppIcon 并执行 ad-hoc 签名，发布脚本可生成 zip 和 DMG 试用包。

## 本地运行

当前环境可以用 Swift Package 直接运行：

```bash
swift run LitePaste
```

也可以打包成本地可打开的 `.app`：

```bash
Scripts/build_app_bundle.sh
open Build/LitePaste.app
```

生成本地试用 zip 和 DMG 包：

```bash
Scripts/package_release.sh
```

核心检查和编译：

```bash
swift run LitePasteCoreChecks
swift build
```

本地发布前完整验证：

```bash
Scripts/verify_release.sh
```

## 环境说明

当前开发机只有 Command Line Tools，`xcodebuild` 和 XCTest/Swift Testing 模块不可用。仓库内的 `Scripts/build_app_bundle.sh` 会用 SwiftPM release 产物组装本地 `.app` 并进行 ad-hoc 签名，适合本机试用。

正式 Xcode target、Developer ID 签名、公证和发布打包需要完整 Xcode：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

正式 App target 接入说明见：

- `docs/MACOS_APP_TARGET.md`
- `docs/RELEASE_CHECKLIST.md`
- `docs/DEVELOPER_ID_RELEASE.md`

产品需求文档见：

- `docs/PRD.md`

## 数据位置

运行时数据保存在用户 Application Support 目录：

- `~/Library/Application Support/LitePaste/history.sqlite3`
- `~/Library/Application Support/LitePaste/history.json`（旧版本遗留文件，首次读取后迁移）
- `~/Library/Application Support/LitePaste/settings.json`
- `~/Library/Application Support/LitePaste/Blobs/`

## 下一步

- 创建并验证完整 Xcode `.app` target。
- 补正式发布视觉资源。
- 完善图片、文件和富文本预览细节。
- 补充真正的单元测试和 UI 测试。
