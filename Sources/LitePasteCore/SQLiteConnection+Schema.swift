import Foundation
import SQLite3

extension SQLiteConnection {
  func ensureSchema() throws {
    try execute("""
      CREATE TABLE IF NOT EXISTS clipboard_records (
        id TEXT PRIMARY KEY NOT NULL,
        kind TEXT NOT NULL,
        title TEXT NOT NULL,
        search_text TEXT NOT NULL,
        note TEXT NOT NULL,
        source_app_bundle_id TEXT,
        source_app_name TEXT,
        created_at REAL NOT NULL,
        last_copied_at REAL NOT NULL,
        last_used_at REAL,
        copy_count INTEGER NOT NULL,
        is_favorite INTEGER NOT NULL,
        is_pinned INTEGER NOT NULL,
        pin_shortcut TEXT,
        content_hash TEXT NOT NULL,
        plain_text TEXT,
        ocr_text TEXT,
        contents_json BLOB NOT NULL,
        preview_file_path TEXT,
        position INTEGER NOT NULL
      )
      """)
    try addColumnIfNeeded(table: "clipboard_records", column: "ocr_text", definition: "ocr_text TEXT")
    try execute("CREATE INDEX IF NOT EXISTS idx_clipboard_records_content_hash ON clipboard_records(content_hash)")
    try execute("CREATE INDEX IF NOT EXISTS idx_clipboard_records_last_copied_at ON clipboard_records(last_copied_at DESC)")
    try execute("CREATE INDEX IF NOT EXISTS idx_clipboard_records_kind ON clipboard_records(kind)")
    try execute("CREATE INDEX IF NOT EXISTS idx_clipboard_records_favorite ON clipboard_records(is_favorite, last_copied_at DESC)")
    try execute("CREATE INDEX IF NOT EXISTS idx_clipboard_records_pinned ON clipboard_records(is_pinned, last_copied_at DESC)")
    try execute("CREATE INDEX IF NOT EXISTS idx_clipboard_records_copy_count ON clipboard_records(copy_count DESC, last_copied_at DESC)")
  }

  private func addColumnIfNeeded(table: String, column: String, definition: String) throws {
    let columns = try columnNames(in: table)
    guard !columns.contains(column) else {
      return
    }

    try execute("ALTER TABLE \(table) ADD COLUMN \(definition)")
  }

  private func columnNames(in table: String) throws -> Set<String> {
    let statement = try prepare("PRAGMA table_info(\(table))")
    defer { sqlite3_finalize(statement) }

    var names = Set<String>()
    var stepResult = sqlite3_step(statement)
    while stepResult == SQLITE_ROW {
      if let name = SQLiteClipboardRecordCoder.text(at: 1, in: statement) {
        names.insert(name)
      }
      stepResult = sqlite3_step(statement)
    }

    guard stepResult == SQLITE_DONE else {
      throw SQLiteRepositoryError.operationFailed(errorMessage)
    }
    return names
  }
}
