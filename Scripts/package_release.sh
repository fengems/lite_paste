#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-0.1.0}"
BUILD="${BUILD:-1}"
BUILD_APP="${BUILD_APP:-1}"
OUTPUT_DIR="${ROOT_DIR}/Build"
APP_PATH="${OUTPUT_DIR}/LitePaste.app"
ARCHIVE_BASENAME="LitePaste-${VERSION}-${BUILD}"
ARCHIVE_PATH="${OUTPUT_DIR}/${ARCHIVE_BASENAME}.zip"
CHECKSUM_PATH="${ARCHIVE_PATH}.sha256"
DMG_PATH="${OUTPUT_DIR}/${ARCHIVE_BASENAME}.dmg"
DMG_CHECKSUM_PATH="${DMG_PATH}.sha256"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/litepaste-release.XXXXXX")"

cleanup() {
  rm -rf "${STAGING_DIR}"
}
trap cleanup EXIT

cd "${ROOT_DIR}"

if [[ "${BUILD_APP}" == "1" ]]; then
  Scripts/build_app_bundle.sh
elif [[ ! -d "${APP_PATH}" ]]; then
  echo "Missing ${APP_PATH}. Run Scripts/build_app_bundle.sh first, or leave BUILD_APP=1." >&2
  exit 1
fi

rm -f "${ARCHIVE_PATH}" "${CHECKSUM_PATH}" "${DMG_PATH}" "${DMG_CHECKSUM_PATH}"
ditto -c -k --keepParent "${APP_PATH}" "${ARCHIVE_PATH}"
shasum -a 256 "${ARCHIVE_PATH}" > "${CHECKSUM_PATH}"

DMG_SOURCE_DIR="${STAGING_DIR}/Lite Paste"
mkdir -p "${DMG_SOURCE_DIR}"
ditto "${APP_PATH}" "${DMG_SOURCE_DIR}/LitePaste.app"
ln -s /Applications "${DMG_SOURCE_DIR}/Applications"
hdiutil create \
  -volname "Lite Paste" \
  -srcfolder "${DMG_SOURCE_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"
shasum -a 256 "${DMG_PATH}" > "${DMG_CHECKSUM_PATH}"

echo "Packaged ${ARCHIVE_PATH}"
echo "Checksum ${CHECKSUM_PATH}"
echo "Packaged ${DMG_PATH}"
echo "Checksum ${DMG_CHECKSUM_PATH}"
