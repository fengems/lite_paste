# Lite Paste 公开发布审计

记录时间：2026-05-31 08:08:57 CST

## 结论

Lite Paste 的核心剪贴板管理能力已经具备公开预览版基础。当前因没有 Apple Developer Program 预算，公开发布策略调整为源码发布：GitHub Release 只提供源码归档和本地构建说明，不提供面向普通用户的一键安装 DMG。

“用户下载后无摩擦安装”的正式二进制发布仍需要 Developer ID 签名证书和 Apple 公证凭据；在没有这些条件时，不应把本地 DMG 当作正式安装包发布。

## 已具备

- 菜单栏常驻、全局快捷键、卡片/列表面板、搜索、筛选、收藏、置顶、备注、删除和清空。
- 文本、URL、邮箱、颜色、文件、图片、HTML、RTF 捕获和恢复。
- 大历史分页读取、搜索下推、图片后台下采样和大内容处理。
- 停止监听、忽略应用、敏感 pasteboard type 过滤和本地优先数据策略。
- 本地备份和 iCloud Drive 备份，iCloud 侧只保留最新一份。
- 首次启动权限引导，说明快捷打开、本地隐私和自动粘贴权限用途。
- MIT License、公开 README、Developer ID 发布说明、发布环境预检脚本、GitHub Actions 正式发布流水线和 GitHub 发布就绪检查脚本。
- 源码发布检查和创建脚本，支持无 Apple Developer Program 预算时发布 source-only GitHub Release。

## 继续改进方向

- UI 国际化：首次引导、菜单栏、剪贴板面板、设置页和关键弹窗已补充中英文文案；后续仍应把底层错误恢复建议和完整帮助文案迁移到标准 `.lproj` 资源。
- 安装体验：当前源码发布只面向开发者和测试用户；配置 Developer ID 与 Apple 公证 secrets 后，再使用 GitHub Actions 生成签名并公证的 DMG，并在干净 macOS 用户环境做首次安装验证。
- 自动化测试：当前以核心检查和运行时烟测为主，后续可增加 Xcode UI 测试覆盖首次启动、权限引导和面板交互。
- 发布页资产：正式发布前建议补充面板截图和简短演示图，降低用户理解成本。

## 当前硬性阻塞

- 正式二进制安装包仍缺少 Apple Developer Program、`Developer ID Application` 证书和 Apple 公证凭据。
- 源码发布不受上述条件阻塞。

## 源码发布命令

```bash
Scripts/check_source_release_ready.sh
Scripts/create_source_release.sh
```

## 未来正式二进制发布所需命令

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
TEAM_ID="TEAMID" \
NOTARY_PROFILE="litepaste-notary" \
Scripts/check_distribution_ready.sh

DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
TEAM_ID="TEAMID" \
NOTARY_PROFILE="litepaste-notary" \
Scripts/sign_notarize_release.sh
```

也可以在 GitHub 仓库配置发布 secrets 后，从 `Actions > Release > Run workflow` 触发正式签名、公证和 GitHub Release 发布。
