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

public struct ICloudBackupService: Sendable {
  private let importExportService: ImportExportService
  private let containerURLProvider: @Sendable () -> URL?
  private let iCloudDriveURLProvider: @Sendable () -> URL?

  public init(
    paths: AppStoragePaths = AppStoragePaths(),
    containerURLProvider: @escaping @Sendable () -> URL? = {
      FileManager.default.url(forUbiquityContainerIdentifier: nil)
    },
    iCloudDriveURLProvider: @escaping @Sendable () -> URL? = {
      Self.defaultICloudDriveURL()
    }
  ) {
    self.importExportService = ImportExportService(paths: paths)
    self.containerURLProvider = containerURLProvider
    self.iCloudDriveURLProvider = iCloudDriveURLProvider
  }

  public func summary() async throws -> ICloudBackupSummary {
    try await Task.detached(priority: .utility) {
      let backupsDirectory = try resolvedBackupsDirectoryURL()
      let backups = try backupURLs(in: backupsDirectory)
      return ICloudBackupSummary(
        backupsDirectory: backupsDirectory,
        backupCount: backups.count,
        latestBackupURL: backups.first
      )
    }.value
  }

  public func exportBackup(now: Date = .now) async throws -> URL {
    try await Task.detached(priority: .userInitiated) {
      let backupsDirectory = try resolvedBackupsDirectoryURL()
      try FileManager.default.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
      let exportedURL = try importExportService.exportBackup(to: backupsDirectory, now: now)
      try pruneOldBackups(in: backupsDirectory, keeping: exportedURL)
      return exportedURL
    }.value
  }

  @discardableResult
  public func importLatestBackup(mode: BackupImportMode) async throws -> URL {
    try await Task.detached(priority: .userInitiated) {
      let backupURL = try latestBackupURL()
      try requestDownloadIfNeeded(for: backupURL)
      try importExportService.importBackup(from: backupURL, mode: mode)
      return backupURL
    }.value
  }

  public func backupsDirectoryURL() async throws -> URL {
    try await Task.detached(priority: .utility) {
      try resolvedBackupsDirectoryURL()
    }.value
  }

  private func latestBackupURL() throws -> URL {
    let backups = try backupURLs(in: resolvedBackupsDirectoryURL())
    guard let latestBackup = backups.first else {
      throw ICloudBackupError.noBackups
    }

    return latestBackup
  }

  private func resolvedBackupsDirectoryURL() throws -> URL {
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

  private func backupURLs(in directory: URL) throws -> [URL] {
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

  private func pruneOldBackups(in directory: URL, keeping keptURL: URL) throws {
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

  private func requestDownloadIfNeeded(for url: URL) throws {
    let deadline = Date().addingTimeInterval(20)
    let fileManager = FileManager.default
    while true {
      let pendingURLs = try requestPendingDownloads(in: url, fileManager: fileManager)
      guard !pendingURLs.contains(where: { isNotDownloaded($0) }) else {
        guard Date() < deadline else {
          return
        }

        Thread.sleep(forTimeInterval: 0.2)
        continue
      }

      return
    }
  }

  private func requestPendingDownloads(in url: URL, fileManager: FileManager) throws -> [URL] {
    var urls = [url]

    guard let enumerator = fileManager.enumerator(
      at: url,
      includingPropertiesForKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey],
      options: [.skipsHiddenFiles]
    ) else {
      return urls
    }

    for case let childURL as URL in enumerator {
      urls.append(childURL)
    }

    for itemURL in urls where fileManager.isUbiquitousItem(at: itemURL) && isNotDownloaded(itemURL) {
      try? fileManager.startDownloadingUbiquitousItem(at: itemURL)
    }

    return urls
  }

  private func isNotDownloaded(_ url: URL) -> Bool {
    let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
    return values?.ubiquitousItemDownloadingStatus == .notDownloaded
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
