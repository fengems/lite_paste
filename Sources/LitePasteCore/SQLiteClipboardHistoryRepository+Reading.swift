import Foundation

extension SQLiteClipboardHistoryRepository {
  public func load() throws -> [ClipboardRecord] {
    let connection = try makeConnection()
    return try connection.records(
      sql: "SELECT \(SQLiteClipboardHistoryQueryBuilder.selectColumns) FROM clipboard_records ORDER BY position ASC"
    )
  }

  public func execute(
    _ query: ClipboardHistoryQuery,
    limit: Int? = nil,
    offset: Int = 0
  ) throws -> [ClipboardRecord] {
    let connection = try makeConnection()
    let request = SQLiteClipboardHistoryQueryBuilder.recordsRequest(for: query, limit: limit, offset: offset)
    return try connection.records(sql: request.sql, bindings: request.bindings)
  }

  public func count(_ query: ClipboardHistoryQuery) throws -> Int {
    let connection = try makeConnection()
    let request = SQLiteClipboardHistoryQueryBuilder.countRequest(for: query)
    return try connection.int(sql: request.sql, bindings: request.bindings)
  }

  public func record(id: ClipboardRecord.ID) throws -> ClipboardRecord? {
    let connection = try makeConnection()
    return try connection.records(
      sql: "SELECT \(SQLiteClipboardHistoryQueryBuilder.selectColumns) FROM clipboard_records WHERE id = ? LIMIT 1",
      bindings: [id.uuidString]
    ).first
  }

  public func record(contentHash: String) throws -> ClipboardRecord? {
    let connection = try makeConnection()
    return try connection.records(
      sql: "SELECT \(SQLiteClipboardHistoryQueryBuilder.selectColumns) FROM clipboard_records WHERE content_hash = ? LIMIT 1",
      bindings: [contentHash]
    ).first
  }
}
