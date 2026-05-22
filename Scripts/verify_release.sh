#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-0.1.0}"
BUILD="${BUILD:-1}"
OUTPUT_DIR="${ROOT_DIR}/Build"
APP_PATH="${OUTPUT_DIR}/LitePaste.app"
ZIP_PATH="${OUTPUT_DIR}/LitePaste-${VERSION}-${BUILD}.zip"
ZIP_CHECKSUM_PATH="${ZIP_PATH}.sha256"
DMG_PATH="${OUTPUT_DIR}/LitePaste-${VERSION}-${BUILD}.dmg"
DMG_CHECKSUM_PATH="${DMG_PATH}.sha256"

run() {
  printf '\n==> %s\n' "$*"
  "$@"
}

cd "${ROOT_DIR}"

run Scripts/verify_metadata.sh
run swift run LitePasteCoreChecks
run swift build
run Scripts/build_app_bundle.sh
run plutil -lint "${APP_PATH}/Contents/Info.plist"
run codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
run Scripts/package_release.sh
run hdiutil verify "${DMG_PATH}"
run shasum -a 256 -c "${ZIP_CHECKSUM_PATH}"
run shasum -a 256 -c "${DMG_CHECKSUM_PATH}"

printf '\nLite Paste release verification passed for %s-%s.\n' "${VERSION}" "${BUILD}"
