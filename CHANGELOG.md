# Changelog

All notable changes to Lite Paste are documented here.

## Unreleased

## 0.1.6 - 2026-06-23

- Fixed the clipboard panel not resetting scroll to the top when reopened.
- Renamed data models (`ClipboardItem` → `ClipboardRecord`, `ClipboardContent` → `ClipboardContentSnapshot`) and added fields for plain text, OCR text, content snapshots, and preview file paths.
- Isolated persistence behind a repository layer and switched settings to a JSON configuration model.
- Split large source files into focused modules and removed deprecated privacy-filter and pin-shortcut implementations.

## 0.1.3 - 2026-06-05

- Added a stable/dev local build channel so `Lite Paste Dev` can coexist with the normal app using a separate bundle id, data directory, default shortcut, and package output names.
- Added source-only GitHub release checks and creation script for the zero-budget release path without Apple Developer Program credentials.
- Added locale-aware Chinese/English copy for onboarding, menu-bar actions, the clipboard panel, settings, backup flows, and key alerts.
- Added DMG content verification for the app bundle, Applications shortcut, version metadata, and code signature before publishing.

## 0.1.2 - 2026-05-31

- Added public project governance files, issue templates, CI checks, and release readiness documentation.
- Added a guarded GitHub Release creation script and a draft release note for the first notarized public release.
- Added a manual GitHub Actions release workflow for Developer ID signing, notarization, packaging, and GitHub Release publication.
- Added a GitHub release readiness check for repository visibility, workflow state, release target, and required Actions secrets.
- Added public privacy notes describing local storage, monitoring, Accessibility permission, and backups.
- Updated app metadata for the MIT-licensed first public release.

## 0.1.1

- Added the core menu-bar clipboard manager experience.
- Added card and list panel views with search, filtering, favorites, pinned items, notes, and deletion.
- Added local SQLite history storage, external blob storage, import/export backup, and iCloud Drive backup.
- Added privacy controls for paused monitoring, ignored apps, and sensitive pasteboard types.
- Added local packaging scripts for app bundle, zip, and DMG artifacts.
