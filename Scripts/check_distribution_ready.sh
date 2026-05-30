#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="${ROOT_DIR}/Config/LitePaste/Info.plist"
IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARIZE="${NOTARIZE:-1}"

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "${INFO_PLIST}"
}

VERSION="${VERSION:-$(plist_value CFBundleShortVersionString)}"
BUILD="${BUILD:-$(plist_value CFBundleVersion)}"

fail() {
  printf '发布环境未就绪：%s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "缺少命令 $1"
}

team_prefix() {
  if [[ -n "${TEAM_IDENTIFIER_PREFIX:-}" ]]; then
    printf '%s\n' "${TEAM_IDENTIFIER_PREFIX}"
    return
  fi

  if [[ -n "${TEAM_ID:-}" ]]; then
    printf '%s.\n' "${TEAM_ID}"
    return
  fi

  printf '\n'
}

check_identity() {
  [[ -n "${IDENTITY}" ]] || fail "缺少 DEVELOPER_ID_APPLICATION"
  security find-identity -v -p codesigning | grep -Fq "\"${IDENTITY}\"" ||
    fail "钥匙串中找不到 Developer ID 签名身份：${IDENTITY}"
}

check_icloud_team_prefix() {
  [[ -n "$(team_prefix)" ]] || fail "iCloud entitlement 需要 TEAM_ID 或 TEAM_IDENTIFIER_PREFIX"
}

check_notary_credentials() {
  [[ "${NOTARIZE}" == "1" ]] || return 0

  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" >/dev/null 2>&1 ||
      fail "notarytool 无法使用 keychain profile：${NOTARY_PROFILE}"
    return 0
  fi

  if [[ -n "${APPLE_ID:-}" && -n "${APP_SPECIFIC_PASSWORD:-}" && -n "${TEAM_ID:-}" ]]; then
    return 0
  fi

  fail "缺少公证凭据。请设置 NOTARY_PROFILE，或 APPLE_ID、APP_SPECIFIC_PASSWORD、TEAM_ID"
}

cd "${ROOT_DIR}"

require_command codesign
require_command ditto
require_command hdiutil
require_command security
require_command shasum
require_command xcrun

VERSION="${VERSION}" BUILD="${BUILD}" Scripts/verify_metadata.sh >/dev/null
check_identity
check_icloud_team_prefix
check_notary_credentials

printf '正式分发环境已就绪：%s (%s)\n' "${VERSION}" "${BUILD}"
