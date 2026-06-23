import Foundation

enum BackupValidator {
  static func validateBackup(at backupURL: URL, supportedFormatVersion: Int) throws {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: backupURL.path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
      throw BackupError.invalidBackup
    }

    let manifest = try loadManifest(from: backupURL)
    guard manifest.formatVersion == supportedFormatVersion else {
      throw BackupError.unsupportedFormatVersion(manifest.formatVersion)
    }

    try validateHistoryIfExists(
      at: BackupLayout.historyURL(in: backupURL),
      blobsDirectory: BackupLayout.blobsDirectory(in: backupURL)
    )
    try validateSettingsIfExists(at: BackupLayout.settingsURL(in: backupURL))
    try validateBlobsIfExists(at: BackupLayout.blobsDirectory(in: backupURL))
  }

  private static func loadManifest(from backupURL: URL) throws -> BackupManifest {
    let manifestURL = BackupLayout.manifestURL(in: backupURL)
    guard let data = try? Data(contentsOf: manifestURL),
          let manifest = try? JSONDecoder.litePaste.decode(BackupManifest.self, from: data) else {
      throw BackupError.invalidBackup
    }

    return manifest
  }

  private static func validateHistoryIfExists(at url: URL, blobsDirectory: URL) throws {
    guard FileManager.default.fileExists(atPath: url.path) else {
      return
    }

    let records = try JSONClipboardHistoryRepository(url: url).load()
    try validateExternalBlobs(in: records, blobsDirectory: blobsDirectory)
  }

  private static func validateExternalBlobs(in records: [ClipboardRecord], blobsDirectory: URL) throws {
    for record in records {
      for snapshot in record.contents where snapshot.storageMode == .external {
        guard let externalFilePath = snapshot.externalFilePath else {
          throw BackupError.missingBlob("")
        }

        try validateExternalBlob(path: externalFilePath, byteSize: snapshot.byteSize, blobsDirectory: blobsDirectory)
      }

      if let previewFilePath = record.previewFilePath {
        try validateExternalBlob(path: previewFilePath, byteSize: nil, blobsDirectory: blobsDirectory)
      }
    }
  }

  private static func validateExternalBlob(path: String, byteSize: Int?, blobsDirectory: URL) throws {
    let filename = URL(fileURLWithPath: path).lastPathComponent
    guard !filename.isEmpty else {
      throw BackupError.missingBlob(path)
    }

    let blobURL = blobsDirectory.appending(path: filename)
    guard FileManager.default.fileExists(atPath: blobURL.path) else {
      throw BackupError.missingBlob(filename)
    }

    guard let byteSize, byteSize > 0 else {
      return
    }

    let attributes = try FileManager.default.attributesOfItem(atPath: blobURL.path)
    let actualByteSize = (attributes[.size] as? NSNumber)?.intValue
    guard actualByteSize == byteSize else {
      throw BackupError.missingBlob(filename)
    }
  }

  private static func validateSettingsIfExists(at url: URL) throws {
    guard let data = try? Data(contentsOf: url) else {
      return
    }

    do {
      _ = try JSONDecoder.litePaste.decode(AppSettings.self, from: data)
    } catch {
      throw BackupError.invalidBackup
    }
  }

  private static func validateBlobsIfExists(at url: URL) throws {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
      return
    }

    guard isDirectory.boolValue else {
      throw BackupError.invalidBackup
    }
  }
}
