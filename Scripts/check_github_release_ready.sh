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

required_secrets=(
  DEVELOPER_ID_APPLICATION
  DEVELOPER_ID_CERTIFICATE_BASE64
  DEVELOPER_ID_CERTIFICATE_PASSWORD
  APPLE_ID
  APP_SPECIFIC_PASSWORD
  APPLE_TEAM_ID
)

fail() {
  printf 'GitHub 正式发布条件未满足：%s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "缺少命令 $1"
}

check_repo_state() {
  local is_private
  local license_key
  local current_commit
  local origin_commit

  git fetch origin "${TARGET_BRANCH}" --tags >/dev/null 2>&1 ||
    fail "无法获取 origin/${TARGET_BRANCH}"

  current_commit="$(git rev-parse HEAD)"
  origin_commit="$(git rev-parse "origin/${TARGET_BRANCH}")"
  [[ "${current_commit}" == "${origin_commit}" ]] ||
    fail "当前提交与 origin/${TARGET_BRANCH} 不一致，请先推送 main"

  is_private="$(gh repo view "${REPO}" --json isPrivate --jq '.isPrivate')"
  [[ "${is_private}" == "false" ]] || fail "GitHub 仓库还不是公开仓库：${REPO}"

  license_key="$(gh repo view "${REPO}" --json licenseInfo --jq '.licenseInfo.key // ""')"
  [[ -n "${license_key}" ]] || fail "GitHub 仓库没有识别到开源协议"
}

check_workflow() {
  gh workflow view release.yml --repo "${REPO}" >/dev/null 2>&1 ||
    fail "找不到 Release workflow"

  gh workflow list --repo "${REPO}" --all |
    awk '$1 == "Release" && $2 == "active" { found = 1 } END { exit found ? 0 : 1 }' ||
    fail "Release workflow 未启用"
}

check_release_target() {
  [[ -f "${NOTES_PATH}" ]] || fail "缺少发布说明文件：${NOTES_PATH}"

  if gh release view "${TAG}" --repo "${REPO}" >/dev/null 2>&1; then
    fail "GitHub Release 已存在：${TAG}"
  fi

  if git ls-remote --exit-code --tags origin "refs/tags/${TAG}" >/dev/null 2>&1; then
    fail "远端 tag 已存在：${TAG}"
  fi
}

check_release_secrets() {
  local secret_names
  local missing=()

  secret_names="$(gh secret list --repo "${REPO}" --app actions --json name --jq '.[].name')"
  for name in "${required_secrets[@]}"; do
    if ! grep -Fxq "${name}" <<<"${secret_names}"; then
      missing+=("${name}")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    fail "缺少 GitHub Actions secrets：${missing[*]}"
  fi
}

cd "${ROOT_DIR}"

require_command gh
require_command git

VERSION="${VERSION}" BUILD="${BUILD}" Scripts/verify_metadata.sh >/dev/null
check_repo_state
check_workflow
check_release_target
check_release_secrets

printf 'GitHub 正式发布条件已就绪：%s %s (%s)\n' "${REPO}" "${VERSION}" "${BUILD}"
