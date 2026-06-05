#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/Scripts/lib/app_flavor.sh"
litepaste_configure_flavor

INFO_PLIST="${ROOT_DIR}/Config/LitePaste/Info.plist"
plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "${INFO_PLIST}"
}
VERSION="${VERSION:-$(plist_value CFBundleShortVersionString)}"
BUILD="${BUILD:-$(plist_value CFBundleVersion)}"
OUTPUT_DIR="${ROOT_DIR}/Build"
APP_PATH="${OUTPUT_DIR}/${LITEPASTE_APP_BUNDLE_NAME}"
ZIP_PATH="${OUTPUT_DIR}/${LITEPASTE_ARCHIVE_PRODUCT_NAME}-${VERSION}-${BUILD}.zip"
ZIP_CHECKSUM_PATH="${ZIP_PATH}.sha256"
DMG_PATH="${OUTPUT_DIR}/${LITEPASTE_ARCHIVE_PRODUCT_NAME}-${VERSION}-${BUILD}.dmg"
DMG_CHECKSUM_PATH="${DMG_PATH}.sha256"

run() {
  printf '\n==> %s\n' "$*"
  "$@"
}

cd "${ROOT_DIR}"

run Scripts/verify_metadata.sh
run env -u LITEPASTE_FLAVOR swift run LitePasteCoreChecks
run swift build
run Scripts/build_app_bundle.sh
run Scripts/smoke_runtime_capture.sh
run plutil -lint "${APP_PATH}/Contents/Info.plist"
run codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
run Scripts/package_release.sh
run hdiutil verify "${DMG_PATH}"
run Scripts/verify_dmg_contents.sh
run shasum -a 256 -c "${ZIP_CHECKSUM_PATH}"
run shasum -a 256 -c "${DMG_CHECKSUM_PATH}"

printf '\n%s release verification passed for %s-%s.\n' "${LITEPASTE_APP_DISPLAY_NAME}" "${VERSION}" "${BUILD}"
