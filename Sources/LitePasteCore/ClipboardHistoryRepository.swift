import Foundation

public protocol ClipboardHistoryRepository: Sendable {
  func load() throws -> [ClipboardRecord]
  func save(_ records: [ClipboardRecord]) throws
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
    try AppPaths.ensureApplicationSupportDirectoryExists()
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

