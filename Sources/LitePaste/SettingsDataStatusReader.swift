import Foundation
import LitePasteCore

enum SettingsDataStatusReader {
  static func historyCount() throws -> Int {
    try SQLiteClipboardHistoryRepository().count(ClipboardHistoryQuery())
  }

  static func storageSizeText() throws -> String {
    formattedByteCount(try totalSizeOfDataDirectory())
  }

  private static func totalSizeOfDataDirectory() throws -> UInt64 {
    let directory = AppPaths.applicationSupportDirectory
    guard FileManager.default.fileExists(atPath: directory.path) else {
      return 0
    }

    let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]
    guard let enumerator = FileManager.default.enumerator(
      at: directory,
      includingPropertiesForKeys: Array(resourceKeys),
      options: [.skipsHiddenFiles]
    ) else {
      return 0
    }

    return try enumerator.reduce(UInt64(0)) { total, item in
      guard let url = item as? URL else {
        return total
      }

      let values = try url.resourceValues(forKeys: resourceKeys)
      guard values.isRegularFile == true else {
        return total
      }

      return total + UInt64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }
  }

  private static func formattedByteCount(_ byteCount: UInt64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(byteCount))
  }
}
