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
FILE_PATH="${DATA_DIR}/LitePaste Runtime File ${STAMP}.txt"
HTML_PLAIN_VALUE="LitePaste runtime html ${STAMP}"
RTF_PLAIN_VALUE="LitePaste runtime rtf ${STAMP}"
CLIPBOARD_SNAPSHOT="${DATA_DIR}/clipboard-snapshot.json"
APP_PID=""

cleanup() {
  if [[ -n "${APP_PID}" ]] && kill -0 "${APP_PID}" >/dev/null 2>&1; then
    kill "${APP_PID}" >/dev/null 2>&1 || true
    wait "${APP_PID}" 2>/dev/null || true
  fi

  restore_clipboard_snapshot
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

  set_clipboard "text" "${value}"
  wait_for_sql_capture \
    "${kind} clipboard content: ${value}" \
    "select count(*) from clipboard_records where plain_text = '${value}' and kind = '${kind}';"
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

LITEPASTE_APPLICATION_SUPPORT_DIR="${DATA_DIR}" "${APP_EXECUTABLE}" >"${APP_LOG}" 2>&1 &
APP_PID="$!"

snapshot_clipboard
wait_for_history_db
wait_for_capture "${TEXT_VALUE}" "text"
wait_for_capture "${URL_VALUE}" "url"
wait_for_capture "${EMAIL_VALUE}" "email"
wait_for_capture "${COLOR_VALUE}" "color"

printf '%s' "Lite Paste runtime file" >"${FILE_PATH}"
set_clipboard "file" "${FILE_PATH}"
wait_for_sql_capture \
  "files clipboard content: ${FILE_PATH}" \
  "select count(*) from clipboard_records where plain_text = '${FILE_PATH}' and kind = 'files';"

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

echo "Runtime capture smoke passed."
