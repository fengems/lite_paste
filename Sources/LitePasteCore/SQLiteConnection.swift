import Foundation
import SQLite3

final class SQLiteConnection {
  private static let busyTimeoutMilliseconds: Int32 = 5_000

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

    sqlite3_busy_timeout(database, Self.busyTimeoutMilliseconds)
  }

  deinit {
    sqlite3_close(database)
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

    bind(bindings, to: statement)

    var records: [ClipboardRecord] = []
    var stepResult = sqlite3_step(statement)
    while stepResult == SQLITE_ROW {
      records.append(try SQLiteClipboardRecordCoder.record(from: statement))
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

    bind(bindings, to: statement)

    let stepResult = sqlite3_step(statement)
    guard stepResult == SQLITE_ROW else {
      throw SQLiteRepositoryError.operationFailed(errorMessage)
    }

    return Int(sqlite3_column_int64(statement, 0))
  }

  func run(sql: String, bindings: [String] = []) throws {
    let statement = try prepare(sql)
    defer { sqlite3_finalize(statement) }

    bind(bindings, to: statement)

    guard sqlite3_step(statement) == SQLITE_DONE else {
      throw SQLiteRepositoryError.operationFailed(errorMessage)
    }
  }

  private func bind(_ bindings: [String], to statement: OpaquePointer?) {
    for (index, binding) in bindings.enumerated() {
      SQLiteClipboardRecordCoder.bindText(binding, at: Int32(index + 1), to: statement)
    }
  }
}
