import Foundation

public enum BackupImportMode: Sendable {
  case replace
  case merge
}

public enum BackupError: Error, Equatable, LocalizedError {
  case invalidBackup
  case unsupportedFormatVersion(Int)
  case missingBlob(String)

  public var errorDescription: String? {
    switch self {
    case .invalidBackup:
      "备份文件无效或已损坏。"
    case let .unsupportedFormatVersion(version):
      "不支持的备份格式版本：\(version)。"
    case let .missingBlob(filename):
      filename.isEmpty ? "备份缺少必要的媒体文件。" : "备份缺少媒体文件：\(filename)。"
    }
  }

  public var recoverySuggestion: String? {
    switch self {
    case .invalidBackup:
      "请选择由 Lite Paste 导出的完整 .litepastebackup 备份文件夹。"
    case .unsupportedFormatVersion:
      "请升级 Lite Paste 后再导入该备份，或选择较旧版本导出的备份。"
    case .missingBlob:
      "请重新导出备份，或确认备份文件夹中的 Blobs 目录未被移动、删除或修改。"
    }
  }
}

struct BackupManifest: Codable {
  var createdAt: Date
  var formatVersion: Int
}

enum BackupLayout {
  static let manifestFilename = "manifest.json"
  static let historyFilename = "history.json"
  static let settingsFilename = "settings.json"
  static let blobsDirectoryName = "Blobs"

  static func manifestURL(in backupURL: URL) -> URL {
    backupURL.appending(path: manifestFilename)
  }

  static func historyURL(in backupURL: URL) -> URL {
    backupURL.appending(path: historyFilename)
  }

  static func settingsURL(in backupURL: URL) -> URL {
    backupURL.appending(path: settingsFilename)
  }

  static func blobsDirectory(in backupURL: URL) -> URL {
    backupURL.appending(path: blobsDirectoryName, directoryHint: .isDirectory)
  }
}
