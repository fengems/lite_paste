import Foundation

extension BackupBlobMapper {
  static func copyExternalBlobsForExport(
    in records: [ClipboardRecord],
    to backupBlobsDirectory: URL
  ) throws -> [ClipboardRecord] {
    var copiedPaths: [String: String] = [:]

    return try records.map { record in
      var record = record
      record.contents = try record.contents.map { snapshot in
        try copyExternalBlobForExport(
          in: snapshot,
          to: backupBlobsDirectory,
          copiedPaths: &copiedPaths
        )
      }

      if let previewFilePath = record.previewFilePath {
        record.previewFilePath = try copiedBlobPathForExport(
          from: previewFilePath,
          to: backupBlobsDirectory,
          copiedPaths: &copiedPaths
        )
      }

      return record
    }
  }

  private static func copyExternalBlobForExport(
    in snapshot: ClipboardContentSnapshot,
    to backupBlobsDirectory: URL,
    copiedPaths: inout [String: String]
  ) throws -> ClipboardContentSnapshot {
    guard snapshot.storageMode == .external,
          let externalFilePath = snapshot.externalFilePath else {
      return snapshot
    }

    var snapshot = snapshot
    snapshot.externalFilePath = try copiedBlobPathForExport(
      from: externalFilePath,
      to: backupBlobsDirectory,
      copiedPaths: &copiedPaths
    )
    return snapshot
  }

  private static func copiedBlobPathForExport(
    from path: String,
    to backupBlobsDirectory: URL,
    copiedPaths: inout [String: String]
  ) throws -> String {
    if let copiedPath = copiedPaths[path] {
      return copiedPath
    }

    let sourceURL = URL(fileURLWithPath: path)
    let preferredDestinationURL = backupBlobsDirectory.appending(path: sourceURL.lastPathComponent)

    guard FileManager.default.fileExists(atPath: sourceURL.path) else {
      throw BackupError.missingBlob(sourceURL.lastPathComponent)
    }

    try FileManager.default.createDirectory(at: backupBlobsDirectory, withIntermediateDirectories: true)
    let destinationURL = uniqueDestinationURL(for: sourceURL, preferredDestinationURL: preferredDestinationURL)
    if !FileManager.default.fileExists(atPath: destinationURL.path) {
      try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    copiedPaths[path] = destinationURL.path
    return destinationURL.path
  }
}
