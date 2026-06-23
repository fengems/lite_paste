import Foundation
import LitePasteCore

func checkImportExportValidation() {
  let service = ImportExportService()

  do {
    try withTemporaryDirectory(prefix: "LitePasteBackupValidation") { directory in
      let validBackup = directory.appending(
        path: "Valid.litepastebackup", directoryHint: .isDirectory)
      try FileManager.default.createDirectory(at: validBackup, withIntermediateDirectories: true)
      try Data(#"{"createdAt":"2026-01-01T00:00:00Z","formatVersion":1}"#.utf8)
        .write(to: validBackup.appending(path: "manifest.json"))
      try JSONEncoder.litePaste.encode([
        ClipboardRecord(kind: .text, title: "backup", searchText: "backup", contentHash: "backup")
      ])
      .write(to: validBackup.appending(path: "history.json"))
      try JSONEncoder.litePaste.encode(AppSettings())
        .write(to: validBackup.appending(path: "settings.json"))
      try FileManager.default.createDirectory(
        at: validBackup.appending(path: "Blobs", directoryHint: .isDirectory),
        withIntermediateDirectories: true)
      try service.validateBackup(at: validBackup)

      let validBlobBackup = directory.appending(
        path: "ValidBlob.litepastebackup", directoryHint: .isDirectory)
      let validBlobs = validBlobBackup.appending(path: "Blobs", directoryHint: .isDirectory)
      try FileManager.default.createDirectory(at: validBlobs, withIntermediateDirectories: true)
      try Data(#"{"createdAt":"2026-01-01T00:00:00Z","formatVersion":1}"#.utf8)
        .write(to: validBlobBackup.appending(path: "manifest.json"))
      try Data("blob".utf8).write(to: validBlobs.appending(path: "image.bin"))
      try JSONEncoder.litePaste.encode([
        ClipboardRecord(
          kind: .image,
          title: "image",
          searchText: "image",
          contentHash: "image",
          contents: [
            ClipboardContentSnapshot(
              pasteboardType: "public.png",
              storageMode: .external,
              externalFilePath: validBlobs.appending(path: "image.bin").path,
              byteSize: 4,
              displayOrder: 0
            )
          ],
          previewFilePath: validBlobs.appending(path: "image.bin").path
        )
      ])
      .write(to: validBlobBackup.appending(path: "history.json"))
      try service.validateBackup(at: validBlobBackup)

      let brokenManifest = directory.appending(
        path: "Broken.litepastebackup", directoryHint: .isDirectory)
      try FileManager.default.createDirectory(at: brokenManifest, withIntermediateDirectories: true)
      try Data("not json".utf8).write(to: brokenManifest.appending(path: "manifest.json"))

      do {
        try service.validateBackup(at: brokenManifest)
        fatalError("Broken backup manifest should be rejected")
      } catch BackupError.invalidBackup {
        // Expected.
      }

      let futureBackup = directory.appending(
        path: "Future.litepastebackup", directoryHint: .isDirectory)
      try FileManager.default.createDirectory(at: futureBackup, withIntermediateDirectories: true)
      try Data(#"{"createdAt":"2026-01-01T00:00:00Z","formatVersion":999}"#.utf8)
        .write(to: futureBackup.appending(path: "manifest.json"))

      do {
        try service.validateBackup(at: futureBackup)
        fatalError("Unsupported backup format should be rejected")
      } catch BackupError.unsupportedFormatVersion(999) {
        // Expected.
      }

      let missingBlobBackup = directory.appending(
        path: "MissingBlob.litepastebackup", directoryHint: .isDirectory)
      try FileManager.default.createDirectory(
        at: missingBlobBackup, withIntermediateDirectories: true)
      try Data(#"{"createdAt":"2026-01-01T00:00:00Z","formatVersion":1}"#.utf8)
        .write(to: missingBlobBackup.appending(path: "manifest.json"))
      try FileManager.default.createDirectory(
        at: missingBlobBackup.appending(path: "Blobs", directoryHint: .isDirectory),
        withIntermediateDirectories: true)
      try JSONEncoder.litePaste.encode([
        ClipboardRecord(
          kind: .image,
          title: "missing",
          searchText: "missing",
          contentHash: "missing",
          contents: [
            ClipboardContentSnapshot(
              pasteboardType: "public.png",
              storageMode: .external,
              externalFilePath: missingBlobBackup.appending(path: "Blobs/missing.png").path,
              byteSize: 7,
              displayOrder: 0
            )
          ]
        )
      ])
      .write(to: missingBlobBackup.appending(path: "history.json"))

      do {
        try service.validateBackup(at: missingBlobBackup)
        fatalError("Backup with missing external blob should be rejected")
      } catch BackupError.missingBlob("missing.png") {
        // Expected.
      }

      expect(
        BackupError.invalidBackup.localizedDescription == "备份文件无效或已损坏。",
        "Backup errors should have user-facing localized descriptions"
      )
      expect(
        BackupError.missingBlob("missing.png").localizedDescription == "备份缺少媒体文件：missing.png。",
        "Missing blob errors should name the missing file"
      )
    }
  } catch {
    fatalError("Import/export validation check failed: \(error)")
  }
}
