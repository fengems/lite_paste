#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="${ROOT_DIR}/Config/LitePaste/Info.plist"
REPO="${GITHUB_REPOSITORY:-fengems/lite_paste}"

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "${INFO_PLIST}"
}

VERSION="${VERSION:-$(plist_value CFBundleShortVersionString)}"
BUILD="${BUILD:-$(plist_value CFBundleVersion)}"
TAG="${TAG:-${VERSION}}"
NOTES_PATH="${NOTES_PATH:-${ROOT_DIR}/docs/releases/${TAG}.md}"
PRERELEASE="${PRERELEASE:-1}"

cd "${ROOT_DIR}"

VERSION="${VERSION}" \
BUILD="${BUILD}" \
TAG="${TAG}" \
NOTES_PATH="${NOTES_PATH}" \
Scripts/check_source_release_ready.sh

release_flags=()
if [[ "${PRERELEASE}" == "1" ]]; then
  release_flags+=(--prerelease)
fi

gh release create "${TAG}" \
  --repo "${REPO}" \
  --target "$(git rev-parse HEAD)" \
  --title "Lite Paste ${TAG}" \
  --notes-file "${NOTES_PATH}" \
  "${release_flags[@]}"

printf 'GitHub 源码 Release 已创建：%s\n' "${TAG}"
