import Foundation

extension ICloudBackupService {
  func latestBackupURL() throws -> URL {
    let backups = try backupURLs(in: resolvedBackupsDirectoryURL())
    guard let latestBackup = backups.first else {
      throw ICloudBackupError.noBackups
    }

    return latestBackup
  }

  func resolvedBackupsDirectoryURL() throws -> URL {
    if let containerURL = containerURLProvider() {
      return containerURL
        .appending(path: "Documents", directoryHint: .isDirectory)
        .appending(path: "Lite Paste", directoryHint: .isDirectory)
        .appending(path: "Backups", directoryHint: .isDirectory)
    }

    if let iCloudDriveURL = iCloudDriveURLProvider() {
      return iCloudDriveURL
        .appending(path: "Lite Paste", directoryHint: .isDirectory)
        .appending(path: "Backups", directoryHint: .isDirectory)
    }

    throw ICloudBackupError.unavailable
  }

  func backupURLs(in directory: URL) throws -> [URL] {
    guard FileManager.default.fileExists(atPath: directory.path) else {
      return []
    }

    return try FileManager.default
      .contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
        options: [.skipsHiddenFiles]
      )
      .filter { url in
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
          return false
        }

        return url.pathExtension == "litepastebackup"
      }
      .sorted(by: compareBackupURLs)
  }

  func pruneOldBackups(in directory: URL, keeping keptURL: URL) throws {
    let keptPath = keptURL.standardizedFileURL.path
    for backupURL in try backupURLs(in: directory) where backupURL.standardizedFileURL.path != keptPath {
      try FileManager.default.removeItem(at: backupURL)
    }
  }

  private func compareBackupURLs(_ lhs: URL, _ rhs: URL) -> Bool {
    if lhs.lastPathComponent != rhs.lastPathComponent,
       lhs.lastPathComponent.hasPrefix("LitePaste-"),
       rhs.lastPathComponent.hasPrefix("LitePaste-") {
      return lhs.lastPathComponent > rhs.lastPathComponent
    }

    return contentModificationDate(for: lhs) > contentModificationDate(for: rhs)
  }

  private func contentModificationDate(for url: URL) -> Date {
    (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
  }

  public static func defaultICloudDriveURL() -> URL? {
    let url = FileManager.default.homeDirectoryForCurrentUser
      .appending(path: "Library", directoryHint: .isDirectory)
      .appending(path: "Mobile Documents", directoryHint: .isDirectory)
      .appending(path: "com~apple~CloudDocs", directoryHint: .isDirectory)

    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
      return nil
    }

    return url
  }
}
