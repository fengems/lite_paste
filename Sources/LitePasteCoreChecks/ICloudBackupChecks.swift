import Foundation
import LitePasteCore

func checkICloudBackupService() {
  do {
    try withTemporaryDirectory(prefix: "LitePasteICloudBackup") { directory in
      let appDirectory = directory.appending(path: "AppData", directoryHint: .isDirectory)
      let iCloudContainer = directory.appending(
        path: "iCloudContainer", directoryHint: .isDirectory)
      let iCloudDrive = directory.appending(path: "iCloudDrive", directoryHint: .isDirectory)
      let paths = AppStoragePaths(applicationSupportDirectory: appDirectory)
      let repository = MigratingClipboardHistoryRepository(
        sqliteURL: paths.sqliteHistoryURL,
        legacyJSONURL: paths.historyURL
      )
      let service = ICloudBackupService(
        paths: paths,
        containerURLProvider: { iCloudContainer },
        iCloudDriveURLProvider: { nil }
      )

      try paths.ensureApplicationSupportDirectoryExists()
      let record = ClipboardRecord(
        kind: .text,
        title: "icloud",
        searchText: "icloud",
        lastCopiedAt: Date(timeIntervalSince1970: 10),
        contentHash: "icloud-hash",
        plainText: "icloud"
      )
      try repository.save([record])
      try JSONEncoder.litePaste.encode(AppSettings(viewMode: .list))
        .write(to: paths.settingsURL, options: .atomic)

      let exportedURL = try waitForAsync {
        try await service.exportBackup(now: Date(timeIntervalSince1970: 200))
      }
      expect(
        exportedURL.path.hasPrefix(iCloudContainer.path),
        "iCloud backup should export into the provided iCloud container"
      )
      expect(
        exportedURL.lastPathComponent.hasPrefix("LitePaste-")
          && exportedURL.pathExtension == "litepastebackup",
        "iCloud backup should use normal backup naming"
      )

      let summary = try waitForAsync {
        try await service.summary()
      }
      expect(summary.backupCount == 1, "iCloud backup summary should count exported backups")
      expect(
        summary.latestBackupURL?.standardizedFileURL.path == exportedURL.standardizedFileURL.path,
        "iCloud backup summary should expose the latest backup"
      )

      let newerRecord = ClipboardRecord(
        kind: .text,
        title: "icloud newer",
        searchText: "icloud newer",
        lastCopiedAt: Date(timeIntervalSince1970: 20),
        contentHash: "icloud-newer-hash",
        plainText: "icloud newer"
      )
      try repository.save([newerRecord])
      let newerExportedURL = try waitForAsync {
        try await service.exportBackup(now: Date(timeIntervalSince1970: 260))
      }
      let summaryAfterSecondExport = try waitForAsync {
        try await service.summary()
      }
      expect(
        summaryAfterSecondExport.backupCount == 1,
        "iCloud backup should keep only the latest backup")
      expect(
        summaryAfterSecondExport.latestBackupURL?.standardizedFileURL.path
          == newerExportedURL.standardizedFileURL.path,
        "iCloud backup summary should pick the newest backup"
      )
      expect(
        !FileManager.default.fileExists(atPath: exportedURL.path),
        "iCloud backup should remove the previous backup after a successful export"
      )

      try FileManager.default.removeItem(at: appDirectory)
      let importedURL = try waitForAsync {
        try await service.importLatestBackup(mode: .replace)
      }
      expect(
        importedURL.standardizedFileURL.path == newerExportedURL.standardizedFileURL.path,
        "iCloud import should restore the latest backup"
      )

      let restoredHistory = try MigratingClipboardHistoryRepository(
        sqliteURL: paths.sqliteHistoryURL,
        legacyJSONURL: paths.historyURL
      ).load()
      let restoredSettings = try JSONDecoder.litePaste.decode(
        AppSettings.self,
        from: Data(contentsOf: paths.settingsURL)
      )
      expect(
        restoredHistory.map(\.contentHash) == [newerRecord.contentHash]
          && restoredHistory.first?.plainText == newerRecord.plainText,
        "iCloud import should restore backed up history"
      )
      expect(restoredSettings.viewMode == .list, "iCloud import should restore backed up settings")

      try FileManager.default.createDirectory(at: iCloudDrive, withIntermediateDirectories: true)
      try repository.save([record])
      let fallbackService = ICloudBackupService(
        paths: paths,
        containerURLProvider: { nil },
        iCloudDriveURLProvider: { iCloudDrive }
      )
      let fallbackExportedURL = try waitForAsync {
        try await fallbackService.exportBackup(now: Date(timeIntervalSince1970: 320))
      }
      expect(
        fallbackExportedURL.path.hasPrefix(iCloudDrive.path),
        "iCloud backup should fall back to the user iCloud Drive folder when the app container is unavailable"
      )

      let unavailableService = ICloudBackupService(
        paths: paths,
        containerURLProvider: { nil },
        iCloudDriveURLProvider: { nil }
      )
      do {
        _ = try waitForAsync {
          try await unavailableService.summary()
        }
        fatalError("Unavailable iCloud container should fail")
      } catch ICloudBackupError.unavailable {
        // Expected.
      }
    }
  } catch {
    fatalError("iCloud backup service check failed: \(error)")
  }
}
