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
TOKEN="LitePaste runtime smoke $(date +%s)"
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

LITEPASTE_APPLICATION_SUPPORT_DIR="${DATA_DIR}" "${APP_EXECUTABLE}" >"${APP_LOG}" 2>&1 &
APP_PID="$!"

for _ in {1..20}; do
  if [[ -f "${HISTORY_DB}" ]]; then
    break
  fi

  if ! kill -0 "${APP_PID}" >/dev/null 2>&1; then
    echo "Lite Paste exited before creating history database." >&2
    cat "${APP_LOG}" >&2 || true
    exit 1
  fi

  sleep 0.25
done

printf '%s' "${TOKEN}" | pbcopy

for _ in {1..40}; do
  if [[ -f "${HISTORY_DB}" ]]; then
    MATCH_COUNT="$(
      sqlite3 "${HISTORY_DB}" \
        "select count(*) from clipboard_records where plain_text = '${TOKEN//\'/\'\'}';"
    )"

    if [[ "${MATCH_COUNT}" == "1" ]]; then
      echo "Runtime capture smoke passed."
      exit 0
    fi
  fi

  if ! kill -0 "${APP_PID}" >/dev/null 2>&1; then
    echo "Lite Paste exited before capturing clipboard content." >&2
    cat "${APP_LOG}" >&2 || true
    exit 1
  fi

  sleep 0.25
done

echo "Lite Paste did not capture runtime clipboard content in time." >&2
cat "${APP_LOG}" >&2 || true
exit 1
