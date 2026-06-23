import AppKit
import Foundation
import LitePasteCore

extension ClipboardRecordActions {
  func showInFinder(_ record: ClipboardRecord) -> ClipboardExternalActionResult {
    let urls = fileURLs(from: record).filter { FileManager.default.fileExists(atPath: $0.path) }
    guard !urls.isEmpty else {
      return .failed(
        title: AppText.value("无法在 Finder 中显示", "Unable To Show In Finder"),
        message: AppText.value("这些文件可能已经被移动或删除。", "These files may have been moved or deleted.")
      )
    }

    NSWorkspace.shared.activateFileViewerSelecting(urls)
    return .completed(message: AppText.value("已在 Finder 显示", "Shown In Finder"))
  }

  func fileURLs(from record: ClipboardRecord) -> [URL] {
    let contentURLs = record.contents
      .sorted { $0.displayOrder < $1.displayOrder }
      .compactMap(fileURL)

    if !contentURLs.isEmpty {
      return contentURLs
    }

    guard let text = record.plainText else {
      return []
    }

    return text
      .split(separator: "\n")
      .map { URL(fileURLWithPath: String($0)) }
  }

  private func fileURL(from snapshot: ClipboardContentSnapshot) -> URL? {
    guard snapshot.pasteboardType == ClipboardFilePayloadBuilder.fileURLPasteboardType,
          let data = data(from: snapshot),
          let path = String(data: data, encoding: .utf8),
          !path.isEmpty else {
      return nil
    }

    return URL(fileURLWithPath: path)
  }

  func data(from snapshot: ClipboardContentSnapshot) -> Data? {
    switch snapshot.storageMode {
    case .inline:
      snapshot.inlineData
    case .external:
      snapshot.externalFilePath.flatMap { try? Data(contentsOf: URL(fileURLWithPath: $0)) }
    }
  }
}
