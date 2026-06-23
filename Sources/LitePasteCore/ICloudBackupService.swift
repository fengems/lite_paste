import Foundation

public struct ICloudBackupService: Sendable {
  let importExportService: ImportExportService
  let containerURLProvider: @Sendable () -> URL?
  let iCloudDriveURLProvider: @Sendable () -> URL?

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
}
