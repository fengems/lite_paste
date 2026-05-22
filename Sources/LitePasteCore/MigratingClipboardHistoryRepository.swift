import Foundation

public struct MigratingClipboardHistoryRepository: ClipboardHistoryRepository {
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

    let legacyRecords = try legacy.load()
    try primary.save(legacyRecords)
    try removeLegacyHistoryIfNeeded()

    return legacyRecords
  }

  public func save(_ records: [ClipboardRecord]) throws {
    try primary.save(records)
    try removeLegacyHistoryIfNeeded()
  }

  private func removeLegacyHistoryIfNeeded() throws {
    guard FileManager.default.fileExists(atPath: legacyURL.path) else {
      return
    }

    try FileManager.default.removeItem(at: legacyURL)
  }
}
