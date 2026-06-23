import Foundation
import LitePasteCore

func checkImportExportRoundTrip() {
  do {
    try withTemporaryDirectory(prefix: "LitePasteBackupRoundTrip") { directory in
      let appDirectory = directory.appending(path: "AppData", directoryHint: .isDirectory)
      let backupParent = directory.appending(path: "Backups", directoryHint: .isDirectory)
      let paths = AppStoragePaths(applicationSupportDirectory: appDirectory)
      let service = ImportExportService(paths: paths)
      let legacyRepository = JSONClipboardHistoryRepository(url: paths.historyURL)
      let repository = MigratingClipboardHistoryRepository(
        sqliteURL: paths.sqliteHistoryURL,
        legacyJSONURL: paths.historyURL
      )

      try paths.ensureBlobsDirectoryExists()
      try FileManager.default.createDirectory(at: backupParent, withIntermediateDirectories: true)

      let sourceBlob = paths.blobsDirectory.appending(path: "image.bin")
      let orphanBlob = paths.blobsDirectory.appending(path: "orphan.bin")
      try Data("blob-a".utf8).write(to: sourceBlob, options: .atomic)
      try Data("orphan".utf8).write(to: orphanBlob, options: .atomic)
      let sourceRecord = ClipboardRecord(
        kind: .image,
        title: "image",
        searchText: "image",
        lastCopiedAt: Date(timeIntervalSince1970: 30),
        contentHash: "hash-a",
        contents: [
          ClipboardContentSnapshot(
            pasteboardType: "public.data",
            storageMode: .external,
            externalFilePath: sourceBlob.path,
            byteSize: 6,
            displayOrder: 0
          )
        ],
        previewFilePath: sourceBlob.path
      )
      try legacyRepository.save([sourceRecord])
      try JSONEncoder.litePaste.encode(AppSettings(hotkey: "command+option+space", viewMode: .list))
        .write(to: paths.settingsURL, options: .atomic)

      let backupURL = try service.exportBackup(
        to: backupParent, now: Date(timeIntervalSince1970: 100))
      let exportedHistory = try JSONClipboardHistoryRepository(
        url: backupURL.appending(path: "history.json")
      ).load()
      let exportedBlob = backupURL.appending(path: "Blobs/image.bin")
      let exportedOrphanBlob = backupURL.appending(path: "Blobs/orphan.bin")

      expect(
        FileManager.default.fileExists(atPath: exportedBlob.path),
        "Export should copy external blobs")
      expect(
        !FileManager.default.fileExists(atPath: exportedOrphanBlob.path),
        "Export should skip unreferenced orphan blobs")
      expect(
        exportedHistory.first?.previewFilePath == exportedBlob.path,
        "Export should rewrite preview blob paths into backup directory"
      )

      let backupsBeforeFailedExport = try backupDirectoryNames(in: backupParent)
      let missingExportRecord = ClipboardRecord(
        kind: .image,
        title: "missing export",
        searchText: "missing export",
        lastCopiedAt: Date(timeIntervalSince1970: 35),
        contentHash: "hash-missing-export",
        contents: [
          ClipboardContentSnapshot(
            pasteboardType: "public.data",
            storageMode: .external,
            externalFilePath: paths.blobsDirectory.appending(path: "missing-export.bin").path,
            byteSize: 6,
            displayOrder: 0
          )
        ]
      )
      try repository.save([missingExportRecord])
      do {
        _ = try service.exportBackup(to: backupParent, now: Date(timeIntervalSince1970: 101))
        fatalError("Export should fail when referenced blobs are missing")
      } catch BackupError.missingBlob("missing-export.bin") {
      } catch {
        fatalError("Export should report the missing blob name, got \(error)")
      }
      let backupsAfterFailedExport = try backupDirectoryNames(in: backupParent)
      expect(
        backupsAfterFailedExport == backupsBeforeFailedExport,
        "Failed export should remove partial backup directories"
      )

      try FileManager.default.removeItem(at: appDirectory)
      try service.importBackup(from: backupURL, mode: .replace)

      let restoredHistory = try repository.load()
      let restoredBlob = paths.blobsDirectory.appending(path: "image.bin")
      let restoredSettings = try JSONDecoder.litePaste.decode(
        AppSettings.self,
        from: Data(contentsOf: paths.settingsURL)
      )

      expect(restoredHistory.count == 1, "Replace import should restore exported history")
      expect(
        restoredHistory.first?.previewFilePath == restoredBlob.path,
        "Replace import should rewrite preview path")
      expect(
        FileManager.default.fileExists(atPath: restoredBlob.path),
        "Replace import should restore blob files")
      expect(
        restoredSettings.hotkey == "command+option+space", "Replace import should restore settings")

      let localRecord = ClipboardRecord(
        kind: .text,
        title: "local",
        searchText: "local",
        lastCopiedAt: Date(timeIntervalSince1970: 50),
        contentHash: "hash-local"
      )
      try repository.save([localRecord, sourceRecord])

      let mergeBackup = directory.appending(
        path: "Merge.litepastebackup", directoryHint: .isDirectory)
      let mergeBlobs = mergeBackup.appending(path: "Blobs", directoryHint: .isDirectory)
      try FileManager.default.createDirectory(at: mergeBlobs, withIntermediateDirectories: true)
      try Data(#"{"createdAt":"2026-01-01T00:00:00Z","formatVersion":1}"#.utf8)
        .write(to: mergeBackup.appending(path: "manifest.json"))
      try JSONEncoder.litePaste.encode(AppSettings(hotkey: "command+option+v", viewMode: .card))
        .write(to: mergeBackup.appending(path: "settings.json"))

      let incomingBlob = mergeBlobs.appending(path: "incoming.bin")
      let collisionBlob = paths.blobsDirectory.appending(path: "incoming.bin")
      try Data("local-collision".utf8).write(to: collisionBlob, options: .atomic)
      try Data("incoming".utf8).write(to: incomingBlob, options: .atomic)
      let duplicateRecord = ClipboardRecord(
        kind: .text,
        title: "duplicate",
        searchText: "duplicate",
        lastCopiedAt: Date(timeIntervalSince1970: 40),
        contentHash: "hash-a"
      )
      let incomingRecord = ClipboardRecord(
        kind: .image,
        title: "incoming",
        searchText: "incoming",
        lastCopiedAt: Date(timeIntervalSince1970: 60),
        contentHash: "hash-incoming",
        contents: [
          ClipboardContentSnapshot(
            pasteboardType: "public.data",
            storageMode: .external,
            externalFilePath: incomingBlob.path,
            byteSize: 8,
            displayOrder: 0
          )
        ],
        previewFilePath: incomingBlob.path
      )
      try JSONEncoder.litePaste.encode([duplicateRecord, incomingRecord])
        .write(to: mergeBackup.appending(path: "history.json"), options: .atomic)

      try service.importBackup(from: mergeBackup, mode: .merge)

      let mergedHistory = try repository.load()
      let hashCounts = Dictionary(grouping: mergedHistory, by: \.contentHash).mapValues(\.count)
      let mergedSettings = try JSONDecoder.litePaste.decode(
        AppSettings.self,
        from: Data(contentsOf: paths.settingsURL)
      )
      let importedBlob = paths.blobsDirectory.appending(path: "incoming.bin")
      let importedRecord = mergedHistory.first { $0.contentHash == "hash-incoming" }
      let importedPreviewPath = importedRecord?.previewFilePath ?? ""

      expect(
        mergedHistory.count == 3,
        "Merge import should keep existing and add unique incoming records")
      expect(hashCounts["hash-a"] == 1, "Merge import should deduplicate by content hash")
      expect(
        importedPreviewPath != importedBlob.path,
        "Merge import should avoid overwriting existing blob filename collisions"
      )
      expect(
        FileManager.default.fileExists(atPath: importedPreviewPath),
        "Merge import should copy incoming blobs")
      expect(
        (try? Data(contentsOf: URL(fileURLWithPath: importedPreviewPath))) == Data("incoming".utf8),
        "Merge import should keep incoming blob data when resolving collisions"
      )
      expect(
        (try? Data(contentsOf: collisionBlob)) == Data("local-collision".utf8),
        "Merge import should not overwrite existing colliding blobs"
      )
      expect(
        mergedSettings.hotkey == "command+option+space",
        "Merge import should not overwrite existing settings")

      let emptyBackup = directory.appending(
        path: "Empty.litepastebackup", directoryHint: .isDirectory)
      try FileManager.default.createDirectory(at: emptyBackup, withIntermediateDirectories: true)
      try Data(#"{"createdAt":"2026-01-01T00:00:00Z","formatVersion":1}"#.utf8)
        .write(to: emptyBackup.appending(path: "manifest.json"))
      try service.importBackup(from: emptyBackup, mode: .replace)

      let emptyReplaceHistory = try repository.load()
      expect(
        emptyReplaceHistory.isEmpty, "Replace import without history should clear existing history")
      expect(
        !FileManager.default.fileExists(atPath: paths.settingsURL.path),
        "Replace import without settings should remove existing settings so defaults are used"
      )
      expect(
        !FileManager.default.fileExists(atPath: paths.blobsDirectory.path),
        "Replace import without blobs should clear existing blobs"
      )
    }
  } catch {
    fatalError("Import/export round-trip check failed: \(error)")
  }
}

func backupDirectoryNames(in directory: URL) throws -> [String] {
  try FileManager.default
    .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    .map(\.lastPathComponent)
    .sorted()
}
