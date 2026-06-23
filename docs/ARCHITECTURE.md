# Lite Paste Architecture

This note is the starting point for contributors who want to understand how the
project is put together before changing code.

## Module Layout

Lite Paste is intentionally split into a small app layer and a reusable core:

- `LitePaste`: AppKit and SwiftUI entry point, menu-bar integration, panel
  presentation, keyboard handling, settings UI, alerts, OCR scheduling, and
  pasteboard writes.
- `LitePasteCore`: Data models, settings persistence, capture policy, payload
  classification, history storage, backup import/export, and SQLite access.
- `LitePasteCoreChecks`: Fast executable checks for core behavior. These are
  the default regression suite for model, settings, storage, backup, and capture
  logic.
- `LitePasteRuntimeRestoreChecks`: Runtime-oriented restore checks used by the
  release smoke flow.

The app target depends on `LitePasteCore`; the core target does not depend on
SwiftUI or AppKit UI types.

## Capture Flow

Clipboard capture moves through a narrow pipeline:

1. `ClipboardMonitor` observes system pasteboard changes and owns timing.
2. `ClipboardCaptureGate` and `ClipboardMonitoringPolicy` reject writes that
   should not enter history, including Lite Paste's own pasteboard writes and
   the user-controlled pause-monitoring state.
3. `ClipboardPayloadResolver` chooses the right payload builder for text, rich
   text, files, images, colors, and links.
4. `HistoryStore` applies duplicate, sorting, retention, and notification rules.
5. `ClipboardHistoryRepository` implementations persist metadata, while
   `BlobStorage` stores larger payloads outside SQLite.

The capture path should stay cheap on the main thread. Expensive work must be
bounded, deferred, or moved behind explicit size and policy checks.

## Restore Flow

Restoring an item is separate from selecting it in the UI:

1. `ClipboardPanelView` tracks selection and dispatches keyboard or pointer
   actions.
2. `ClipboardRecordActions` handles record-level commands such as copy, paste,
   plain-text paste, notes, external open, and delete.
3. `PasteboardWriter` writes the selected record back to the system pasteboard.
4. `PasteboardRestorePlan` decides which pasteboard formats are restored and
   how plain-text fallbacks are applied.
5. `PanelCoordinator` handles panel visibility, focus, and the optional
   auto-paste hop back to the previous app.

Selection state is UI state. Clipboard writes and history mutations should go
through the action/store layer rather than being embedded inside individual card
or row views.

## Settings

`AppSettings` is the persisted settings contract. When adding a setting:

- Add a default and decoding fallback in `AppSettings`.
- Keep migrations compatible with older JSON keys when a setting replaces a
  previous concept.
- Update `LitePasteCoreChecks`, especially `SettingsChecks`.
- Add user-facing copy through `AppLocalization` instead of hard-coding strings
  inside view code.

The current app visibility invariant is that at least one visible launch surface
must remain enabled: menu-bar icon or Dock icon.

## Storage

History is stored locally under the active flavor's application-support
directory. Stable and development builds intentionally use different data
directories.

- SQLite stores searchable metadata and small record fields.
- External blob files store larger media or rich payloads.
- Backup import/export uses the same record model, plus a manifest that records
  export metadata and validation details.

Keep storage changes backward compatible unless a release note and explicit
migration plan say otherwise.

## Verification

For normal development changes, run:

```bash
swift build
swift run LitePasteCoreChecks
Scripts/check_worktree_hygiene.sh
```

For release readiness, use:

```bash
Scripts/verify_release.sh
```

The release verifier also builds the local app bundle, runs runtime smoke
checks, validates signing, verifies the DMG layout, and checks SHA-256 files.

## Repository Hygiene

Do not commit local build output, generated app bundles, `.DS_Store`, signing
credentials, local environment files, or temporary logs. Keep feature changes,
cleanup commits, and version-only release commits separate so release history is
easy to review.
