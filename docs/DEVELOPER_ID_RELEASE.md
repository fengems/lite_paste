# Lite Paste Developer ID 发布流程

本文档记录 Lite Paste 从本地试用包升级到 Developer ID 签名和公证发布包的命令行流程。Apple 官方要求直接分发的 macOS 软件使用 Developer ID 签名，并建议提交到 Apple notary service；公证上传应使用 Xcode 附带的 `notarytool`，可用 `stapler` 把票据附加到分发物。

参考：

- [Signing Mac Software with Developer ID](https://developer.apple.com/developer-id/)
- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Customizing the notarization workflow](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow)
- [Hardened Runtime](https://developer.apple.com/documentation/Security/hardened-runtime)

## 1. 前置条件

- 安装完整 Xcode，并切换命令行工具：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

- Apple Developer Program 账号。
- 本机钥匙串中存在 `Developer ID Application` 证书。
- 有 App Store Connect app-specific password，或已保存的 `notarytool` keychain profile。

查看可用证书：

```bash
security find-identity -v -p codesigning
```

保存公证凭据到钥匙串：

```bash
xcrun notarytool store-credentials litepaste-notary \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

## 2. 一键签名和公证

发布前先运行环境预检，避免生成本机能打开、其他用户无法顺畅安装的包：

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
TEAM_ID="TEAMID" \
NOTARY_PROFILE="litepaste-notary" \
Scripts/check_distribution_ready.sh
```

推荐使用 keychain profile：

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
TEAM_ID="TEAMID" \
NOTARY_PROFILE="litepaste-notary" \
VERSION=0.1.0 \
BUILD=1 \
Scripts/sign_notarize_release.sh
```

也可以直接通过环境变量传入公证凭据：

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
APPLE_ID="you@example.com" \
APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
TEAM_ID="TEAMID" \
VERSION=0.1.0 \
BUILD=1 \
Scripts/sign_notarize_release.sh
```

脚本会执行：

- 检查 Developer ID 证书、iCloud entitlement 团队前缀和公证凭据。
- 重新构建 `Build/LitePaste.app`。
- 使用 Developer ID、Hardened Runtime 和 `Config/LitePaste/LitePaste.entitlements` 重签名。
- 生成 zip、DMG 和 SHA-256 校验文件。
- 使用 Developer ID 签名 DMG。
- 提交 DMG 到 Apple notary service。
- 对 DMG 执行 `stapler staple` 和 `stapler validate`。
- 在所有签名和 staple 操作完成后重新生成 SHA-256 校验文件。

## 3. 只生成 Developer ID 签名包

在调试证书或离线环境中，可以跳过公证：

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
TEAM_ID="TEAMID" \
NOTARIZE=0 \
Scripts/sign_notarize_release.sh
```

此模式生成的包仍不是最终用户发布包，只适合检查签名、entitlements 和打包流程。

## 4. 发布前验证

签名和公证完成后至少执行：

```bash
codesign --verify --deep --strict --verbose=2 Build/LitePaste.app
hdiutil verify Build/LitePaste-0.1.0-1.dmg
xcrun stapler validate Build/LitePaste-0.1.0-1.dmg
spctl --assess --type open --verbose=4 Build/LitePaste-0.1.0-1.dmg
shasum -a 256 -c Build/LitePaste-0.1.0-1.zip.sha256
shasum -a 256 -c Build/LitePaste-0.1.0-1.dmg.sha256
```

如果公证失败，先查看 notarytool 输出中的 submission id，再拉取日志：

```bash
xcrun notarytool log SUBMISSION_ID --keychain-profile litepaste-notary
```

## 5. 创建 GitHub Release

### 5.1 使用 GitHub Actions 发布

仓库提供手动触发的 `Release` workflow。适合在本机没有 Developer ID 证书，但仓库已经配置好发布 secrets 时使用。

需要先在 GitHub 仓库 `Settings > Secrets and variables > Actions` 配置：

- `DEVELOPER_ID_APPLICATION`：完整签名身份，例如 `Developer ID Application: Your Name (TEAMID)`。
- `DEVELOPER_ID_CERTIFICATE_BASE64`：导出的 `.p12` 证书文件 base64 内容。
- `DEVELOPER_ID_CERTIFICATE_PASSWORD`：导出 `.p12` 时设置的密码。
- `APPLE_ID`：Apple Developer 账号邮箱。
- `APP_SPECIFIC_PASSWORD`：Apple ID app-specific password。
- `APPLE_TEAM_ID`：Apple Developer Team ID。

生成证书 secret 的示例：

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
```

发布前要求：

- 版本号和构建号已经提交到 `Config/LitePaste/Info.plist` 和 `Sources/LitePasteCore/AppMetadata.swift`。
- `main` 已经推送到 GitHub。
- 发布说明文件存在，例如 `docs/releases/0.1.2.md`。
- `Actions > Release > Run workflow` 必须从 `main` 运行。

workflow 会执行：

- 导入 Developer ID `.p12` 到临时 keychain。
- 保存并校验 Apple 公证凭据。
- 运行 `Scripts/sign_notarize_release.sh` 生成 Developer ID 签名并公证的 zip、DMG 和校验文件。
- 运行 `Scripts/create_github_release.sh` 校验 artifact，并创建 GitHub Release。
- 清理临时 keychain。

### 5.2 本地创建 Release

确认 DMG 已签名、公证、staple，并且 checksum 已重新生成后，使用发布脚本创建 GitHub Release：

```bash
VERSION=0.1.2 \
BUILD=1 \
TAG=0.1.2 \
NOTES_PATH=docs/releases/0.1.2.md \
Scripts/create_github_release.sh
```

脚本会检查：

- 工作区和暂存区干净。
- 当前分支是 `main`，且 `main` 与 `origin/main` 一致。
- tag 尚不存在。
- zip、DMG 和 SHA-256 文件存在且校验通过。
- DMG 通过 `xcrun stapler validate` 和 `spctl --assess`。

## 6. 当前限制

- 当前仓库仍是 SwiftPM 主入口，完整 Xcode target 还未创建。
- 当前 DMG 是基础安装镜像，尚未加入自定义背景图、窗口布局和许可证页。
- 正式发布前需要在干净 macOS 用户环境中完成首次运行、辅助功能授权、复制、搜索、自动粘贴和备份恢复检查。
