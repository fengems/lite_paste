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
DMG_PATH="${DMG_PATH:-${OUTPUT_DIR}/LitePaste-${VERSION}-${BUILD}.dmg}"
MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/litepaste-dmg-check.XXXXXX")"
MOUNTED=0

cleanup() {
  if [[ "${MOUNTED}" == "1" ]]; then
    hdiutil detach "${MOUNT_DIR}" -quiet >/dev/null 2>&1 || true
  fi
  rm -rf "${MOUNT_DIR}"
}
trap cleanup EXIT

fail() {
  printf 'DMG 内容校验失败：%s\n' "$1" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "缺少文件 $1"
}

require_dir() {
  [[ -d "$1" ]] || fail "缺少目录 $1"
}

require_symlink_to() {
  local path="$1"
  local expected_target="$2"
  [[ -L "${path}" ]] || fail "缺少快捷方式 ${path}"
  [[ "$(readlink "${path}")" == "${expected_target}" ]] ||
    fail "${path} 未指向 ${expected_target}"
}

cd "${ROOT_DIR}"

require_file "${DMG_PATH}"
VERSION="${VERSION}" BUILD="${BUILD}" Scripts/verify_metadata.sh >/dev/null

hdiutil attach \
  -nobrowse \
  -readonly \
  -mountpoint "${MOUNT_DIR}" \
  "${DMG_PATH}" >/dev/null
MOUNTED=1

APP_PATH="${MOUNT_DIR}/LitePaste.app"
APP_INFO_PLIST="${APP_PATH}/Contents/Info.plist"

require_dir "${APP_PATH}"
require_symlink_to "${MOUNT_DIR}/Applications" "/Applications"
require_file "${APP_PATH}/Contents/MacOS/LitePaste"
require_file "${APP_INFO_PLIST}"
require_file "${APP_PATH}/Contents/Resources/AppIcon.icns"

bundle_version="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${APP_INFO_PLIST}")"
bundle_build="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${APP_INFO_PLIST}")"

[[ "${bundle_version}" == "${VERSION}" ]] ||
  fail "DMG 内 App 版本不一致：${bundle_version}，期望 ${VERSION}"
[[ "${bundle_build}" == "${BUILD}" ]] ||
  fail "DMG 内 App build 不一致：${bundle_build}，期望 ${BUILD}"

codesign --verify --deep --strict --verbose=2 "${APP_PATH}" >/dev/null

printf 'DMG 内容校验通过：%s\n' "${DMG_PATH}"
