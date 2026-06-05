# Lite Paste macOS App Target 接入说明

本文档记录从当前 Swift Package 开发入口迁移到正式 macOS `.app` target 时需要保持一致的工程配置。

## 当前开发入口

当前仓库可以通过 Swift Package 在本地启动基础应用：

```bash
swift run LitePaste
```

当前仓库也提供 Command Line Tools 环境可用的本地 `.app` 打包脚本：

```bash
Scripts/build_app_bundle.sh --open
```

需要让开发版和已安装的正式版共存时，使用 Dev 构建通道：

```bash
LITEPASTE_FLAVOR=dev Scripts/build_app_bundle.sh --open
```

Dev 通道会生成 `Build/LitePasteDev.app`，显示名称为 `Lite Paste Dev`，Bundle Identifier 为 `com.fengems.LitePaste.dev`，数据目录为 `~/Library/Application Support/LitePaste-Dev/`，默认打开面板快捷键为 `⌘⌥⇧V`。未设置 `LITEPASTE_FLAVOR` 时仍生成正式通道的 `Build/LitePaste.app`。

本地试用 zip 包和 DMG 包可通过以下命令生成，文件名版本号默认读取 `Config/LitePaste/Info.plist`：

```bash
Scripts/package_release.sh
```

该脚本使用 SwiftPM release 产物组装 `Build/LitePaste.app`，复制 `Config/LitePaste/Info.plist`，执行 ad-hoc 签名，并生成 zip、DMG 与 SHA-256 校验文件。它适合本机试用，不替代正式 Xcode target。Developer ID 签名和公证脚本见 `Scripts/sign_notarize_release.sh` 与 `docs/DEVELOPER_ID_RELEASE.md`。

Dev 通道打包命令为：

```bash
LITEPASTE_FLAVOR=dev Scripts/package_release.sh
LITEPASTE_FLAVOR=dev Scripts/verify_dmg_contents.sh
```

Dev 通道包名使用 `LitePasteDev-版本-build.*`，不会覆盖正式通道产物。

当前环境已安装完整 Xcode，`xcodebuild` 可构建现有 SwiftPM scheme。创建正式 Xcode `.app` target、签名和公证前，应确保：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## App Target 基线

正式 Xcode target 建议使用以下配置：

- Product Name：`LitePaste`
- Display Name：`Lite Paste`
- Bundle Identifier：`com.fengems.LitePaste`
- Minimum Deployment：`macOS 15.0`
- App Category：Productivity
- App Sandbox：v1 暂不作为优先目标
- iCloud：启用 iCloud Documents，容器建议为 `iCloud.com.fengems.LitePaste`
- Dock 行为：菜单栏常驻工具，默认 `LSUIElement = true`
- Swift Language Version：Swift 6

## 配置文件

仓库已准备以下文件：

- `Config/LitePaste/Info.plist`
- `Config/LitePaste/LitePaste.entitlements`

正式 target 应使用这些文件作为基线。版本号需要同时更新：

- `Config/LitePaste/Info.plist`
- `Sources/LitePasteCore/AppMetadata.swift`

发布前可用 `Scripts/verify_metadata.sh` 检查 bundle id、显示名称、版本号、build 号和最低 macOS 版本是否一致。`Scripts/package_release.sh`、`Scripts/sign_notarize_release.sh` 和 `Scripts/verify_release.sh` 都会自动执行该检查。

## 权限说明

Lite Paste 的自动粘贴依赖 Accessibility 权限。该权限不通过 Info.plist 文案声明，而是在运行时调用系统 API 请求用户授权。

Lite Paste 的 iCloud 备份优先使用 iCloud Documents entitlement，并只保留最新一份备份。正式 target 应启用 iCloud Documents，并使用 `Config/LitePaste/LitePaste.entitlements` 中的 iCloud container 配置。为了保证人工验收包能在本地签名身份下稳定启动，本地脚本默认不签入 iCloud entitlement；需要验证 Apple iCloud Documents container 时，设置 `INCLUDE_ICLOUD_ENTITLEMENTS=1`，并提供 `TEAM_IDENTIFIER_PREFIX` 或 `TEAM_ID` 让脚本替换 `$(TeamIdentifierPrefix)` 后再签名。若运行环境无法获取应用 iCloud container，但用户已开启 iCloud Drive，应用会回退到用户 iCloud Drive 下的 Lite Paste 备份目录。

当前行为：

- 启动时会检查辅助功能权限，未授权时显示权限引导窗口。
- 用户可在引导窗口中请求权限、打开系统设置，或本次运行稍后处理。
- 自动粘贴时如果仍未授权，Lite Paste 会先把内容复制到剪贴板，再提示用户授予辅助功能权限。
- 授权后，Lite Paste 可恢复上一个活跃应用并模拟 `⌘V`。

如果后续增加 Apple Events 或自动化控制，再补充对应的 usage description 和 entitlement。

## 开机启动

开机启动使用 `ServiceManagement.SMAppService.mainApp` 注册。该能力需要应用以正常 `.app` bundle 形态运行；在 SwiftPM 直接运行的调试入口中，可能因缺少正式 bundle/signing 环境而无法完成注册。

当前设置页行为：

- 注册成功后保存 `launchAtLogin = true`。
- 注册失败时弹出系统错误信息，不写入设置。
- App 启动时会按已保存设置尝试同步登录项状态。

## 资源要求

仓库已提供正式 target 可直接接入的 AppIcon 基线：

- `Assets/LitePaste.xcassets/AppIcon.appiconset`

菜单栏当前使用 `StatusItemIcon` 程序化绘制 template 图标，能在 SwiftPM 和本地 `.app` bundle 中保持一致。未来完整 Xcode target 可按需迁移为 asset catalog 里的模板资源。本地 bundle 脚本会用 `Scripts/generate_app_icon.swift` 生成 `AppIcon.icns`；如需刷新 Xcode AppIcon，可执行：

```bash
swift Scripts/generate_app_icon.swift /tmp/LitePaste-AppIcon.icns Assets/LitePaste.xcassets/AppIcon.appiconset
```

## 本地 Bundle 脚本

`Scripts/build_app_bundle.sh` 会生成：

- `Build/LitePaste.app/Contents/MacOS/LitePaste`
- `Build/LitePaste.app/Contents/Info.plist`
- `Build/LitePaste.app/Contents/PkgInfo`
- `Build/LitePaste.app/Contents/Resources/AppIcon.icns`

设置 `LITEPASTE_FLAVOR=dev` 时对应生成：

- `Build/LitePasteDev.app/Contents/MacOS/LitePaste`
- `Build/LitePasteDev.app/Contents/Info.plist`
- `Build/LitePasteDev.app/Contents/PkgInfo`
- `Build/LitePasteDev.app/Contents/Resources/AppIcon.icns`

脚本默认使用 release 配置。需要改配置时可传环境变量：

```bash
CONFIGURATION=debug Scripts/build_app_bundle.sh
```

需要验证 iCloud Documents container 时，应使用真实 Apple 签名身份并显式开启 iCloud entitlement：

```bash
TEAM_ID="TEAMID" \
CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)" \
INCLUDE_ICLOUD_ENTITLEMENTS=1 \
Scripts/build_app_bundle.sh --open
```

## 验证命令

当前 SwiftPM scheme 可用 Xcode 验证：

```bash
xcodebuild -scheme LitePaste -configuration Debug build
```

人工验收本地 `.app` 前可运行；脚本成功后会直接打开 App，详细日志写入 `Build/prepare_manual_check.log`：

```bash
Scripts/prepare_manual_check.sh
```

正式 Xcode `.app` target 创建后，还需要补充该 target 的 `xcodebuild` 构建命令。完整发布前继续使用：

```bash
swift run LitePasteCoreChecks
swift build
Scripts/verify_release.sh
```
