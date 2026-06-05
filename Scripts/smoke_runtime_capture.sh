#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/Scripts/lib/app_flavor.sh"
litepaste_configure_flavor

APP_EXECUTABLE="${ROOT_DIR}/Build/${LITEPASTE_APP_BUNDLE_NAME}/Contents/MacOS/LitePaste"

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
MAX_RSS_KB="${LITEPASTE_RUNTIME_SMOKE_MAX_RSS_KB:-200000}"
STAMP="$(date +%s)"
TEXT_VALUE="LitePaste runtime text ${STAMP}"
URL_VALUE="https://litepaste-smoke.example/${STAMP}"
EMAIL_VALUE="litepaste-smoke-${STAMP}@example.com"
COLOR_VALUE="#A1B2C3"
PAUSED_MONITORING_VALUE="LitePaste paused monitoring smoke ${STAMP}"
DISABLED_TEXT_VALUE="LitePaste disabled text smoke ${STAMP}"
IGNORED_APP_VALUE="LitePaste ignored app smoke ${STAMP}"
FILE_PATH="${DATA_DIR}/LitePaste Runtime File ${STAMP}.txt"
HTML_PLAIN_VALUE="LitePaste runtime html ${STAMP}"
RTF_PLAIN_VALUE="LitePaste runtime rtf ${STAMP}"
CLIPBOARD_SNAPSHOT="${DATA_DIR}/clipboard-snapshot.json"
APP_PID=""
IGNORED_APP_BUNDLE_IDS_JSON=""

running_app_bundle_ids_json() {
  swift - <<'SWIFT'
import AppKit
import Foundation

let bundleIDs = NSWorkspace.shared.runningApplications
  .compactMap(\.bundleIdentifier)
  .filter { !$0.isEmpty }
let data = try JSONSerialization.data(withJSONObject: Array(Set(bundleIDs)).sorted())
print(String(data: data, encoding: .utf8) ?? "[]")
SWIFT
}

cleanup() {
  stop_app
  restore_clipboard_snapshot
  rm -rf "${DATA_DIR}"
}
trap cleanup EXIT

stop_app() {
  if [[ -n "${APP_PID}" ]] && kill -0 "${APP_PID}" >/dev/null 2>&1; then
    kill "${APP_PID}" >/dev/null 2>&1 || true
    wait "${APP_PID}" 2>/dev/null || true
  fi

  APP_PID=""
}

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

write_monitoring_paused_setting() {
  local enabled="$1"

  cat >"${DATA_DIR}/settings.json" <<JSON
{
  "isMonitoringPaused" : ${enabled}
}
JSON
}

write_enabled_types_setting() {
  local types_json="$1"

  cat >"${DATA_DIR}/settings.json" <<JSON
{
  "enabledTypes" : ${types_json},
  "isMonitoringPaused" : false
}
JSON
}

write_ignored_apps_setting() {
  IGNORED_APP_BUNDLE_IDS_JSON="$(running_app_bundle_ids_json)"

  cat >"${DATA_DIR}/settings.json" <<JSON
{
  "ignoredApps" : ${IGNORED_APP_BUNDLE_IDS_JSON},
  "isMonitoringPaused" : false
}
JSON
}

start_app() {
  LITEPASTE_FLAVOR="${LITEPASTE_FLAVOR}" \
    LITEPASTE_APPLICATION_SUPPORT_DIR="${DATA_DIR}" \
    "${APP_EXECUTABLE}" >"${APP_LOG}" 2>&1 &
  APP_PID="$!"
}

wait_for_capture() {
  local value="$1"
  local kind="$2"

  settle_pasteboard
  set_clipboard "text" "${value}"
  wait_for_sql_capture \
    "${kind} clipboard content: ${value}" \
    "select count(*) from clipboard_records where plain_text = '${value}' and kind = '${kind}';"
}

assert_paused_monitoring_blocks_capture() {
  settle_pasteboard
  set_clipboard "text" "${PAUSED_MONITORING_VALUE}"

  for _ in {1..12}; do
    assert_app_running
    sleep 0.25

    if [[ -f "${HISTORY_DB}" ]]; then
      local match_count
      match_count="$(
        sqlite3 -cmd ".timeout 5000" "${HISTORY_DB}" \
          "select count(*) from clipboard_records where plain_text = '${PAUSED_MONITORING_VALUE}';" 2>/dev/null || printf '0'
      )"

      if [[ "${match_count}" != "0" ]]; then
        echo "Lite Paste captured clipboard content while monitoring was paused." >&2
        sqlite3 -cmd ".timeout 5000" "${HISTORY_DB}" \
          "select kind, title, plain_text from clipboard_records order by last_copied_at desc limit 10;" >&2 || true
        cat "${APP_LOG}" >&2 || true
        exit 1
      fi
    fi
  done
}

assert_text_type_disabled_blocks_capture() {
  settle_pasteboard
  set_clipboard "text" "${DISABLED_TEXT_VALUE}"

  for _ in {1..12}; do
    assert_app_running
    sleep 0.25

    if [[ -f "${HISTORY_DB}" ]]; then
      local match_count
      match_count="$(
        sqlite3 -cmd ".timeout 5000" "${HISTORY_DB}" \
          "select count(*) from clipboard_records where plain_text = '${DISABLED_TEXT_VALUE}';" 2>/dev/null || printf '0'
      )"

      if [[ "${match_count}" != "0" ]]; then
        echo "Lite Paste captured disabled text content while only image capture was enabled." >&2
        sqlite3 -cmd ".timeout 5000" "${HISTORY_DB}" \
          "select kind, title, plain_text from clipboard_records order by last_copied_at desc limit 10;" >&2 || true
        cat "${APP_LOG}" >&2 || true
        exit 1
      fi
    fi
  done
}

assert_ignored_app_blocks_capture() {
  if [[ "${IGNORED_APP_BUNDLE_IDS_JSON}" == "[]" ]]; then
    echo "Unable to determine running app bundle ids for ignored-app runtime smoke." >&2
    exit 1
  fi

  settle_pasteboard
  set_clipboard "text" "${IGNORED_APP_VALUE}"

  for _ in {1..12}; do
    assert_app_running
    sleep 0.25

    if [[ -f "${HISTORY_DB}" ]]; then
      local match_count
      match_count="$(
        sqlite3 -cmd ".timeout 5000" "${HISTORY_DB}" \
          "select count(*) from clipboard_records where plain_text = '${IGNORED_APP_VALUE}';" 2>/dev/null || printf '0'
      )"

      if [[ "${match_count}" != "0" ]]; then
        echo "Lite Paste captured content from an ignored running app." >&2
        sqlite3 -cmd ".timeout 5000" "${HISTORY_DB}" \
          "select kind, title, source_app_bundle_id, plain_text from clipboard_records order by last_copied_at desc limit 10;" >&2 || true
        echo "Ignored bundle ids: ${IGNORED_APP_BUNDLE_IDS_JSON}" >&2
        cat "${APP_LOG}" >&2 || true
        exit 1
      fi
    fi
  done
}

assert_not_captured() {
  local value="$1"
  local description="$2"

  if [[ ! -f "${HISTORY_DB}" ]]; then
    return
  fi

  local match_count
  match_count="$(
    sqlite3 -cmd ".timeout 5000" "${HISTORY_DB}" \
      "select count(*) from clipboard_records where plain_text = '${value}';" 2>/dev/null || printf '0'
  )"

  if [[ "${match_count}" != "0" ]]; then
    echo "Lite Paste unexpectedly captured ${description}." >&2
    sqlite3 -cmd ".timeout 5000" "${HISTORY_DB}" \
      "select kind, title, plain_text from clipboard_records order by last_copied_at desc limit 10;" >&2 || true
    cat "${APP_LOG}" >&2 || true
    exit 1
  fi
}

run_clipboard_helper() {
  local mode="$1"
  local value="${2:-}"

  swift - "${mode}" "${value}" <<'SWIFT'
import AppKit
import Foundation

let mode = CommandLine.arguments[1]
let value = CommandLine.arguments[2]
let pasteboard = NSPasteboard.general

struct ClipboardSnapshot: Codable {
  var items: [ClipboardItemSnapshot]
}

struct ClipboardItemSnapshot: Codable {
  var values: [ClipboardValueSnapshot]
}

struct ClipboardValueSnapshot: Codable {
  var type: String
  var base64Data: String
}

switch mode {
case "snapshot":
  let items = (pasteboard.pasteboardItems ?? []).map { item in
    ClipboardItemSnapshot(
      values: item.types.compactMap { type in
        item.data(forType: type).map {
          ClipboardValueSnapshot(type: type.rawValue, base64Data: $0.base64EncodedString())
        }
      }
    )
  }
  let snapshot = ClipboardSnapshot(items: items)
  let data = try JSONEncoder().encode(snapshot)
  try data.write(to: URL(fileURLWithPath: value), options: .atomic)

case "restore":
  let url = URL(fileURLWithPath: value)
  guard FileManager.default.fileExists(atPath: url.path) else {
    break
  }

  let snapshot = try JSONDecoder().decode(ClipboardSnapshot.self, from: Data(contentsOf: url))
  pasteboard.clearContents()

  let items = snapshot.items.map { itemSnapshot in
    let item = NSPasteboardItem()
    for valueSnapshot in itemSnapshot.values {
      if let data = Data(base64Encoded: valueSnapshot.base64Data) {
        item.setData(data, forType: NSPasteboard.PasteboardType(valueSnapshot.type))
      }
    }
    return item
  }
  _ = pasteboard.writeObjects(items)

case "text":
  pasteboard.clearContents()
  pasteboard.setString(value, forType: .string)

case "file":
  pasteboard.clearContents()
  let url = URL(fileURLWithPath: value)
  _ = pasteboard.writeObjects([url as NSURL])

case "image":
  pasteboard.clearContents()
  let pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR42mP8z8BQDwAFgwJ/lUtN4wAAAABJRU5ErkJggg=="
  guard let data = Data(base64Encoded: pngBase64) else {
    fatalError("Invalid embedded PNG data")
  }
  pasteboard.setData(data, forType: .png)

case "html":
  pasteboard.clearContents()
  pasteboard.setString(value, forType: .string)
  let html = "<p><strong>\(value)</strong></p>"
  pasteboard.setData(Data(html.utf8), forType: .html)

case "rtf":
  pasteboard.clearContents()
  let attributedString = NSAttributedString(
    string: value,
    attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
  )
  _ = pasteboard.writeObjects([attributedString])

default:
  fatalError("Unsupported clipboard mode: \(mode)")
}
SWIFT
}

snapshot_clipboard() {
  run_clipboard_helper "snapshot" "${CLIPBOARD_SNAPSHOT}"
}

restore_clipboard_snapshot() {
  if [[ -f "${CLIPBOARD_SNAPSHOT}" ]]; then
    run_clipboard_helper "restore" "${CLIPBOARD_SNAPSHOT}" 2>/dev/null || true
  fi
}

set_clipboard() {
  run_clipboard_helper "$@"
}

settle_pasteboard() {
  sleep 0.8
}

wait_for_sql_capture() {
  local description="$1"
  local sql="$2"

  for _ in {1..60}; do
    if [[ -f "${HISTORY_DB}" ]]; then
      MATCH_COUNT="$(
        sqlite3 -cmd ".timeout 5000" "${HISTORY_DB}" "${sql}" 2>/dev/null || printf '0'
      )"

      if [[ "${MATCH_COUNT}" == "1" ]]; then
        return
      fi
    fi

    assert_app_running
    sleep 0.25
  done

  echo "Lite Paste did not capture ${description} in time." >&2
  sqlite3 -cmd ".timeout 5000" "${HISTORY_DB}" \
    "select kind, title, plain_text from clipboard_records order by last_copied_at desc limit 10;" >&2 || true
  cat "${APP_LOG}" >&2 || true
  exit 1
}

assert_memory_within_limit() {
  assert_app_running

  local rss_kb
  rss_kb="$(ps -o rss= -p "${APP_PID}" | tr -d '[:space:]')"

  if [[ -z "${rss_kb}" ]]; then
    echo "Unable to read Lite Paste RSS during runtime smoke." >&2
    exit 1
  fi

  if (( rss_kb > MAX_RSS_KB )); then
    echo "Lite Paste RSS ${rss_kb} KB exceeded runtime smoke limit ${MAX_RSS_KB} KB." >&2
    cat "${APP_LOG}" >&2 || true
    exit 1
  fi

  echo "Runtime memory smoke passed: RSS ${rss_kb} KB <= ${MAX_RSS_KB} KB."
}

snapshot_clipboard
write_monitoring_paused_setting true
start_app
wait_for_history_db
assert_paused_monitoring_blocks_capture
stop_app

write_enabled_types_setting '["image"]'
start_app
wait_for_history_db
assert_text_type_disabled_blocks_capture
stop_app

write_ignored_apps_setting
start_app
wait_for_history_db
assert_ignored_app_blocks_capture
stop_app

write_enabled_types_setting '["text","richText","html","image","files","url","email","color","unknown"]'
start_app
wait_for_history_db
assert_not_captured "${PAUSED_MONITORING_VALUE}" "paused-monitoring smoke content"
assert_not_captured "${DISABLED_TEXT_VALUE}" "disabled-type smoke content"
assert_not_captured "${IGNORED_APP_VALUE}" "ignored-app smoke content"
wait_for_capture "${TEXT_VALUE}" "text"
wait_for_capture "${URL_VALUE}" "url"
wait_for_capture "${EMAIL_VALUE}" "email"
wait_for_capture "${COLOR_VALUE}" "color"

printf '%s' "Lite Paste runtime file" >"${FILE_PATH}"
settle_pasteboard
set_clipboard "file" "${FILE_PATH}"
wait_for_sql_capture \
  "files clipboard content: ${FILE_PATH}" \
  "select count(*) from clipboard_records where plain_text = '${FILE_PATH}' and kind = 'files';"

settle_pasteboard
set_clipboard "image"
wait_for_sql_capture \
  "image clipboard content" \
  "select count(*) from clipboard_records where kind = 'image' and preview_file_path is not null;"

settle_pasteboard
set_clipboard "rtf" "${RTF_PLAIN_VALUE}"
wait_for_sql_capture \
  "rtf clipboard content: ${RTF_PLAIN_VALUE}" \
  "select count(*) from clipboard_records where plain_text = '${RTF_PLAIN_VALUE}' and kind = 'richText';"

settle_pasteboard
set_clipboard "html" "${HTML_PLAIN_VALUE}"
wait_for_sql_capture \
  "html clipboard content: ${HTML_PLAIN_VALUE}" \
  "select count(*) from clipboard_records where plain_text = '${HTML_PLAIN_VALUE}' and kind = 'html';"

assert_memory_within_limit
stop_app
swift run LitePasteRuntimeRestoreChecks \
  "${DATA_DIR}" \
  "${TEXT_VALUE}" \
  "${URL_VALUE}" \
  "${EMAIL_VALUE}" \
  "${COLOR_VALUE}" \
  "${FILE_PATH}" \
  "${HTML_PLAIN_VALUE}" \
  "${RTF_PLAIN_VALUE}" >/dev/null

if grep -q "Unable to update Lite Paste launch at login" "${APP_LOG}"; then
  echo "Lite Paste attempted an unnecessary launch-at-login update during runtime smoke." >&2
  cat "${APP_LOG}" >&2 || true
  exit 1
fi

echo "Runtime capture smoke passed."
