# Lite Paste Privacy Notes

Lite Paste is designed as a local-first clipboard manager. Clipboard contents can be sensitive, so the default behavior is conservative and transparent.

## Local Data

Lite Paste stores clipboard history on your Mac under:

```text
~/Library/Application Support/LitePaste/
```

The data directory can contain:

- `history.sqlite3`: clipboard metadata and searchable text.
- `settings.json`: app settings.
- `Blobs/`: external files for images, rich text, HTML, files, and other larger clipboard payloads.

Lite Paste does not run a server and does not upload clipboard history automatically.

## Clipboard Monitoring

Lite Paste watches the system pasteboard while monitoring is enabled. You can stop monitoring from the menu-bar menu or Settings. When monitoring is stopped, new clipboard changes are not saved.

## Accessibility Permission

Accessibility permission is used only for automatic paste. When you select an item to paste, Lite Paste restores that content to the system pasteboard and can send the paste shortcut to the previous app.

If Accessibility permission is not granted, Lite Paste still copies the selected item to the clipboard and you can paste manually.

## iCloud Backup

iCloud backup is explicit and user-triggered from Settings. It is not real-time sync.

When iCloud backup is used, Lite Paste writes the same backup package format used by local export. It first tries the app iCloud container, then falls back to the user's iCloud Drive folder when needed. The iCloud backup keeps the latest backup only.

## Manual Backups

Manual export creates a backup package at the location you choose. That package can include clipboard history, settings, and external blob files. Treat exported backups as sensitive files.

## Security Reports

If you find a privacy or security issue, follow the [Security Policy](../.github/SECURITY.md). Do not include real passwords, tokens, private keys, or personal clipboard data in public reports.
