import Foundation

public protocol ClipboardHistoryRepository: Sendable {
  func load() throws -> [ClipboardRecord]
  func save(_ records: [ClipboardRecord]) throws
}

public protocol ClipboardHistoryQueryingRepository: ClipboardHistoryRepository {
  func execute(_ query: ClipboardHistoryQuery, limit: Int?, offset: Int) throws -> [ClipboardRecord]
  func count(_ query: ClipboardHistoryQuery) throws -> Int
}

public protocol ClipboardHistoryLookupRepository: ClipboardHistoryRepository {
  func record(id: ClipboardRecord.ID) throws -> ClipboardRecord?
  func record(contentHash: String) throws -> ClipboardRecord?
}

public protocol ClipboardHistoryIncrementalRepository: ClipboardHistoryRepository {
  func upsert(_ record: ClipboardRecord, position: Int?) throws
  func delete(id: ClipboardRecord.ID) throws
  func deleteAll() throws
}

public protocol ClipboardHistoryUsageRepository: ClipboardHistoryRepository {
  func markUsed(id: ClipboardRecord.ID, at date: Date, position: Int?) throws
}

public struct JSONClipboardHistoryRepository: ClipboardHistoryRepository {
  private let url: URL

  public init(url: URL = AppPaths.historyURL) {
    self.url = url
  }

  public func load() throws -> [ClipboardRecord] {
    guard FileManager.default.fileExists(atPath: url.path) else {
      return []
    }

    let data = try Data(contentsOf: url)
    return try JSONDecoder.litePaste.decode([ClipboardRecord].self, from: data)
  }

  public func save(_ records: [ClipboardRecord]) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let data = try JSONEncoder.litePaste.encode(records)
    try data.write(to: url, options: .atomic)
  }
}

public struct InMemoryClipboardHistoryRepository: ClipboardHistoryRepository {
  public init() {}

  public func load() throws -> [ClipboardRecord] {
    []
  }

  public func save(_ records: [ClipboardRecord]) throws {}
}
