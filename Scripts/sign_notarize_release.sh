#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="${ROOT_DIR}/Config/LitePaste/Info.plist"
plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "${INFO_PLIST}"
}
VERSION="${VERSION:-$(plist_value CFBundleShortVersionString)}"
BUILD="${BUILD:-$(plist_value CFBundleVersion)}"
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
  VERSION defaults to Config/LitePaste/Info.plist CFBundleShortVersionString.
  BUILD defaults to Config/LitePaste/Info.plist CFBundleVersion.
  NOTARIZE=0  Skip notarytool submit/staple and only create a Developer ID signed package.
  TEAM_ID or TEAM_IDENTIFIER_PREFIX is used to resolve iCloud document entitlements.
  NOTARY_KEYCHAIN can point notarytool to a CI-created temporary keychain.
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

resolved_entitlements() {
  local destination="${OUTPUT_DIR}/LitePaste.release.entitlements"
  local team_prefix="${TEAM_IDENTIFIER_PREFIX:-}"
  if [[ -z "${team_prefix}" && -n "${TEAM_ID:-}" ]]; then
    team_prefix="${TEAM_ID}."
  fi
  if [[ -z "${team_prefix}" ]]; then
    echo "TEAM_ID or TEAM_IDENTIFIER_PREFIX is required for iCloud document entitlements." >&2
    exit 65
  fi

  mkdir -p "${OUTPUT_DIR}"
  sed "s/\$(TeamIdentifierPrefix)/${team_prefix}/g" "${ENTITLEMENTS_PATH}" > "${destination}"
  printf '%s\n' "${destination}"
}

if [[ -z "${IDENTITY}" ]]; then
  usage >&2
  echo "DEVELOPER_ID_APPLICATION is required." >&2
  exit 64
fi

require_command codesign
require_command xcrun

cd "${ROOT_DIR}"

if [[ "${SKIP_DISTRIBUTION_PREFLIGHT:-0}" != "1" ]]; then
  Scripts/check_distribution_ready.sh
fi

VERSION="${VERSION}" BUILD="${BUILD}" Scripts/verify_metadata.sh

Scripts/build_app_bundle.sh

codesign \
  --force \
  --deep \
  --options runtime \
  --timestamp \
  --entitlements "$(resolved_entitlements)" \
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
  if [[ -n "${NOTARY_KEYCHAIN:-}" ]]; then
    credential_args+=(--keychain "${NOTARY_KEYCHAIN}")
  fi
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
