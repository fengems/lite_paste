# Lite Paste

[![CI](https://github.com/fengems/lite_paste/actions/workflows/ci.yml/badge.svg)](https://github.com/fengems/lite_paste/actions/workflows/ci.yml)

Lite Paste is a native macOS clipboard manager focused on speed, privacy, and a polished menu-bar workflow. It keeps clipboard history locally, opens from the menu bar or a global hotkey, and restores text, files, images, colors, links, HTML, and rich text back to the system pasteboard.

Lite Paste 是一款原生 macOS 剪贴板管理器，重点是轻量、隐私优先和高效的菜单栏体验。它默认把历史记录保存在本机，可通过菜单栏或全局快捷键打开，并支持恢复文本、文件、图片、颜色、链接、HTML 和富文本内容。

## Highlights

- Native menu-bar app for macOS 15 and later.
- Card and list views with search, type filters, favorites, pinned items, notes, and delete/clear actions.
- Global panel hotkey, keyboard navigation, `Command + 1` to `Command + 6` quick selection, copy, paste, and paste-as-plain-text shortcuts.
- Automatic paste back to the previous app after Accessibility permission is granted.
- Local SQLite storage with external blob files for large media.
- Privacy controls: pause monitoring, ignore specific apps, ignore sensitive pasteboard types, and keep data local by default.
- Large rich-text/table handling with a user setting for preserving original formats when higher fidelity matters.
- Local backup import/export and iCloud Drive backup. iCloud backup keeps the latest backup only.
- Launch at login, data directory reveal, runtime status, and permission status in Settings.

## Install

When a notarized build is available, download the latest DMG from the [GitHub Releases](https://github.com/fengems/lite_paste/releases) page, open it, and drag `LitePaste.app` to Applications.

The repository is public before the first notarized release is published. Until a release appears on GitHub Releases, build Lite Paste locally with the development commands below.

On first launch, macOS may ask for Accessibility permission. Lite Paste uses this permission only when you trigger automatic paste, so it can return to the previous app and send the paste shortcut. Without the permission, Lite Paste still copies the selected item to the clipboard and you can paste manually.

## Usage

- Open the panel from the menu bar icon or the default hotkey `Command + Shift + V`.
- Search with `Command + F`.
- Use arrow keys to move selection, Return to paste, `Command + C` to copy, Delete to delete, and Escape to close.
- Use `Command + 1` through `Command + 6` to select the corresponding visible item.
- Use the menu-bar menu to pause clipboard monitoring or ignore the current app.

## Privacy

Lite Paste is designed as a local-first utility:

- Clipboard history is stored under `~/Library/Application Support/LitePaste/`.
- Lite Paste ignores its own pasteboard writes to avoid recording loops.
- Password managers and concealed/transient pasteboard types are ignored by default.
- iCloud backup is explicit and user-triggered. It is not real-time sync.

Read the [Privacy Notes](docs/PRIVACY.md) for details about local storage, Accessibility permission, ignored apps, and backups.

## Development

Requirements:

- macOS 15+
- Swift 6
- Xcode command line tools or full Xcode

Run from SwiftPM:

```bash
swift run LitePaste
```

Build a local app bundle:

```bash
Scripts/build_app_bundle.sh --open
```

Run core checks:

```bash
Scripts/verify_metadata.sh
swift run LitePasteCoreChecks
swift build
git diff --check
```

Prepare a manual QA build:

```bash
Scripts/prepare_manual_check.sh
```

Local builds use the local `LitePaste Local Code Signing` identity when available, otherwise ad-hoc signing. Local builds are useful for development and QA, but they are not a substitute for a Developer ID signed and notarized public release.

## Release

For a build that other users can install smoothly, use Developer ID signing and Apple notarization:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
TEAM_ID="TEAMID" \
NOTARY_PROFILE="litepaste-notary" \
Scripts/sign_notarize_release.sh
```

Check distribution prerequisites before release:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
TEAM_ID="TEAMID" \
NOTARY_PROFILE="litepaste-notary" \
Scripts/check_distribution_ready.sh
```

Public releases can also be created from GitHub Actions after the release secrets are configured. Open **Actions > Release > Run workflow**, enter the version/build that already exist in app metadata, and the workflow will sign, notarize, package, verify, and publish the GitHub Release.

Check the remote GitHub release prerequisites before triggering the workflow:

```bash
Scripts/check_github_release_ready.sh
```

Detailed release notes and manual QA steps are in:

- [Developer ID release guide](docs/DEVELOPER_ID_RELEASE.md)
- [Privacy notes](docs/PRIVACY.md)
- [Release checklist](docs/RELEASE_CHECKLIST.md)
- [Public release audit](docs/PUBLIC_RELEASE_AUDIT.md)
- [Release notes](docs/releases/0.1.2.md)
- [macOS app target notes](docs/MACOS_APP_TARGET.md)

## Contributing

See [Contributing](.github/CONTRIBUTING.md), [Security Policy](.github/SECURITY.md), and [Changelog](CHANGELOG.md).

## License

Lite Paste is released under the [MIT License](LICENSE).
