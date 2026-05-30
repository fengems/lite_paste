#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
LOCAL_CODESIGN_IDENTITY="LitePaste Local Code Signing"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
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
ICON_DESTINATION="${RESOURCES_DIR}/AppIcon.icns"
OPEN_APP=false

usage() {
  cat <<'USAGE'
用法：
  Scripts/build_app_bundle.sh [--open]

生成 Build/LitePaste.app，复制 Info.plist，生成 App 图标，并执行本地签名。

选项：
  --open   打包成功后直接打开 App。
  --help   显示帮助。

环境变量：
  CONFIGURATION      SwiftPM 构建配置，默认 release。
  CODESIGN_IDENTITY  代码签名身份，默认优先使用本地 LitePaste Local Code Signing，否则 ad-hoc。
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --open)
      OPEN_APP=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "未知选项：$1" >&2
      usage >&2
      exit 64
      ;;
  esac
  shift
done

step() {
  printf '\n%s\n' "$1"
}

cd "${ROOT_DIR}"

step "准备 Lite Paste 本地 App 包。"

if [[ -z "${CODESIGN_IDENTITY}" ]]; then
  step "选择代码签名身份..."
  if security find-identity -v -p codesigning 2>/dev/null | grep -Fq "\"${LOCAL_CODESIGN_IDENTITY}\""; then
    CODESIGN_IDENTITY="${LOCAL_CODESIGN_IDENTITY}"
  else
    CODESIGN_IDENTITY="-"
  fi
fi

step "构建 ${CONFIGURATION} 版本..."
swift build -c "${CONFIGURATION}" --product "${PRODUCT_NAME}"

EXECUTABLE_PATH="$(swift build -c "${CONFIGURATION}" --product "${PRODUCT_NAME}" --show-bin-path)/${PRODUCT_NAME}"

step "组装 ${APP_BUNDLE_NAME}..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${EXECUTABLE_PATH}" "${MACOS_DIR}/${PRODUCT_NAME}"
cp "${INFO_PLIST_SOURCE}" "${INFO_PLIST_DESTINATION}"
step "生成 App 图标..."
swift "${ROOT_DIR}/Scripts/generate_app_icon.swift" "${ICON_DESTINATION}"
printf 'APPL????' > "${CONTENTS_DIR}/PkgInfo"

chmod +x "${MACOS_DIR}/${PRODUCT_NAME}"

if command -v plutil >/dev/null 2>&1; then
  step "校验 Info.plist..."
  plutil -lint "${INFO_PLIST_DESTINATION}" >/dev/null
fi

if command -v codesign >/dev/null 2>&1; then
  step "签名 App..."
  codesign --force --sign "${CODESIGN_IDENTITY}" "${APP_DIR}" >/dev/null
fi

printf '\n%s 已生成：%s\n' "${APP_DISPLAY_NAME}" "${APP_DIR}"
printf '签名身份：%s\n' "${CODESIGN_IDENTITY}"

if "${OPEN_APP}"; then
  printf '正在打开 App...\n'
  open "${APP_DIR}"
else
  printf '可手动打开：open %s\n' "${APP_DIR}"
fi
