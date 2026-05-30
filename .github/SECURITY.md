# Security Policy

Lite Paste is a local-first clipboard manager. Clipboard history can contain sensitive user data, so security reports are treated seriously.

## Supported Versions

Security fixes are prioritized for the latest released version.

## Reporting a Vulnerability

Please do not open a public issue for a suspected vulnerability. Use GitHub private vulnerability reporting if it is available on the repository, or contact the maintainer privately with:

- A clear description of the issue.
- Steps to reproduce.
- The macOS version and Lite Paste version.
- Whether clipboard contents, local files, backups, or app permissions are involved.

Do not include real passwords, tokens, private keys, or personal clipboard data in the report. Use synthetic examples whenever possible.

## Scope

Relevant issues include:

- Clipboard data being captured when monitoring is paused or an app is ignored.
- Sensitive pasteboard types being persisted unexpectedly.
- Backup import/export exposing data outside the selected destination.
- Release artifacts that cannot be verified or appear to be tampered with.
