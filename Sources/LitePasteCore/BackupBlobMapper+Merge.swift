import Foundation

extension BackupBlobMapper {
  static func copyExternalBlobsForMerge(
    in records: [ClipboardRecord],
    from sourceBlobsDirectory: URL,
    to destinationBlobsDirectory: URL
  ) throws -> [ClipboardRecord] {
    var copiedPaths: [String: String] = [:]

    return try records.map { record in
      var record = record
      record.contents = try record.contents.map { snapshot in
        try copyExternalBlobForMerge(
          in: snapshot,
          from: sourceBlobsDirectory,
          to: destinationBlobsDirectory,
          copiedPaths: &copiedPaths
        )
      }

      if let previewFilePath = record.previewFilePath {
        record.previewFilePath = try copiedBlobPathForMerge(
          from: previewFilePath,
          sourceBlobsDirectory: sourceBlobsDirectory,
          destinationBlobsDirectory: destinationBlobsDirectory,
          copiedPaths: &copiedPaths
        )
      }

      return record
    }
  }

  private static func copyExternalBlobForMerge(
    in snapshot: ClipboardContentSnapshot,
    from sourceBlobsDirectory: URL,
    to destinationBlobsDirectory: URL,
    copiedPaths: inout [String: String]
  ) throws -> ClipboardContentSnapshot {
    guard snapshot.storageMode == .external,
          let externalFilePath = snapshot.externalFilePath else {
      return snapshot
    }

    var snapshot = snapshot
    snapshot.externalFilePath = try copiedBlobPathForMerge(
      from: externalFilePath,
      sourceBlobsDirectory: sourceBlobsDirectory,
      destinationBlobsDirectory: destinationBlobsDirectory,
      copiedPaths: &copiedPaths
    )
    return snapshot
  }

  private static func copiedBlobPathForMerge(
    from path: String,
    sourceBlobsDirectory: URL,
    destinationBlobsDirectory: URL,
    copiedPaths: inout [String: String]
  ) throws -> String {
    if let copiedPath = copiedPaths[path] {
      return copiedPath
    }

    let filename = URL(fileURLWithPath: path).lastPathComponent
    let sourceURL = existingBlobSourceURL(
      originalPath: path,
      sourceBlobsDirectory: sourceBlobsDirectory
    )
    let preferredDestinationURL = destinationBlobsDirectory.appending(path: filename)

    guard let sourceURL else {
      copiedPaths[path] = preferredDestinationURL.path
      return preferredDestinationURL.path
    }

    try FileManager.default.createDirectory(at: destinationBlobsDirectory, withIntermediateDirectories: true)
    let destinationURL = uniqueDestinationURL(for: sourceURL, preferredDestinationURL: preferredDestinationURL)
    if !FileManager.default.fileExists(atPath: destinationURL.path) {
      try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    copiedPaths[path] = destinationURL.path
    return destinationURL.path
  }

  private static func existingBlobSourceURL(originalPath: String, sourceBlobsDirectory: URL) -> URL? {
    let filename = URL(fileURLWithPath: originalPath).lastPathComponent
    let backupBlobURL = sourceBlobsDirectory.appending(path: filename)
    if FileManager.default.fileExists(atPath: backupBlobURL.path) {
      return backupBlobURL
    }

    let originalURL = URL(fileURLWithPath: originalPath)
    if FileManager.default.fileExists(atPath: originalURL.path) {
      return originalURL
    }

    return nil
  }
}
