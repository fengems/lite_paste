#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${ROOT_DIR}/Build/LitePaste.app"
LOG_PATH="${ROOT_DIR}/Build/prepare_manual_check.log"
RUN_SMOKE=false
OPEN_APP=true
VERBOSE=false

usage() {
  cat <<'USAGE'
用法：
  Scripts/prepare_manual_check.sh [--with-smoke] [--no-open] [--verbose]

用于准备人工验收本地 App。默认会验证 metadata、确认 Xcode 可构建
SwiftPM scheme、运行核心检查、生成 Build/LitePaste.app、校验 Info.plist
和签名，并在成功后直接打开 App。

选项：
  --with-smoke   额外运行真实剪贴板采集/恢复烟测。
  --open         成功后打开 App。兼容旧用法，默认已开启。
  --no-open      成功后不打开 App。
  --verbose      同时在终端显示底层构建日志。
  --help         显示帮助。
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-smoke)
      RUN_SMOKE=true
      ;;
    --open)
      OPEN_APP=true
      ;;
    --no-open)
      OPEN_APP=false
      ;;
    --verbose)
      VERBOSE=true
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

TOTAL_STEPS=6
if "${RUN_SMOKE}"; then
  TOTAL_STEPS=7
fi

STEP=0

run_step() {
  local title="$1"
  shift
  STEP=$((STEP + 1))
  printf '\n[%d/%d] %s\n' "${STEP}" "${TOTAL_STEPS}" "${title}"
  printf '命令：%s\n' "$*"
  printf '\n[%d/%d] %s\n命令：%s\n' "${STEP}" "${TOTAL_STEPS}" "${title}" "$*" >>"${LOG_PATH}"

  local status=0
  set +e
  if "${VERBOSE}"; then
    "$@" 2>&1 | tee -a "${LOG_PATH}"
    status=${PIPESTATUS[0]}
  else
    "$@" >>"${LOG_PATH}" 2>&1
    status=$?
  fi
  set -e

  if [[ "${status}" -eq 0 ]]; then
    printf '完成：%s\n' "${title}"
    return 0
  fi

  printf '\n失败：%s\n' "${title}" >&2
  printf '退出码：%d\n' "${status}" >&2
  printf '完整日志：%s\n' "${LOG_PATH}" >&2
  printf '\n最近日志：\n' >&2
  tail -n 80 "${LOG_PATH}" >&2 || true
  exit "${status}"
}

cd "${ROOT_DIR}"

mkdir -p "$(dirname "${LOG_PATH}")"
{
  printf 'Lite Paste 人工验收准备日志\n'
  printf '工作目录：%s\n' "${ROOT_DIR}"
  printf '开始时间：%s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
} >"${LOG_PATH}"

printf '开始准备 Lite Paste 人工验收包。\n'
printf '详细日志：%s\n' "${LOG_PATH}"

run_step "校验项目 metadata" Scripts/verify_metadata.sh
run_step "验证 Xcode 能构建 SwiftPM scheme" xcodebuild -scheme LitePaste -destination "platform=macOS" -configuration Debug build
run_step "运行核心检查" swift run LitePasteCoreChecks
run_step "生成本地 App 包" env CONFIGURATION=release Scripts/build_app_bundle.sh

if "${RUN_SMOKE}"; then
  run_step "运行真实剪贴板采集/恢复烟测" Scripts/smoke_runtime_capture.sh
fi

run_step "校验 Info.plist" plutil -lint "${APP_PATH}/Contents/Info.plist"
run_step "校验 App 签名" codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

printf '\nLite Paste 人工验收包已准备好：%s\n' "${APP_PATH}"

if "${OPEN_APP}"; then
  printf '正在打开 App...\n'
  open "${APP_PATH}"
else
  printf '可手动打开：open %s\n' "${APP_PATH}"
fi

printf '完整日志：%s\n' "${LOG_PATH}"
