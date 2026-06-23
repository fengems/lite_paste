import Foundation

public struct ICloudBackupSummary: Equatable, Sendable {
  public var backupsDirectory: URL
  public var backupCount: Int
  public var latestBackupURL: URL?

  public init(backupsDirectory: URL, backupCount: Int, latestBackupURL: URL?) {
    self.backupsDirectory = backupsDirectory
    self.backupCount = backupCount
    self.latestBackupURL = latestBackupURL
  }
}

public enum ICloudBackupError: Error, Equatable, LocalizedError {
  case unavailable
  case noBackups

  public var errorDescription: String? {
    switch self {
    case .unavailable:
      "iCloud 不可用。"
    case .noBackups:
      "iCloud 中没有 Lite Paste 备份。"
    }
  }

  public var recoverySuggestion: String? {
    switch self {
    case .unavailable:
      "请确认当前 Mac 已登录 iCloud、已开启 iCloud Drive，并且 Lite Paste 可以访问 iCloud Drive。"
    case .noBackups:
      "请先执行一次“备份到 iCloud”，或手动导入本地备份。"
    }
  }
}
