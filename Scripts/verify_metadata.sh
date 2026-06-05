#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="${ROOT_DIR}/Config/LitePaste/Info.plist"
APP_METADATA="${ROOT_DIR}/Sources/LitePasteCore/AppMetadata.swift"
EXPECTED_DISPLAY_NAME="Lite Paste"
EXPECTED_BUNDLE_IDENTIFIER="com.fengems.LitePaste"

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "${INFO_PLIST}"
}

metadata_value() {
  local key="$1"
  sed -nE "s/^[[:space:]]*public static let ${key} = \"([^\"]+)\".*/\\1/p" "${APP_METADATA}"
}

fail() {
  echo "Metadata verification failed: $1" >&2
  exit 1
}

info_display_name="$(plist_value CFBundleDisplayName)"
info_bundle_identifier="$(plist_value CFBundleIdentifier)"
info_version="$(plist_value CFBundleShortVersionString)"
info_build="$(plist_value CFBundleVersion)"
info_minimum_macos="$(plist_value LSMinimumSystemVersion)"

metadata_version="$(metadata_value version)"
metadata_build="$(metadata_value build)"
metadata_minimum_macos="$(metadata_value minimumMacOSVersion)"

[[ -n "${metadata_version}" ]] || fail "AppMetadata.version was not found"
[[ -n "${metadata_build}" ]] || fail "AppMetadata.build was not found"
[[ -n "${metadata_minimum_macos}" ]] || fail "AppMetadata.minimumMacOSVersion was not found"

[[ "${info_display_name}" == "${EXPECTED_DISPLAY_NAME}" ]] ||
  fail "display name mismatch: Info.plist=${info_display_name}, expected=${EXPECTED_DISPLAY_NAME}"
[[ "${info_bundle_identifier}" == "${EXPECTED_BUNDLE_IDENTIFIER}" ]] ||
  fail "bundle identifier mismatch: Info.plist=${info_bundle_identifier}, expected=${EXPECTED_BUNDLE_IDENTIFIER}"
[[ "${info_version}" == "${metadata_version}" ]] ||
  fail "version mismatch: Info.plist=${info_version}, AppMetadata=${metadata_version}"
[[ "${info_build}" == "${metadata_build}" ]] ||
  fail "build mismatch: Info.plist=${info_build}, AppMetadata=${metadata_build}"
[[ "${info_minimum_macos}" == "${metadata_minimum_macos}" ]] ||
  fail "minimum macOS mismatch: Info.plist=${info_minimum_macos}, AppMetadata=${metadata_minimum_macos}"

if [[ -n "${VERSION:-}" && "${VERSION}" != "${metadata_version}" ]]; then
  fail "VERSION=${VERSION} does not match AppMetadata.version=${metadata_version}"
fi

if [[ -n "${BUILD:-}" && "${BUILD}" != "${metadata_build}" ]]; then
  fail "BUILD=${BUILD} does not match AppMetadata.build=${metadata_build}"
fi

echo "Metadata verified: ${info_display_name} ${metadata_version} (${metadata_build})"
