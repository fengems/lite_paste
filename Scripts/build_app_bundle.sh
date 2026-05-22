#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
PRODUCT_NAME="LitePaste"
APP_DISPLAY_NAME="Lite Paste"
APP_BUNDLE_NAME="${PRODUCT_NAME}.app"
OUTPUT_DIR="${ROOT_DIR}/Build"
APP_DIR="${OUTPUT_DIR}/${APP_BUNDLE_NAME}"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
INFO_PLIST_SOURCE="${ROOT_DIR}/Config/LitePaste/Info.plist"
INFO_PLIST_DESTINATION="${CONTENTS_DIR}/Info.plist"

cd "${ROOT_DIR}"

swift build -c "${CONFIGURATION}" --product "${PRODUCT_NAME}"

EXECUTABLE_PATH="$(swift build -c "${CONFIGURATION}" --product "${PRODUCT_NAME}" --show-bin-path)/${PRODUCT_NAME}"

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${EXECUTABLE_PATH}" "${MACOS_DIR}/${PRODUCT_NAME}"
cp "${INFO_PLIST_SOURCE}" "${INFO_PLIST_DESTINATION}"
printf 'APPL????' > "${CONTENTS_DIR}/PkgInfo"

chmod +x "${MACOS_DIR}/${PRODUCT_NAME}"

if command -v plutil >/dev/null 2>&1; then
  plutil -lint "${INFO_PLIST_DESTINATION}" >/dev/null
fi

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "${APP_DIR}" >/dev/null
fi

echo "Built ${APP_DISPLAY_NAME} at ${APP_DIR}"
echo "Open with: open ${APP_DIR}"
