import Foundation
import SQLite3

enum SQLiteClipboardRecordCoder {
  static func record(from statement: OpaquePointer?) throws -> ClipboardRecord {
    guard let id = UUID(uuidString: text(at: .id, in: statement) ?? ""),
          let kind = ClipboardKind(rawValue: text(at: .kind, in: statement) ?? "") else {
      throw SQLiteRepositoryError.invalidRecord
    }

    let contentsData = data(at: .contentsJSON, in: statement) ?? Data("[]".utf8)
    let contents = try JSONDecoder.litePaste.decode([ClipboardContentSnapshot].self, from: contentsData)

    return ClipboardRecord(
      id: id,
      kind: kind,
      title: text(at: .title, in: statement) ?? "",
      searchText: text(at: .searchText, in: statement) ?? "",
      note: text(at: .note, in: statement) ?? "",
      sourceAppBundleId: text(at: .sourceAppBundleId, in: statement),
      sourceAppName: text(at: .sourceAppName, in: statement),
      createdAt: Date(timeIntervalSince1970: double(at: .createdAt, in: statement)),
      lastCopiedAt: Date(timeIntervalSince1970: double(at: .lastCopiedAt, in: statement)),
      lastUsedAt: optionalDate(at: .lastUsedAt, in: statement),
      copyCount: Int(int64(at: .copyCount, in: statement)),
      isFavorite: bool(at: .isFavorite, in: statement),
      isPinned: bool(at: .isPinned, in: statement),
      pinShortcut: text(at: .pinShortcut, in: statement),
      contentHash: text(at: .contentHash, in: statement) ?? "",
      plainText: text(at: .plainText, in: statement),
      ocrText: text(at: .ocrText, in: statement),
      contents: contents,
      previewFilePath: text(at: .previewFilePath, in: statement)
    )
  }

  static func bind(_ record: ClipboardRecord, position: Int, to statement: OpaquePointer?) throws {
    let contentsData = try JSONEncoder.litePaste.encode(record.contents)

    bindText(record.id.uuidString, at: .id, to: statement)
    bindText(record.kind.rawValue, at: .kind, to: statement)
    bindText(record.title, at: .title, to: statement)
    bindText(record.searchText, at: .searchText, to: statement)
    bindText(record.note, at: .note, to: statement)
    bindText(record.sourceAppBundleId, at: .sourceAppBundleId, to: statement)
    bindText(record.sourceAppName, at: .sourceAppName, to: statement)
    sqlite3_bind_double(
      statement,
      SQLiteClipboardRecordColumn.createdAt.bindingIndex,
      record.createdAt.timeIntervalSince1970
    )
    sqlite3_bind_double(
      statement,
      SQLiteClipboardRecordColumn.lastCopiedAt.bindingIndex,
      record.lastCopiedAt.timeIntervalSince1970
    )
    bindDate(record.lastUsedAt, at: .lastUsedAt, to: statement)
    sqlite3_bind_int64(
      statement,
      SQLiteClipboardRecordColumn.copyCount.bindingIndex,
      Int64(record.copyCount)
    )
    sqlite3_bind_int(
      statement,
      SQLiteClipboardRecordColumn.isFavorite.bindingIndex,
      record.isFavorite ? 1 : 0
    )
    sqlite3_bind_int(
      statement,
      SQLiteClipboardRecordColumn.isPinned.bindingIndex,
      record.isPinned ? 1 : 0
    )
    bindText(record.pinShortcut, at: .pinShortcut, to: statement)
    bindText(record.contentHash, at: .contentHash, to: statement)
    bindText(record.plainText, at: .plainText, to: statement)
    bindText(record.ocrText, at: .ocrText, to: statement)
    let bindContentsResult = contentsData.withUnsafeBytes { buffer in
      sqlite3_bind_blob(
        statement,
        SQLiteClipboardRecordColumn.contentsJSON.bindingIndex,
        buffer.baseAddress,
        Int32(buffer.count),
        sqliteTransient
      )
    }
    guard bindContentsResult == SQLITE_OK else {
      throw SQLiteRepositoryError.operationFailed("Unable to bind clipboard contents")
    }
    bindText(record.previewFilePath, at: .previewFilePath, to: statement)
    sqlite3_bind_int64(statement, SQLiteClipboardRecordColumn.position.bindingIndex, Int64(position))
  }

  static func text(at index: Int32, in statement: OpaquePointer?) -> String? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL,
          let pointer = sqlite3_column_text(statement, index) else {
      return nil
    }

    return String(cString: pointer)
  }

  static func bindText(_ value: String?, at index: Int32, to statement: OpaquePointer?) {
    guard let value else {
      sqlite3_bind_null(statement, index)
      return
    }

    sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
  }

  private static func text(at column: SQLiteClipboardRecordColumn, in statement: OpaquePointer?) -> String? {
    text(at: column.selectedIndex, in: statement)
  }

  private static func bindText(_ value: String?, at column: SQLiteClipboardRecordColumn, to statement: OpaquePointer?) {
    bindText(value, at: column.bindingIndex, to: statement)
  }

  private static func optionalDate(at column: SQLiteClipboardRecordColumn, in statement: OpaquePointer?) -> Date? {
    guard sqlite3_column_type(statement, column.selectedIndex) != SQLITE_NULL else {
      return nil
    }

    return Date(timeIntervalSince1970: double(at: column, in: statement))
  }

  private static func data(at column: SQLiteClipboardRecordColumn, in statement: OpaquePointer?) -> Data? {
    guard sqlite3_column_type(statement, column.selectedIndex) != SQLITE_NULL else {
      return nil
    }

    let byteCount = Int(sqlite3_column_bytes(statement, column.selectedIndex))
    guard byteCount > 0,
          let bytes = sqlite3_column_blob(statement, column.selectedIndex) else {
      return Data()
    }

    return Data(bytes: bytes, count: byteCount)
  }

  private static func double(at column: SQLiteClipboardRecordColumn, in statement: OpaquePointer?) -> Double {
    sqlite3_column_double(statement, column.selectedIndex)
  }

  private static func int64(at column: SQLiteClipboardRecordColumn, in statement: OpaquePointer?) -> Int64 {
    sqlite3_column_int64(statement, column.selectedIndex)
  }

  private static func bool(at column: SQLiteClipboardRecordColumn, in statement: OpaquePointer?) -> Bool {
    sqlite3_column_int(statement, column.selectedIndex) != 0
  }

  private static func bindDate(_ value: Date?, at column: SQLiteClipboardRecordColumn, to statement: OpaquePointer?) {
    guard let value else {
      sqlite3_bind_null(statement, column.bindingIndex)
      return
    }

    sqlite3_bind_double(statement, column.bindingIndex, value.timeIntervalSince1970)
  }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
