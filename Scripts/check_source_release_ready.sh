#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="${ROOT_DIR}/Config/LitePaste/Info.plist"
REPO="${GITHUB_REPOSITORY:-fengems/lite_paste}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "${INFO_PLIST}"
}

VERSION="${VERSION:-$(plist_value CFBundleShortVersionString)}"
BUILD="${BUILD:-$(plist_value CFBundleVersion)}"
TAG="${TAG:-${VERSION}}"
NOTES_PATH="${NOTES_PATH:-${ROOT_DIR}/docs/releases/${TAG}.md}"

fail() {
  printf 'GitHub 源码发布条件未满足：%s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "缺少命令 $1"
}

cd "${ROOT_DIR}"

require_command gh
require_command git

VERSION="${VERSION}" BUILD="${BUILD}" Scripts/verify_metadata.sh >/dev/null

git fetch origin "${TARGET_BRANCH}" --tags >/dev/null 2>&1 ||
  fail "无法获取 origin/${TARGET_BRANCH}"

current_commit="$(git rev-parse HEAD)"
origin_commit="$(git rev-parse "origin/${TARGET_BRANCH}")"
[[ "${current_commit}" == "${origin_commit}" ]] ||
  fail "当前提交与 origin/${TARGET_BRANCH} 不一致，请先推送 ${TARGET_BRANCH}"

is_private="$(gh repo view "${REPO}" --json isPrivate --jq '.isPrivate')"
[[ "${is_private}" == "false" ]] || fail "GitHub 仓库还不是公开仓库：${REPO}"

license_key="$(gh repo view "${REPO}" --json licenseInfo --jq '.licenseInfo.key // ""')"
[[ -n "${license_key}" ]] || fail "GitHub 仓库没有识别到开源协议"

[[ -f "${NOTES_PATH}" ]] || fail "缺少发布说明文件：${NOTES_PATH}"

if gh release view "${TAG}" --repo "${REPO}" >/dev/null 2>&1; then
  fail "GitHub Release 已存在：${TAG}"
fi

if git ls-remote --exit-code --tags origin "refs/tags/${TAG}" >/dev/null 2>&1; then
  fail "远端 tag 已存在：${TAG}"
fi

printf 'GitHub 源码发布条件已就绪：%s %s (%s)\n' "${REPO}" "${VERSION}" "${BUILD}"
