#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_EXECUTABLE="${ROOT_DIR}/Build/LitePaste.app/Contents/MacOS/LitePaste"

if [[ ! -x "${APP_EXECUTABLE}" ]]; then
  echo "Missing app executable: ${APP_EXECUTABLE}" >&2
  echo "Run Scripts/build_app_bundle.sh first." >&2
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3 is required for runtime capture smoke checks." >&2
  exit 1
fi

DATA_DIR="$(mktemp -d "${TMPDIR:-/tmp}/litepaste-runtime-smoke.XXXXXX")"
APP_LOG="${DATA_DIR}/app.log"
HISTORY_DB="${DATA_DIR}/history.sqlite3"
STAMP="$(date +%s)"
TEXT_VALUE="LitePaste runtime text ${STAMP}"
URL_VALUE="https://litepaste-smoke.example/${STAMP}"
EMAIL_VALUE="litepaste-smoke-${STAMP}@example.com"
COLOR_VALUE="#A1B2C3"
PREVIOUS_CLIPBOARD="$(pbpaste 2>/dev/null || true)"
APP_PID=""

cleanup() {
  if [[ -n "${APP_PID}" ]] && kill -0 "${APP_PID}" >/dev/null 2>&1; then
    kill "${APP_PID}" >/dev/null 2>&1 || true
    wait "${APP_PID}" 2>/dev/null || true
  fi

  printf '%s' "${PREVIOUS_CLIPBOARD}" | pbcopy 2>/dev/null || true
  rm -rf "${DATA_DIR}"
}
trap cleanup EXIT

assert_app_running() {
  if ! kill -0 "${APP_PID}" >/dev/null 2>&1; then
    echo "Lite Paste exited during runtime smoke." >&2
    cat "${APP_LOG}" >&2 || true
    exit 1
  fi
}

wait_for_history_db() {
  for _ in {1..20}; do
    if [[ -f "${HISTORY_DB}" ]]; then
      return
    fi

    assert_app_running
    sleep 0.25
  done

  echo "Lite Paste did not create history database in time." >&2
  cat "${APP_LOG}" >&2 || true
  exit 1
}

wait_for_capture() {
  local value="$1"
  local kind="$2"

  printf '%s' "${value}" | pbcopy

  for _ in {1..40}; do
    if [[ -f "${HISTORY_DB}" ]]; then
      MATCH_COUNT="$(
        sqlite3 "${HISTORY_DB}" \
          "select count(*) from clipboard_records where plain_text = '${value}' and kind = '${kind}';"
      )"

      if [[ "${MATCH_COUNT}" == "1" ]]; then
        return
      fi
    fi

    assert_app_running
    sleep 0.25
  done

  echo "Lite Paste did not capture ${kind} clipboard content in time: ${value}" >&2
  sqlite3 "${HISTORY_DB}" "select kind, title, plain_text from clipboard_records order by last_copied_at desc limit 10;" >&2 || true
  cat "${APP_LOG}" >&2 || true
  exit 1
}

LITEPASTE_APPLICATION_SUPPORT_DIR="${DATA_DIR}" "${APP_EXECUTABLE}" >"${APP_LOG}" 2>&1 &
APP_PID="$!"

wait_for_history_db
wait_for_capture "${TEXT_VALUE}" "text"
wait_for_capture "${URL_VALUE}" "url"
wait_for_capture "${EMAIL_VALUE}" "email"
wait_for_capture "${COLOR_VALUE}" "color"

echo "Runtime capture smoke passed."
