import Foundation
import SQLite3

public struct SQLiteClipboardHistoryRepository: ClipboardHistoryIncrementalRepository, ClipboardHistoryLookupRepository, ClipboardHistoryQueryingRepository {
  private let url: URL
  private static let selectColumns = """
    id, kind, title, search_text, note, source_app_bundle_id, source_app_name,
    created_at, last_copied_at, last_used_at, copy_count, is_favorite, is_pinned,
    pin_shortcut, content_hash, plain_text, contents_json, preview_file_path
    """

  public init(url: URL = AppPaths.applicationSupportDirectory.appending(path: "history.sqlite3")) {
    self.url = url
  }

  public func load() throws -> [ClipboardRecord] {
    let connection = try SQLiteConnection(url: url)
    try connection.ensureSchema()

    return try connection.records(
      sql: "SELECT \(Self.selectColumns) FROM clipboard_records ORDER BY position ASC"
    )
  }

  public func save(_ records: [ClipboardRecord]) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )

    let connection = try SQLiteConnection(url: url)
    try connection.ensureSchema()
    try connection.execute("BEGIN IMMEDIATE TRANSACTION")

    do {
      try connection.execute("DELETE FROM clipboard_records")
      let statement = try connection.prepare("""
        INSERT INTO clipboard_records (
          id, kind, title, search_text, note, source_app_bundle_id, source_app_name,
          created_at, last_copied_at, last_used_at, copy_count, is_favorite, is_pinned,
          pin_shortcut, content_hash, plain_text, contents_json, preview_file_path, position
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """)
      defer { sqlite3_finalize(statement) }

      for (position, record) in records.enumerated() {
        try Self.bind(record, position: position, to: statement)
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

  public func execute(
    _ query: ClipboardHistoryQuery,
    limit: Int? = nil,
    offset: Int = 0
  ) throws -> [ClipboardRecord] {
    let connection = try SQLiteConnection(url: url)
    try connection.ensureSchema()

    let request = Self.sqlRequest(for: query, limit: limit, offset: offset)
    return try connection.records(sql: request.sql, bindings: request.bindings)
  }

  public func count(_ query: ClipboardHistoryQuery) throws -> Int {
    let connection = try SQLiteConnection(url: url)
    try connection.ensureSchema()

    let request = Self.countRequest(for: query)
    return try connection.int(sql: request.sql, bindings: request.bindings)
  }

  public func record(id: ClipboardRecord.ID) throws -> ClipboardRecord? {
    let connection = try SQLiteConnection(url: url)
    try connection.ensureSchema()

    return try connection.records(
      sql: "SELECT \(Self.selectColumns) FROM clipboard_records WHERE id = ? LIMIT 1",
      bindings: [id.uuidString]
    ).first
  }

  public func record(contentHash: String) throws -> ClipboardRecord? {
    let connection = try SQLiteConnection(url: url)
    try connection.ensureSchema()

    return try connection.records(
      sql: "SELECT \(Self.selectColumns) FROM clipboard_records WHERE content_hash = ? LIMIT 1",
      bindings: [contentHash]
    ).first
  }

  public func upsert(_ record: ClipboardRecord, position: Int? = nil) throws {
    let connection = try SQLiteConnection(url: url)
    try connection.ensureSchema()
    let requestedPosition = position
    let resolvedPosition = try max(requestedPosition ?? nextPosition(for: record.id, in: connection), 0)
    if let requestedPosition, requestedPosition >= 0 {
      try shiftPositionsIfNeeded(from: requestedPosition, excluding: record.id, in: connection)
    }
    let statement = try connection.prepare("""
      INSERT INTO clipboard_records (
        id, kind, title, search_text, note, source_app_bundle_id, source_app_name,
        created_at, last_copied_at, last_used_at, copy_count, is_favorite, is_pinned,
        pin_shortcut, content_hash, plain_text, contents_json, preview_file_path, position
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        kind = excluded.kind,
        title = excluded.title,
        search_text = excluded.search_text,
        note = excluded.note,
        source_app_bundle_id = excluded.source_app_bundle_id,
        source_app_name = excluded.source_app_name,
        created_at = excluded.created_at,
        last_copied_at = excluded.last_copied_at,
        last_used_at = excluded.last_used_at,
        copy_count = excluded.copy_count,
        is_favorite = excluded.is_favorite,
        is_pinned = excluded.is_pinned,
        pin_shortcut = excluded.pin_shortcut,
        content_hash = excluded.content_hash,
        plain_text = excluded.plain_text,
        contents_json = excluded.contents_json,
        preview_file_path = excluded.preview_file_path,
        position = excluded.position
      """)
    defer { sqlite3_finalize(statement) }

    try Self.bind(record, position: resolvedPosition, to: statement)
    guard sqlite3_step(statement) == SQLITE_DONE else {
      throw SQLiteRepositoryError.operationFailed(connection.errorMessage)
    }
  }

  public func delete(id: ClipboardRecord.ID) throws {
    let connection = try SQLiteConnection(url: url)
    try connection.ensureSchema()
    try connection.run(sql: "DELETE FROM clipboard_records WHERE id = ?", bindings: [id.uuidString])
  }

  public func deleteAll() throws {
    let connection = try SQLiteConnection(url: url)
    try connection.ensureSchema()
    try connection.execute("DELETE FROM clipboard_records")
  }

  public func performMaintenance() throws {
    let connection = try SQLiteConnection(url: url)
    try connection.ensureSchema()
    try connection.execute("ANALYZE")
    try connection.execute("PRAGMA optimize")
    try connection.execute("VACUUM")
  }

  private static func sqlRequest(
    for query: ClipboardHistoryQuery,
    limit: Int?,
    offset: Int
  ) -> SQLiteQueryRequest {
    let predicate = predicateRequest(for: query)
    var sql = "SELECT \(selectColumns) FROM clipboard_records"
    sql += predicate.sql
    sql += " ORDER BY \(orderClause(for: query.sort))"

    if let limit {
      sql += " LIMIT \(max(limit, 0))"
    } else if offset > 0 {
      sql += " LIMIT -1"
    }

    if offset > 0 {
      sql += " OFFSET \(offset)"
    }

    return SQLiteQueryRequest(sql: sql, bindings: predicate.bindings)
  }

  private static func countRequest(for query: ClipboardHistoryQuery) -> SQLiteQueryRequest {
    let predicate = predicateRequest(for: query)
    return SQLiteQueryRequest(sql: "SELECT COUNT(*) FROM clipboard_records\(predicate.sql)", bindings: predicate.bindings)
  }

  private static func predicateRequest(for query: ClipboardHistoryQuery) -> SQLiteQueryRequest {
    var clauses: [String] = []
    var bindings: [String] = []

    if let filterRequest = sqlClause(for: query.filter) {
      clauses.append(filterRequest.sql)
      bindings.append(contentsOf: filterRequest.bindings)
    }

    for term in searchTerms(for: query.text) {
      var termClauses = [
        "title LIKE ? ESCAPE '\\' COLLATE NOCASE",
        "search_text LIKE ? ESCAPE '\\' COLLATE NOCASE",
        "note LIKE ? ESCAPE '\\' COLLATE NOCASE",
        "source_app_name LIKE ? ESCAPE '\\' COLLATE NOCASE",
        "source_app_bundle_id LIKE ? ESCAPE '\\' COLLATE NOCASE",
        "kind LIKE ? ESCAPE '\\' COLLATE NOCASE"
      ]
      let pattern = "%\(escapedLikePattern(term))%"
      bindings.append(contentsOf: Array(repeating: pattern, count: termClauses.count))

      let displayNameKinds = ClipboardKind.allCases
        .filter { contains(term, in: $0.displayName) }
        .map(\.rawValue)
      if !displayNameKinds.isEmpty {
        termClauses.append("kind IN (\(placeholders(count: displayNameKinds.count)))")
        bindings.append(contentsOf: displayNameKinds)
      }

      clauses.append("(\(termClauses.joined(separator: " OR ")))")
    }

    var sql = ""
    if !clauses.isEmpty {
      sql = " WHERE \(clauses.joined(separator: " AND "))"
    }

    return SQLiteQueryRequest(sql: sql, bindings: bindings)
  }

  private static func sqlClause(for filter: ClipboardFilter) -> SQLiteQueryRequest? {
    switch filter {
    case .all:
      nil
    case .text:
      SQLiteQueryRequest(
        sql: "kind IN (\(placeholders(count: textKinds.count)))",
        bindings: textKinds
      )
    case .images:
      SQLiteQueryRequest(sql: "kind = 'image'", bindings: [])
    case .files:
      SQLiteQueryRequest(sql: "kind = 'files'", bindings: [])
    case .favorites:
      SQLiteQueryRequest(sql: "is_favorite = 1", bindings: [])
    case .pinned:
      SQLiteQueryRequest(sql: "is_pinned = 1", bindings: [])
    }
  }

  private static func orderClause(for sort: ClipboardHistorySort) -> String {
    switch sort {
    case .pinnedThenRecent:
      "is_pinned DESC, last_copied_at DESC"
    case .recent:
      "last_copied_at DESC"
    case .mostUsed:
      "copy_count DESC, last_copied_at DESC"
    }
  }

  private static func searchTerms(for text: String) -> [String] {
    text
      .split(whereSeparator: \.isWhitespace)
      .map(String.init)
  }

  private static func escapedLikePattern(_ text: String) -> String {
    text
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "%", with: "\\%")
      .replacingOccurrences(of: "_", with: "\\_")
  }

  private static func contains(_ term: String, in value: String) -> Bool {
    value.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
  }

  private static func placeholders(count: Int) -> String {
    Array(repeating: "?", count: count).joined(separator: ", ")
  }

  private static let textKinds = [
    ClipboardKind.text.rawValue,
    ClipboardKind.richText.rawValue,
    ClipboardKind.html.rawValue,
    ClipboardKind.url.rawValue,
    ClipboardKind.email.rawValue,
    ClipboardKind.color.rawValue
  ]

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
    try connection.execute(
      "UPDATE clipboard_records SET position = position + 1 WHERE position >= \(position) AND id != '\(id.uuidString)'"
    )
  }

  fileprivate static func record(from statement: OpaquePointer?) throws -> ClipboardRecord {
    guard let id = UUID(uuidString: text(at: 0, in: statement) ?? ""),
          let kind = ClipboardKind(rawValue: text(at: 1, in: statement) ?? "") else {
      throw SQLiteRepositoryError.invalidRecord
    }

    let contentsData = data(at: 16, in: statement) ?? Data("[]".utf8)
    let contents = try JSONDecoder.litePaste.decode([ClipboardContentSnapshot].self, from: contentsData)

    return ClipboardRecord(
      id: id,
      kind: kind,
      title: text(at: 2, in: statement) ?? "",
      searchText: text(at: 3, in: statement) ?? "",
      note: text(at: 4, in: statement) ?? "",
      sourceAppBundleId: text(at: 5, in: statement),
      sourceAppName: text(at: 6, in: statement),
      createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 7)),
      lastCopiedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 8)),
      lastUsedAt: optionalDate(at: 9, in: statement),
      copyCount: Int(sqlite3_column_int64(statement, 10)),
      isFavorite: sqlite3_column_int(statement, 11) != 0,
      isPinned: sqlite3_column_int(statement, 12) != 0,
      pinShortcut: text(at: 13, in: statement),
      contentHash: text(at: 14, in: statement) ?? "",
      plainText: text(at: 15, in: statement),
      contents: contents,
      previewFilePath: text(at: 17, in: statement)
    )
  }

  private static func bind(_ record: ClipboardRecord, position: Int, to statement: OpaquePointer?) throws {
    let contentsData = try JSONEncoder.litePaste.encode(record.contents)

    bindText(record.id.uuidString, at: 1, to: statement)
    bindText(record.kind.rawValue, at: 2, to: statement)
    bindText(record.title, at: 3, to: statement)
    bindText(record.searchText, at: 4, to: statement)
    bindText(record.note, at: 5, to: statement)
    bindText(record.sourceAppBundleId, at: 6, to: statement)
    bindText(record.sourceAppName, at: 7, to: statement)
    sqlite3_bind_double(statement, 8, record.createdAt.timeIntervalSince1970)
    sqlite3_bind_double(statement, 9, record.lastCopiedAt.timeIntervalSince1970)
    bindDate(record.lastUsedAt, at: 10, to: statement)
    sqlite3_bind_int64(statement, 11, Int64(record.copyCount))
    sqlite3_bind_int(statement, 12, record.isFavorite ? 1 : 0)
    sqlite3_bind_int(statement, 13, record.isPinned ? 1 : 0)
    bindText(record.pinShortcut, at: 14, to: statement)
    bindText(record.contentHash, at: 15, to: statement)
    bindText(record.plainText, at: 16, to: statement)
    let bindContentsResult = contentsData.withUnsafeBytes { buffer in
      sqlite3_bind_blob(statement, 17, buffer.baseAddress, Int32(buffer.count), sqliteTransient)
    }
    guard bindContentsResult == SQLITE_OK else {
      throw SQLiteRepositoryError.operationFailed("Unable to bind clipboard contents")
    }
    bindText(record.previewFilePath, at: 18, to: statement)
    sqlite3_bind_int64(statement, 19, Int64(position))
  }

  private static func optionalDate(at index: Int32, in statement: OpaquePointer?) -> Date? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
      return nil
    }

    return Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
  }

  private static func text(at index: Int32, in statement: OpaquePointer?) -> String? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL,
          let pointer = sqlite3_column_text(statement, index) else {
      return nil
    }

    return String(cString: pointer)
  }

  private static func data(at index: Int32, in statement: OpaquePointer?) -> Data? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
      return nil
    }

    let byteCount = Int(sqlite3_column_bytes(statement, index))
    guard byteCount > 0,
          let bytes = sqlite3_column_blob(statement, index) else {
      return Data()
    }

    return Data(bytes: bytes, count: byteCount)
  }

  fileprivate static func bindText(_ value: String?, at index: Int32, to statement: OpaquePointer?) {
    guard let value else {
      sqlite3_bind_null(statement, index)
      return
    }

    sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
  }

  private static func bindDate(_ value: Date?, at index: Int32, to statement: OpaquePointer?) {
    guard let value else {
      sqlite3_bind_null(statement, index)
      return
    }

    sqlite3_bind_double(statement, index, value.timeIntervalSince1970)
  }
}

private final class SQLiteConnection {
  private var database: OpaquePointer?

  var errorMessage: String {
    guard let database,
          let message = sqlite3_errmsg(database) else {
      return "Unknown SQLite error"
    }

    return String(cString: message)
  }

  init(url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )

    let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
    guard sqlite3_open_v2(url.path, &database, flags, nil) == SQLITE_OK else {
      let message = errorMessage
      sqlite3_close(database)
      throw SQLiteRepositoryError.openFailed(message)
    }

    sqlite3_busy_timeout(database, 5_000)
  }

  deinit {
    sqlite3_close(database)
  }

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
        contents_json BLOB NOT NULL,
        preview_file_path TEXT,
        position INTEGER NOT NULL
      )
      """)
    try execute("CREATE INDEX IF NOT EXISTS idx_clipboard_records_content_hash ON clipboard_records(content_hash)")
    try execute("CREATE INDEX IF NOT EXISTS idx_clipboard_records_last_copied_at ON clipboard_records(last_copied_at DESC)")
    try execute("CREATE INDEX IF NOT EXISTS idx_clipboard_records_kind ON clipboard_records(kind)")
    try execute("CREATE INDEX IF NOT EXISTS idx_clipboard_records_favorite ON clipboard_records(is_favorite, last_copied_at DESC)")
    try execute("CREATE INDEX IF NOT EXISTS idx_clipboard_records_pinned ON clipboard_records(is_pinned, last_copied_at DESC)")
    try execute("CREATE INDEX IF NOT EXISTS idx_clipboard_records_copy_count ON clipboard_records(copy_count DESC, last_copied_at DESC)")
  }

  func execute(_ sql: String) throws {
    guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
      throw SQLiteRepositoryError.operationFailed(errorMessage)
    }
  }

  func prepare(_ sql: String) throws -> OpaquePointer? {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      throw SQLiteRepositoryError.operationFailed(errorMessage)
    }

    return statement
  }

  func records(sql: String, bindings: [String] = []) throws -> [ClipboardRecord] {
    let statement = try prepare(sql)
    defer { sqlite3_finalize(statement) }

    for (index, binding) in bindings.enumerated() {
      SQLiteClipboardHistoryRepository.bindText(binding, at: Int32(index + 1), to: statement)
    }

    var records: [ClipboardRecord] = []
    var stepResult = sqlite3_step(statement)
    while stepResult == SQLITE_ROW {
      records.append(try SQLiteClipboardHistoryRepository.record(from: statement))
      stepResult = sqlite3_step(statement)
    }

    guard stepResult == SQLITE_DONE else {
      throw SQLiteRepositoryError.operationFailed(errorMessage)
    }

    return records
  }

  func int(sql: String, bindings: [String] = []) throws -> Int {
    let statement = try prepare(sql)
    defer { sqlite3_finalize(statement) }

    for (index, binding) in bindings.enumerated() {
      SQLiteClipboardHistoryRepository.bindText(binding, at: Int32(index + 1), to: statement)
    }

    let stepResult = sqlite3_step(statement)
    guard stepResult == SQLITE_ROW else {
      throw SQLiteRepositoryError.operationFailed(errorMessage)
    }

    return Int(sqlite3_column_int64(statement, 0))
  }

  func run(sql: String, bindings: [String] = []) throws {
    let statement = try prepare(sql)
    defer { sqlite3_finalize(statement) }

    for (index, binding) in bindings.enumerated() {
      SQLiteClipboardHistoryRepository.bindText(binding, at: Int32(index + 1), to: statement)
    }

    guard sqlite3_step(statement) == SQLITE_DONE else {
      throw SQLiteRepositoryError.operationFailed(errorMessage)
    }
  }
}

private struct SQLiteQueryRequest {
  var sql: String
  var bindings: [String]
}

public enum SQLiteRepositoryError: Error, Equatable, Sendable {
  case openFailed(String)
  case operationFailed(String)
  case invalidRecord
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
