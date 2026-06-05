#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/Scripts/lib/app_flavor.sh"
litepaste_configure_flavor

CONFIGURATION="${CONFIGURATION:-release}"
LOCAL_CODESIGN_IDENTITY="LitePaste Local Code Signing"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
PRODUCT_NAME="${LITEPASTE_PRODUCT_NAME}"
APP_DISPLAY_NAME="${LITEPASTE_APP_DISPLAY_NAME}"
APP_BUNDLE_NAME="${LITEPASTE_APP_BUNDLE_NAME}"
OUTPUT_DIR="${ROOT_DIR}/Build"
APP_DIR="${OUTPUT_DIR}/${APP_BUNDLE_NAME}"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
INFO_PLIST_SOURCE="${ROOT_DIR}/Config/LitePaste/Info.plist"
INFO_PLIST_DESTINATION="${CONTENTS_DIR}/Info.plist"
ENTITLEMENTS_SOURCE="${ROOT_DIR}/Config/LitePaste/LitePaste.entitlements"
ICON_DESTINATION="${RESOURCES_DIR}/AppIcon.icns"
OPEN_APP=false
INCLUDE_ICLOUD_ENTITLEMENTS="${INCLUDE_ICLOUD_ENTITLEMENTS:-${ENABLE_ICLOUD_ENTITLEMENTS:-0}}"
RESOLVED_ENTITLEMENTS_PATH=""

usage() {
  cat <<'USAGE'
用法：
  Scripts/build_app_bundle.sh [--open]

生成本地 .app，复制 Info.plist，生成 App 图标，并执行本地签名。

选项：
  --open   打包成功后直接打开 App。
  --help   显示帮助。

环境变量：
  LITEPASTE_FLAVOR  构建通道，stable 或 dev；默认 stable。
  CONFIGURATION      SwiftPM 构建配置，默认 release。
  CODESIGN_IDENTITY  代码签名身份，默认优先使用本地 LitePaste Local Code Signing，否则 ad-hoc。
  INCLUDE_ICLOUD_ENTITLEMENTS  设置为 1/true/yes 时签入 iCloud Documents entitlement；默认关闭。
  TEAM_ID            iCloud entitlement 的团队 ID；设置后会替换 $(TeamIdentifierPrefix)。
  TEAM_IDENTIFIER_PREFIX  完整团队前缀，例如 ABCDE12345.，优先级高于 TEAM_ID。
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

is_truthy() {
  case "$1" in
    1|true|TRUE|yes|YES|on|ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

resolved_entitlements() {
  local destination="${OUTPUT_DIR}/${LITEPASTE_ARCHIVE_PRODUCT_NAME}.resolved.entitlements"
  local team_prefix="${TEAM_IDENTIFIER_PREFIX:-}"
  if [[ -z "${team_prefix}" && -n "${TEAM_ID:-}" ]]; then
    team_prefix="${TEAM_ID}."
  fi
  if [[ -z "${team_prefix}" ]]; then
    printf '开启 iCloud entitlement 时必须设置 TEAM_ID 或 TEAM_IDENTIFIER_PREFIX。\n' >&2
    exit 65
  fi

  mkdir -p "${OUTPUT_DIR}"
  sed "s/\$(TeamIdentifierPrefix)/${team_prefix}/g" "${ENTITLEMENTS_SOURCE}" > "${destination}"
  printf '%s\n' "${destination}"
}

prepare_icloud_entitlements() {
  if ! is_truthy "${INCLUDE_ICLOUD_ENTITLEMENTS}"; then
    return 0
  fi

  if [[ "${CODESIGN_IDENTITY}" == "-" || "${CODESIGN_IDENTITY}" == "${LOCAL_CODESIGN_IDENTITY}" ]]; then
    printf '本地或 ad-hoc 签名不能可靠使用 iCloud Documents entitlement。\n' >&2
    printf '请使用 Apple Development/Developer ID 签名身份，并设置 TEAM_ID 或 TEAM_IDENTIFIER_PREFIX。\n' >&2
    exit 65
  fi

  RESOLVED_ENTITLEMENTS_PATH="$(resolved_entitlements)"
}

configure_info_plist() {
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${APP_DISPLAY_NAME}" "${INFO_PLIST_DESTINATION}"
  /usr/libexec/PlistBuddy -c "Set :CFBundleName ${APP_DISPLAY_NAME}" "${INFO_PLIST_DESTINATION}"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${LITEPASTE_BUNDLE_IDENTIFIER}" "${INFO_PLIST_DESTINATION}"
  /usr/libexec/PlistBuddy -c "Set :NSAppleEventsUsageDescription ${APP_DISPLAY_NAME} 需要在用户触发粘贴时把内容发送到上一个活跃应用。" "${INFO_PLIST_DESTINATION}"
}

cd "${ROOT_DIR}"

step "准备 ${APP_DISPLAY_NAME} 本地 App 包。"
printf '构建通道：%s\n' "${LITEPASTE_FLAVOR}"
printf 'Bundle ID：%s\n' "${LITEPASTE_BUNDLE_IDENTIFIER}"

if [[ -z "${CODESIGN_IDENTITY}" ]]; then
  step "选择代码签名身份..."
  if security find-identity -v -p codesigning 2>/dev/null | grep -Fq "\"${LOCAL_CODESIGN_IDENTITY}\""; then
    CODESIGN_IDENTITY="${LOCAL_CODESIGN_IDENTITY}"
  else
    CODESIGN_IDENTITY="-"
  fi
fi

prepare_icloud_entitlements

step "构建 ${CONFIGURATION} 版本..."
swift build -c "${CONFIGURATION}" --product "${PRODUCT_NAME}"

EXECUTABLE_PATH="$(swift build -c "${CONFIGURATION}" --product "${PRODUCT_NAME}" --show-bin-path)/${PRODUCT_NAME}"

step "组装 ${APP_BUNDLE_NAME}..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${EXECUTABLE_PATH}" "${MACOS_DIR}/${PRODUCT_NAME}"
cp "${INFO_PLIST_SOURCE}" "${INFO_PLIST_DESTINATION}"
configure_info_plist
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
  codesign_args=(--force --sign "${CODESIGN_IDENTITY}")
  if [[ -n "${RESOLVED_ENTITLEMENTS_PATH}" ]]; then
    codesign_args=(--force --entitlements "${RESOLVED_ENTITLEMENTS_PATH}" --sign "${CODESIGN_IDENTITY}")
  fi
  codesign "${codesign_args[@]}" "${APP_DIR}" >/dev/null
fi

printf '\n%s 已生成：%s\n' "${APP_DISPLAY_NAME}" "${APP_DIR}"
printf '签名身份：%s\n' "${CODESIGN_IDENTITY}"
if [[ -n "${RESOLVED_ENTITLEMENTS_PATH}" ]]; then
  printf 'iCloud entitlement：已启用\n'
else
  printf 'iCloud entitlement：未启用（本地验收包默认设置）\n'
fi

if "${OPEN_APP}"; then
  printf '正在打开 App...\n'
  open "${APP_DIR}"
else
  printf '可手动打开：open %s\n' "${APP_DIR}"
fi
