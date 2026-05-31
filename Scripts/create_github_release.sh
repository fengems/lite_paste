#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="${ROOT_DIR}/Config/LitePaste/Info.plist"
REPO="${GITHUB_REPOSITORY:-fengems/lite_paste}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"
ALLOW_DETACHED_HEAD="${ALLOW_DETACHED_HEAD:-0}"

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "${INFO_PLIST}"
}

VERSION="${VERSION:-$(plist_value CFBundleShortVersionString)}"
BUILD="${BUILD:-$(plist_value CFBundleVersion)}"
TAG="${TAG:-${VERSION}}"
OUTPUT_DIR="${ROOT_DIR}/Build"
DMG_PATH="${DMG_PATH:-${OUTPUT_DIR}/LitePaste-${VERSION}-${BUILD}.dmg}"
DMG_CHECKSUM_PATH="${DMG_CHECKSUM_PATH:-${DMG_PATH}.sha256}"
ZIP_PATH="${ZIP_PATH:-${OUTPUT_DIR}/LitePaste-${VERSION}-${BUILD}.zip}"
ZIP_CHECKSUM_PATH="${ZIP_CHECKSUM_PATH:-${ZIP_PATH}.sha256}"
NOTES_PATH="${NOTES_PATH:-${ROOT_DIR}/docs/releases/${TAG}.md}"

fail() {
  printf '无法创建 GitHub Release：%s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "缺少命令 $1"
}

require_file() {
  [[ -f "$1" ]] || fail "缺少文件 $1"
}

verify_release_source() {
  local current_branch
  local current_commit
  local origin_commit

  git fetch origin "${TARGET_BRANCH}" --tags >/dev/null 2>&1 ||
    fail "无法获取 origin/${TARGET_BRANCH}"

  current_branch="$(git rev-parse --abbrev-ref HEAD)"
  current_commit="$(git rev-parse HEAD)"
  origin_commit="$(git rev-parse "origin/${TARGET_BRANCH}")"

  if [[ "${ALLOW_DETACHED_HEAD}" != "1" ]]; then
    [[ "${current_branch}" == "${TARGET_BRANCH}" ]] ||
      fail "必须在 ${TARGET_BRANCH} 分支发布"
  fi

  [[ "${current_commit}" == "${origin_commit}" ]] ||
    fail "当前提交与 origin/${TARGET_BRANCH} 不一致"
}

cd "${ROOT_DIR}"

require_command gh
require_command git
require_command shasum
require_command spctl
require_command xcrun

require_file "${DMG_PATH}"
require_file "${DMG_CHECKSUM_PATH}"
require_file "${ZIP_PATH}"
require_file "${ZIP_CHECKSUM_PATH}"
require_file "${NOTES_PATH}"

VERSION="${VERSION}" BUILD="${BUILD}" Scripts/verify_metadata.sh >/dev/null

git diff --quiet || fail "工作区存在未提交改动"
git diff --cached --quiet || fail "暂存区存在未提交改动"
verify_release_source

if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
  fail "tag 已存在：${TAG}"
fi

if git ls-remote --exit-code --tags origin "refs/tags/${TAG}" >/dev/null 2>&1; then
  fail "远端 tag 已存在：${TAG}"
fi

shasum -a 256 -c "${DMG_CHECKSUM_PATH}" >/dev/null
shasum -a 256 -c "${ZIP_CHECKSUM_PATH}" >/dev/null
xcrun stapler validate "${DMG_PATH}" >/dev/null
spctl --assess --type open --verbose=4 "${DMG_PATH}" >/dev/null

gh release create "${TAG}" \
  --repo "${REPO}" \
  --target "$(git rev-parse HEAD)" \
  --title "Lite Paste ${TAG}" \
  --notes-file "${NOTES_PATH}" \
  "${DMG_PATH}" \
  "${DMG_CHECKSUM_PATH}" \
  "${ZIP_PATH}" \
  "${ZIP_CHECKSUM_PATH}"

printf 'GitHub Release 已创建：%s\n' "${TAG}"
