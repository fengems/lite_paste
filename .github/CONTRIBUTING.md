# Contributing to Lite Paste

Thanks for taking the time to improve Lite Paste.

## Development Setup

Requirements:

- macOS 15 or later
- Xcode or Xcode command line tools
- Swift 6

Run the app locally:

```bash
swift run LitePaste
```

Run the checks used by CI:

```bash
Scripts/verify_metadata.sh
bash -n Scripts/*.sh
swift build
swift run LitePasteCoreChecks
git diff --check
```

## Pull Request Guidelines

- Keep changes focused on one behavior or one cleanup.
- Follow the existing SwiftUI/AppKit style.
- Update docs when behavior, packaging, settings, or release steps change.
- Add or update `LitePasteCoreChecks` coverage for core model, storage, backup, or capture logic.
- Do not commit signing certificates, notarization credentials, local entitlements, or generated build artifacts.

## Release Notes

User-facing changes should include a short note in `CHANGELOG.md` under `Unreleased`.
