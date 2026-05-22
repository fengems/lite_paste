# Lite Paste macOS App Target 接入说明

本文档记录从当前 Swift Package 开发入口迁移到正式 macOS `.app` target 时需要保持一致的工程配置。

## 当前开发入口

当前仓库可以通过 Swift Package 在本地启动基础应用：

```bash
swift run LitePaste
```

当前环境仅安装 Command Line Tools，`xcodebuild` 无法工作。创建、签名、打包正式 `.app` 前，需要安装完整 Xcode，并确保：

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

## 权限说明

Lite Paste 的自动粘贴依赖 Accessibility 权限。该权限不通过 Info.plist 文案声明，而是在运行时调用系统 API 请求用户授权。

当前行为：

- 未授权时，Lite Paste 会先把内容复制到剪贴板。
- 随后提示用户授予辅助功能权限。
- 授权后，Lite Paste 可恢复上一个活跃应用并模拟 `⌘V`。

如果后续增加 Apple Events 或自动化控制，再补充对应的 usage description 和 entitlement。

## 资源要求

正式 target 还需要补齐：

- AppIcon `.appiconset`
- 菜单栏 template 图标
- 关于页图标
- 发布用 DMG 或 zip 打包配置

图标文件应放入未来的 Xcode asset catalog 中，不放入 SwiftPM 构建产物目录。

## 验证命令

在完整 Xcode 环境下，正式 target 至少需要通过：

```bash
xcodebuild -scheme LitePaste -configuration Debug build
```

当前 Command Line Tools 环境下，继续使用：

```bash
swift run LitePasteCoreChecks
swift build
```

