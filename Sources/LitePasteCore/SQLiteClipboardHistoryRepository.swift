import Foundation

public struct SQLiteClipboardHistoryRepository: ClipboardHistoryIncrementalRepository, ClipboardHistoryLookupRepository, ClipboardHistoryQueryingRepository, ClipboardHistoryUsageRepository {
  let url: URL

  public init(url: URL = AppPaths.applicationSupportDirectory.appending(path: "history.sqlite3")) {
    self.url = url
  }

  func makeConnection() throws -> SQLiteConnection {
    let connection = try SQLiteConnection(url: url)
    try connection.ensureSchema()
    return connection
  }
}
