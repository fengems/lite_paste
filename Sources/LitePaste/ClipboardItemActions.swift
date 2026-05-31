import AppKit
import Foundation
import LitePasteCore

@MainActor
final class ClipboardItemActions {
  func primaryExternalAction(for record: ClipboardRecord) -> ClipboardExternalAction? {
    switch record.kind {
    case .url:
      return .openURL
    case .email:
      return .composeEmail
    case .files:
      return .showInFinder
    case .image:
      return .exportImage
    case .text, .richText, .html, .color, .unknown:
      return nil
    }
  }

  func perform(_ action: ClipboardExternalAction, for record: ClipboardRecord) -> ClipboardExternalActionResult {
    switch action {
    case .openURL:
      return openURL(record)
    case .composeEmail:
      return composeEmail(record)
    case .showInFinder:
      return showInFinder(record)
    case .exportImage:
      return exportImage(record)
    }
  }

  private func openURL(_ record: ClipboardRecord) -> ClipboardExternalActionResult {
    guard let value = record.plainText?.trimmingCharacters(in: .whitespacesAndNewlines),
          let url = normalizedURL(from: value) else {
      return .failed(
        title: AppText.value("无法打开链接", "Unable To Open Link"),
        message: AppText.value("这条历史记录没有可用的 URL。", "This history item does not contain a usable URL.")
      )
    }

    return NSWorkspace.shared.open(url)
      ? .completed(message: AppText.value("已打开链接", "Opened Link"))
      : .failed(
        title: AppText.value("无法打开链接", "Unable To Open Link"),
        message: AppText.value("系统无法打开：\(value)", "The system could not open: \(value)")
      )
  }

  private func normalizedURL(from value: String) -> URL? {
    guard let directURL = URL(string: value) else {
      return nil
    }

    if directURL.scheme != nil {
      return directURL
    }

    return URL(string: "https://\(value)")
  }

  private func composeEmail(_ record: ClipboardRecord) -> ClipboardExternalActionResult {
    guard let value = record.plainText?.trimmingCharacters(in: .whitespacesAndNewlines),
          let url = mailtoURL(for: value) else {
      return .failed(
        title: AppText.value("无法发送邮件", "Unable To Send Email"),
        message: AppText.value("这条历史记录没有可用的邮箱地址。", "This history item does not contain a usable email address.")
      )
    }

    return NSWorkspace.shared.open(url)
      ? .completed(message: AppText.value("已打开邮件", "Opened Mail"))
      : .failed(
        title: AppText.value("无法发送邮件", "Unable To Send Email"),
        message: AppText.value("系统无法打开默认邮件客户端。", "The system could not open the default mail client.")
      )
  }

  private func mailtoURL(for value: String) -> URL? {
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = value
    return components.url
  }

  private func showInFinder(_ record: ClipboardRecord) -> ClipboardExternalActionResult {
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

  private func exportImage(_ record: ClipboardRecord) -> ClipboardExternalActionResult {
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

  private func fileURLs(from record: ClipboardRecord) -> [URL] {
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

  private func data(from snapshot: ClipboardContentSnapshot) -> Data? {
    switch snapshot.storageMode {
    case .inline:
      snapshot.inlineData
    case .external:
      snapshot.externalFilePath.flatMap { try? Data(contentsOf: URL(fileURLWithPath: $0)) }
    }
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

enum ClipboardExternalAction {
  case openURL
  case composeEmail
  case showInFinder
  case exportImage

  var iconName: String {
    switch self {
    case .openURL:
      "safari"
    case .composeEmail:
      "envelope.open"
    case .showInFinder:
      "folder"
    case .exportImage:
      "square.and.arrow.down"
    }
  }

  var accessibilityLabel: String {
    switch self {
    case .openURL:
      AppText.value("打开链接", "Open Link")
    case .composeEmail:
      AppText.value("发送邮件", "Send Email")
    case .showInFinder:
      AppText.value("在 Finder 中显示", "Show In Finder")
    case .exportImage:
      AppText.value("导出图片", "Export Image")
    }
  }
}

enum ClipboardExternalActionResult {
  case completed(message: String)
  case failed(title: String, message: String)
}
