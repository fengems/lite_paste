import Foundation
import LitePasteCore

struct ClipboardBlobStore {
  func save(data: Data, preferredExtension: String) throws -> String {
    try AppPaths.ensureBlobsDirectoryExists()
    let filename = "\(UUID().uuidString).\(preferredExtension)"
    let url = AppPaths.blobsDirectory.appending(path: filename)
    try data.write(to: url, options: .atomic)
    return url.path
  }

  func snapshot(
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
}

