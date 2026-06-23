import Foundation

extension SQLiteClipboardHistoryRepository {
  public func performMaintenance() throws {
    let connection = try makeConnection()
    try connection.execute("ANALYZE")
    try connection.execute("PRAGMA optimize")
    try connection.execute("VACUUM")
  }
}
