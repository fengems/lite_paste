# Lite Paste 可使用版本发布检查清单

本文档用于当前 Command Line Tools 环境下的本地试用版发布。Developer ID 签名和公证流程见 `docs/DEVELOPER_ID_RELEASE.md`，正式 Xcode target 发布流程后续再补。

## 1. 构建

生成本地 `.app`：

```bash
Scripts/build_app_bundle.sh
```

生成可分享的 zip、DMG 和 SHA-256 校验文件：

```bash
Scripts/package_release.sh
```

默认输出：

- `Build/LitePaste.app`
- `Build/LitePaste-0.1.0-1.zip`
- `Build/LitePaste-0.1.0-1.zip.sha256`
- `Build/LitePaste-0.1.0-1.dmg`
- `Build/LitePaste-0.1.0-1.dmg.sha256`

如需覆盖版本号：

```bash
VERSION=0.1.0 BUILD=1 Scripts/package_release.sh
```

## 2. 发布前验证

每次发布前至少运行：

```bash
Scripts/verify_release.sh
```

该脚本会依次执行核心检查、debug 编译、本地 `.app` 打包、Info.plist 校验、codesign 校验、zip/DMG 打包、DMG 校验和 SHA-256 校验。需要拆开排查时，可单独运行：

```bash
swift run LitePasteCoreChecks
swift build
Scripts/build_app_bundle.sh
plutil -lint Build/LitePaste.app/Contents/Info.plist
codesign --verify --deep --strict --verbose=2 Build/LitePaste.app
Scripts/package_release.sh
```

确认 bundle 内容：

```bash
find Build/LitePaste.app/Contents -maxdepth 3 -type f | sort
```

应至少包含：

- `Contents/MacOS/LitePaste`
- `Contents/Info.plist`
- `Contents/PkgInfo`
- `Contents/Resources/AppIcon.icns`

确认发布包：

```bash
hdiutil verify Build/LitePaste-0.1.0-1.dmg
shasum -a 256 -c Build/LitePaste-0.1.0-1.zip.sha256
shasum -a 256 -c Build/LitePaste-0.1.0-1.dmg.sha256
```

如果要生成 Developer ID 签名并公证的发布包，改用：

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="litepaste-notary" \
Scripts/sign_notarize_release.sh
```

## 3. 首次运行检查

1. 打开应用：

```bash
open Build/LitePaste.app
```

2. 确认菜单栏出现 Lite Paste 图标。
3. 左键菜单栏图标可以打开剪贴板面板。
4. 右键菜单栏图标可以打开菜单，并能进入设置。
5. 在设置的“权限”区检查辅助功能权限状态。
6. 点击“请求辅助功能权限”或“打开系统设置”，授予 Lite Paste 辅助功能权限。
7. 复制一段文本，确认面板中出现历史记录。
8. 搜索该文本，确认结果可过滤。
9. 点击条目执行默认操作，确认可以复制或自动粘贴。
10. 在未授权辅助功能时，确认自动粘贴会降级为复制并提示。
11. 在设置中执行导出备份，再合并导入一次备份，确认历史可恢复。

## 4. 已知限制

- 默认 zip 和 DMG 为 ad-hoc 签名本地试用包；正式分发应使用 `Scripts/sign_notarize_release.sh`。
- 首次打开可能需要用户在 macOS 安全设置中确认允许运行。
- 开机启动能力更适合正式 `.app` bundle 和签名环境验证。
- 菜单栏使用项目内绘制的 template 图标，完整 Xcode target 阶段可再迁移到 asset catalog。

## 5. 回滚和清理

运行时数据位于：

- `~/Library/Application Support/LitePaste/history.sqlite3`
- `~/Library/Application Support/LitePaste/settings.json`
- `~/Library/Application Support/LitePaste/Blobs/`

清理本地构建产物：

```bash
rm -rf Build
```
