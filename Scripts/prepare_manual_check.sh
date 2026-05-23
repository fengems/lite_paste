#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${ROOT_DIR}/Build/LitePaste.app"
RUN_SMOKE=false
OPEN_APP=false

usage() {
  cat <<'USAGE'
Usage:
  Scripts/prepare_manual_check.sh [--with-smoke] [--open]

Builds a local Lite Paste app bundle for manual QA. By default this script
verifies metadata, checks that Xcode can build the SwiftPM scheme, runs core
checks, builds Build/LitePaste.app, and verifies the app bundle plist/signature.

Options:
  --with-smoke   Also run the runtime clipboard capture/restore smoke test.
  --open         Open Build/LitePaste.app after successful preparation.
  --help         Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-smoke)
      RUN_SMOKE=true
      ;;
    --open)
      OPEN_APP=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
  shift
done

run() {
  printf '\n==> %s\n' "$*"
  "$@"
}

cd "${ROOT_DIR}"

run Scripts/verify_metadata.sh
run xcodebuild -scheme LitePaste -destination "platform=macOS" -configuration Debug build
run swift run LitePasteCoreChecks

printf '\n==> CONFIGURATION=release Scripts/build_app_bundle.sh\n'
CONFIGURATION=release Scripts/build_app_bundle.sh

if "${RUN_SMOKE}"; then
  run Scripts/smoke_runtime_capture.sh
fi

run plutil -lint "${APP_PATH}/Contents/Info.plist"
run codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

printf '\nLite Paste is ready for manual check: %s\n' "${APP_PATH}"
printf 'Open with: open %s\n' "${APP_PATH}"

if "${OPEN_APP}"; then
  run open "${APP_PATH}"
fi
