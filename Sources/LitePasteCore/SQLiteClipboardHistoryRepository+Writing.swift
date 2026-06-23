import Foundation
import SQLite3

extension SQLiteClipboardHistoryRepository {
  public func save(_ records: [ClipboardRecord]) throws {
    let connection = try makeConnection()
    try connection.execute("BEGIN IMMEDIATE TRANSACTION")

    do {
      try connection.execute("DELETE FROM clipboard_records")
      let statement = try connection.prepare(Self.insertSQL)
      defer { sqlite3_finalize(statement) }

      for (position, record) in records.enumerated() {
        try SQLiteClipboardRecordCoder.bind(record, position: position, to: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
          throw SQLiteRepositoryError.operationFailed(connection.errorMessage)
        }
        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)
      }

      try connection.execute("COMMIT")
    } catch {
      try? connection.execute("ROLLBACK")
      throw error
    }
  }

  public func upsert(_ record: ClipboardRecord, position: Int? = nil) throws {
    let connection = try makeConnection()
    let requestedPosition = position
    let resolvedPosition = try max(requestedPosition ?? nextPosition(for: record.id, in: connection), 0)
    if let requestedPosition, requestedPosition >= 0 {
      try shiftPositionsIfNeeded(from: requestedPosition, excluding: record.id, in: connection)
    }

    let statement = try connection.prepare(Self.upsertSQL)
    defer { sqlite3_finalize(statement) }

    try SQLiteClipboardRecordCoder.bind(record, position: resolvedPosition, to: statement)
    guard sqlite3_step(statement) == SQLITE_DONE else {
      throw SQLiteRepositoryError.operationFailed(connection.errorMessage)
    }
  }

  public func delete(id: ClipboardRecord.ID) throws {
    let connection = try makeConnection()
    try connection.run(sql: "DELETE FROM clipboard_records WHERE id = ?", bindings: [id.uuidString])
  }

  public func deleteAll() throws {
    let connection = try makeConnection()
    try connection.execute("DELETE FROM clipboard_records")
  }

  public func markUsed(id: ClipboardRecord.ID, at date: Date, position: Int? = nil) throws {
    let connection = try makeConnection()
    let currentPosition = try nextPosition(for: id, in: connection)
    let resolvedPosition = max(position ?? currentPosition, 0)
    if let position, position >= 0 {
      try shiftPositionsIfNeeded(from: position, excluding: id, in: connection)
    }

    let statement = try connection.prepare("""
      UPDATE clipboard_records
      SET last_copied_at = ?, last_used_at = ?, copy_count = copy_count + 1, position = ?
      WHERE id = ?
      """)
    defer { sqlite3_finalize(statement) }

    let timestamp = date.timeIntervalSince1970
    sqlite3_bind_double(statement, 1, timestamp)
    sqlite3_bind_double(statement, 2, timestamp)
    sqlite3_bind_int64(statement, 3, Int64(resolvedPosition))
    SQLiteClipboardRecordCoder.bindText(id.uuidString, at: 4, to: statement)

    guard sqlite3_step(statement) == SQLITE_DONE else {
      throw SQLiteRepositoryError.operationFailed(connection.errorMessage)
    }
  }

  private func nextPosition(for id: ClipboardRecord.ID, in connection: SQLiteConnection) throws -> Int {
    try connection.int(
      sql: """
        SELECT COALESCE(
          (SELECT position FROM clipboard_records WHERE id = ?),
          (SELECT COALESCE(MAX(position), -1) + 1 FROM clipboard_records)
        )
        """,
      bindings: [id.uuidString]
    )
  }

  private func shiftPositionsIfNeeded(
    from position: Int,
    excluding id: ClipboardRecord.ID,
    in connection: SQLiteConnection
  ) throws {
    try connection.run(
      sql: "UPDATE clipboard_records SET position = position + 1 WHERE position >= ? AND id != ?",
      bindings: ["\(position)", id.uuidString]
    )
  }

  private static let insertSQL = """
    INSERT INTO clipboard_records (
      \(SQLiteClipboardRecordColumns.writableList)
    ) VALUES (\(SQLiteClipboardRecordColumns.writablePlaceholders))
    """

  private static let upsertSQL = """
    INSERT INTO clipboard_records (
      \(SQLiteClipboardRecordColumns.writableList)
    ) VALUES (\(SQLiteClipboardRecordColumns.writablePlaceholders))
    ON CONFLICT(id) DO UPDATE SET
      \(SQLiteClipboardRecordColumns.upsertAssignments)
    """
}
