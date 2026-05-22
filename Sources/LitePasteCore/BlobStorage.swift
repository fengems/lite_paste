import Foundation

public protocol BlobStorage: Sendable {
  func save(data: Data, preferredExtension: String) throws -> String
  func snapshot(
    data: Data,
    pasteboardType: String,
    preferredExtension: String,
    displayOrder: Int
  ) throws -> ClipboardContentSnapshot
  func removeExternalFiles(in snapshots: [ClipboardContentSnapshot])
}

public struct LocalBlobStorage: BlobStorage {
  private let directory: URL

  public init(directory: URL = AppPaths.blobsDirectory) {
    self.directory = directory
  }

  public func save(data: Data, preferredExtension: String) throws -> String {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let filename = "\(UUID().uuidString).\(preferredExtension)"
    let url = directory.appending(path: filename)
    try data.write(to: url, options: .atomic)
    return url.path
  }

  public func snapshot(
    data: Data,
    pasteboardType: String,
    preferredExtension: String,
    displayOrder: Int
  ) throws -> ClipboardContentSnapshot {
    let path = try save(data: data, preferredExtension: preferredExtension)
    return ClipboardContentSnapshot(
      pasteboardType: pasteboardType,
      storageMode: .external,
      externalFilePath: path,
      byteSize: data.count,
      displayOrder: displayOrder
    )
  }

  public func removeExternalFiles(in snapshots: [ClipboardContentSnapshot]) {
    let rootPath = directory.standardizedFileURL.path

    for snapshot in snapshots where snapshot.storageMode == .external {
      guard let externalFilePath = snapshot.externalFilePath else {
        continue
      }

      let url = URL(fileURLWithPath: externalFilePath).standardizedFileURL
      guard url.path.hasPrefix(rootPath) else {
        continue
      }

      try? FileManager.default.removeItem(at: url)
    }
  }
}

