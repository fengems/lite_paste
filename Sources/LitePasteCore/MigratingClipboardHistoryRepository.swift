import Foundation

public struct MigratingClipboardHistoryRepository: ClipboardHistoryQueryingRepository {
  private let primary: any ClipboardHistoryRepository
  private let legacy: any ClipboardHistoryRepository
  private let legacyURL: URL

  public init(
    primary: any ClipboardHistoryRepository = SQLiteClipboardHistoryRepository(),
    legacy: any ClipboardHistoryRepository = JSONClipboardHistoryRepository(),
    legacyURL: URL = AppPaths.historyURL
  ) {
    self.primary = primary
    self.legacy = legacy
    self.legacyURL = legacyURL
  }

  public init(sqliteURL: URL, legacyJSONURL: URL) {
    self.init(
      primary: SQLiteClipboardHistoryRepository(url: sqliteURL),
      legacy: JSONClipboardHistoryRepository(url: legacyJSONURL),
      legacyURL: legacyJSONURL
    )
  }

  public func load() throws -> [ClipboardRecord] {
    let records = try primary.load()
    guard records.isEmpty,
          FileManager.default.fileExists(atPath: legacyURL.path) else {
      return records
    }

    return try migrateLegacyHistory()
  }

  public func save(_ records: [ClipboardRecord]) throws {
    try primary.save(records)
    try removeLegacyHistoryIfNeeded()
  }

  public func execute(_ query: ClipboardHistoryQuery, limit: Int?, offset: Int) throws -> [ClipboardRecord] {
    try migrateLegacyHistoryIfNeeded()

    if let primary = primary as? any ClipboardHistoryQueryingRepository {
      return try primary.execute(query, limit: limit, offset: offset)
    }

    let queriedRecords = ClipboardHistoryQueryEngine().execute(query, records: try load())
    return Self.slice(queriedRecords, limit: limit, offset: offset)
  }

  public func count(_ query: ClipboardHistoryQuery) throws -> Int {
    try migrateLegacyHistoryIfNeeded()

    if let primary = primary as? any ClipboardHistoryQueryingRepository {
      return try primary.count(query)
    }

    return ClipboardHistoryQueryEngine().execute(query, records: try load()).count
  }

  private func migrateLegacyHistoryIfNeeded() throws {
    guard FileManager.default.fileExists(atPath: legacyURL.path),
          try primaryIsEmpty() else {
      return
    }

    _ = try migrateLegacyHistory()
  }

  private func migrateLegacyHistory() throws -> [ClipboardRecord] {
    let legacyRecords = try legacy.load()
    try primary.save(legacyRecords)
    try removeLegacyHistoryIfNeeded()
    return legacyRecords
  }

  private func primaryIsEmpty() throws -> Bool {
    if let primary = primary as? any ClipboardHistoryQueryingRepository {
      return try primary.count(ClipboardHistoryQuery()) == 0
    }

    return try primary.load().isEmpty
  }

  private func removeLegacyHistoryIfNeeded() throws {
    guard FileManager.default.fileExists(atPath: legacyURL.path) else {
      return
    }

    try FileManager.default.removeItem(at: legacyURL)
  }

  private static func slice(_ records: [ClipboardRecord], limit: Int?, offset: Int) -> [ClipboardRecord] {
    let offset = min(max(offset, 0), records.count)
    let records = records.dropFirst(offset)
    guard let limit else {
      return Array(records)
    }

    return Array(records.prefix(max(limit, 0)))
  }
}
