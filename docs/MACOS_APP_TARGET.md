# Lite Paste macOS App Target 接入说明

本文档记录从当前 Swift Package 开发入口迁移到正式 macOS `.app` target 时需要保持一致的工程配置。

## 当前开发入口

当前仓库可以通过 Swift Package 在本地启动基础应用：

```bash
swift run LitePaste
```

当前仓库也提供 Command Line Tools 环境可用的本地 `.app` 打包脚本：

```bash
Scripts/build_app_bundle.sh
open Build/LitePaste.app
```

本地试用 zip 包和 DMG 包可通过以下命令生成，文件名版本号默认读取 `Config/LitePaste/Info.plist`：

```bash
Scripts/package_release.sh
```

该脚本使用 SwiftPM release 产物组装 `Build/LitePaste.app`，复制 `Config/LitePaste/Info.plist`，执行 ad-hoc 签名，并生成 zip、DMG 与 SHA-256 校验文件。它适合本机试用，不替代正式 Xcode target。Developer ID 签名和公证脚本见 `Scripts/sign_notarize_release.sh` 与 `docs/DEVELOPER_ID_RELEASE.md`。

当前环境仅安装 Command Line Tools，`xcodebuild` 无法工作。创建、签名、打包正式发布 `.app` 前，需要安装完整 Xcode，并确保：

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

当前行为：

- 未授权时，Lite Paste 会先把内容复制到剪贴板。
- 随后提示用户授予辅助功能权限。
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

脚本默认使用 release 配置。需要改配置时可传环境变量：

```bash
CONFIGURATION=debug Scripts/build_app_bundle.sh
```

## 验证命令

在完整 Xcode 环境下，正式 target 至少需要通过：

```bash
xcodebuild -scheme LitePaste -configuration Debug build
```

当前 Command Line Tools 环境下，继续使用：

```bash
swift run LitePasteCoreChecks
swift build
Scripts/verify_release.sh
```
