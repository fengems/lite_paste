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
ENTITLEMENTS_PATH="${ROOT_DIR}/Config/LitePaste/LitePaste.entitlements"
IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARIZE="${NOTARIZE:-1}"

usage() {
  cat <<'EOF'
Usage:
  DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
  NOTARY_PROFILE="litepaste-notary" \
  Scripts/sign_notarize_release.sh

Alternative notarization credentials:
  APPLE_ID="you@example.com" \
  APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
  TEAM_ID="TEAMID" \
  DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
  Scripts/sign_notarize_release.sh

Environment:
  VERSION=0.1.0
  BUILD=1
  NOTARIZE=0  Skip notarytool submit/staple and only create a Developer ID signed package.
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

if [[ -z "${IDENTITY}" ]]; then
  usage >&2
  echo "DEVELOPER_ID_APPLICATION is required." >&2
  exit 64
fi

require_command codesign
require_command xcrun

cd "${ROOT_DIR}"

Scripts/build_app_bundle.sh

codesign \
  --force \
  --deep \
  --options runtime \
  --timestamp \
  --entitlements "${ENTITLEMENTS_PATH}" \
  --sign "${IDENTITY}" \
  "${APP_PATH}"

codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

BUILD_APP=0 VERSION="${VERSION}" BUILD="${BUILD}" Scripts/package_release.sh

codesign --force --timestamp --sign "${IDENTITY}" "${DMG_PATH}"

if [[ "${NOTARIZE}" != "1" ]]; then
  shasum -a 256 "${ZIP_PATH}" > "${ZIP_CHECKSUM_PATH}"
  shasum -a 256 "${DMG_PATH}" > "${DMG_CHECKSUM_PATH}"
  echo "Created Developer ID signed release without notarization: ${DMG_PATH}"
  exit 0
fi

credential_args=()
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  credential_args=(--keychain-profile "${NOTARY_PROFILE}")
elif [[ -n "${APPLE_ID:-}" && -n "${APP_SPECIFIC_PASSWORD:-}" && -n "${TEAM_ID:-}" ]]; then
  credential_args=(
    --apple-id "${APPLE_ID}"
    --password "${APP_SPECIFIC_PASSWORD}"
    --team-id "${TEAM_ID}"
  )
else
  usage >&2
  echo "Set NOTARY_PROFILE or APPLE_ID/APP_SPECIFIC_PASSWORD/TEAM_ID for notarization." >&2
  exit 64
fi

xcrun notarytool submit "${DMG_PATH}" --wait "${credential_args[@]}"
xcrun stapler staple "${DMG_PATH}"
xcrun stapler validate "${DMG_PATH}"
shasum -a 256 "${ZIP_PATH}" > "${ZIP_CHECKSUM_PATH}"
shasum -a 256 "${DMG_PATH}" > "${DMG_CHECKSUM_PATH}"

echo "Created notarized release: ${DMG_PATH}"
