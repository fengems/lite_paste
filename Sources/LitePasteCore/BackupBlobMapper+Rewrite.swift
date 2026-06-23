import Foundation

extension BackupBlobMapper {
  static func rewriteExternalBlobPaths(
    in records: [ClipboardRecord],
    to blobsDirectory: URL
  ) -> [ClipboardRecord] {
    records.map { record in
      var record = record
      record.contents = record.contents.map { snapshot in
        rewriteExternalBlobPath(in: snapshot, to: blobsDirectory)
      }

      if let previewFilePath = record.previewFilePath {
        record.previewFilePath = rewrittenBlobPath(from: previewFilePath, to: blobsDirectory)
      }

      return record
    }
  }

  private static func rewriteExternalBlobPath(
    in snapshot: ClipboardContentSnapshot,
    to blobsDirectory: URL
  ) -> ClipboardContentSnapshot {
    guard snapshot.storageMode == .external,
          let externalFilePath = snapshot.externalFilePath else {
      return snapshot
    }

    var snapshot = snapshot
    snapshot.externalFilePath = rewrittenBlobPath(from: externalFilePath, to: blobsDirectory)
    return snapshot
  }

  private static func rewrittenBlobPath(from path: String, to blobsDirectory: URL) -> String {
    let filename = URL(fileURLWithPath: path).lastPathComponent
    return blobsDirectory.appending(path: filename).path
  }
}
