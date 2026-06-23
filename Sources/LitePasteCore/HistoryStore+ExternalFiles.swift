import Foundation

@MainActor
extension HistoryStore {
  func removeExternalFiles(in records: [ClipboardRecord]) {
    removeExternalFiles(in: records.flatMap(externalFileSnapshots))
  }

  func removeExternalFiles(in payload: ClipboardPayload) {
    removeExternalFiles(in: externalFileSnapshots(in: payload))
  }

  private func removeExternalFiles(in snapshots: [ClipboardContentSnapshot]) {
    blobStorage.removeExternalFiles(in: snapshots)
  }

  private func externalFileSnapshots(in record: ClipboardRecord) -> [ClipboardContentSnapshot] {
    record.contents + previewSnapshot(from: record.previewFilePath)
  }

  private func externalFileSnapshots(in payload: ClipboardPayload) -> [ClipboardContentSnapshot] {
    payload.contents + previewSnapshot(from: payload.previewFilePath)
  }

  private func previewSnapshot(from path: String?) -> [ClipboardContentSnapshot] {
    guard let path else {
      return []
    }

    return [
      ClipboardContentSnapshot(
        pasteboardType: "com.litepaste.preview",
        storageMode: .external,
        externalFilePath: path,
        byteSize: 0,
        displayOrder: Int.max
      )
    ]
  }
}
