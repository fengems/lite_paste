import AppKit
import Foundation
import LitePasteCore

extension ClipboardRecordActions {
  func exportImage(_ record: ClipboardRecord) -> ClipboardExternalActionResult {
    guard let sourceURL = imageSourceURL(for: record) else {
      return .failed(
        title: AppText.value("无法导出图片", "Unable To Export Image"),
        message: AppText.value("这条历史记录没有可导出的图片文件。", "This history item does not contain an exportable image file.")
      )
    }

    guard FileManager.default.fileExists(atPath: sourceURL.path) else {
      return .failed(
        title: AppText.value("无法导出图片", "Unable To Export Image"),
        message: AppText.value("图片原始数据已经不存在。", "The original image data no longer exists.")
      )
    }

    let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    let destination = uniqueDestination(
      in: downloads,
      filename: exportFilename(for: record, sourceURL: sourceURL)
    )

    do {
      try FileManager.default.copyItem(at: sourceURL, to: destination)
      NSWorkspace.shared.activateFileViewerSelecting([destination])
      return .completed(message: AppText.value("图片已导出", "Image Exported"))
    } catch {
      return .failed(title: AppText.value("导出图片失败", "Image Export Failed"), message: error.localizedDescription)
    }
  }

  private func imageSourceURL(for record: ClipboardRecord) -> URL? {
    if let sourcePath = record.contents
      .first(where: { $0.storageMode == .external && $0.externalFilePath != nil })?
      .externalFilePath {
      return URL(fileURLWithPath: sourcePath)
    }

    return record.previewFilePath.map { URL(fileURLWithPath: $0) }
  }

  private func exportFilename(for record: ClipboardRecord, sourceURL: URL) -> String {
    let fileExtension = sourceURL.pathExtension.isEmpty ? "image" : sourceURL.pathExtension
    let timestamp = Int(record.lastCopiedAt.timeIntervalSince1970)
    return "LitePaste-\(timestamp).\(fileExtension)"
  }

  private func uniqueDestination(in directory: URL, filename: String) -> URL {
    let baseURL = directory.appending(path: filename)
    guard FileManager.default.fileExists(atPath: baseURL.path) else {
      return baseURL
    }

    let stem = baseURL.deletingPathExtension().lastPathComponent
    let fileExtension = baseURL.pathExtension

    for index in 2...99 {
      let candidate = directory.appending(path: "\(stem)-\(index).\(fileExtension)")
      if !FileManager.default.fileExists(atPath: candidate.path) {
        return candidate
      }
    }

    return directory.appending(path: "\(stem)-\(UUID().uuidString).\(fileExtension)")
  }
}
