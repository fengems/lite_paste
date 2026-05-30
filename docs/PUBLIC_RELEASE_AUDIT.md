# Lite Paste 公开发布审计

记录时间：2026-05-30 23:44:55 CST

## 结论

Lite Paste 的核心剪贴板管理能力已经具备公开预览版基础，但“用户下载后无摩擦安装”的正式发布还缺少 Developer ID 签名证书和 Apple 公证凭据。没有这些条件时，可以生成本地 DMG，但其他用户首次打开会遇到 Gatekeeper 拦截，不符合成熟软件的安装预期。

## 已具备

- 菜单栏常驻、全局快捷键、卡片/列表面板、搜索、筛选、收藏、置顶、备注、删除和清空。
- 文本、URL、邮箱、颜色、文件、图片、HTML、RTF 捕获和恢复。
- 大历史分页读取、搜索下推、图片后台下采样和大内容处理。
- 停止监听、忽略应用、敏感 pasteboard type 过滤和本地优先数据策略。
- 本地备份和 iCloud Drive 备份，iCloud 侧只保留最新一份。
- 首次启动权限引导，说明快捷打开、本地隐私和自动粘贴权限用途。
- MIT License、公开 README、Developer ID 发布说明和发布环境预检脚本。

## 继续改进方向

- UI 国际化：当前 App 内文案以中文为主，公开面向全球用户时应补充英文本地化。
- 安装体验：拿到 Developer ID 和公证凭据后，生成签名并公证的 DMG，再在干净 macOS 用户环境做首次安装验证。
- 自动化测试：当前以核心检查和运行时烟测为主，后续可增加 Xcode UI 测试覆盖首次启动、权限引导和面板交互。
- 发布页资产：正式发布前建议补充面板截图和简短演示图，降低用户理解成本。

## 当前硬性阻塞

- `security find-identity -v -p codesigning` 只发现 `LitePaste Local Code Signing`，没有 `Developer ID Application` 证书。
- `xcrun notarytool history --keychain-profile litepaste-notary` 返回未找到 keychain profile。

## 正式发布所需命令

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
