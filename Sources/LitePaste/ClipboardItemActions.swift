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
      return .failed(title: "无法打开链接", message: "这条历史记录没有可用的 URL。")
    }

    return NSWorkspace.shared.open(url)
      ? .completed
      : .failed(title: "无法打开链接", message: "系统无法打开：\(value)")
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
          let url = URL(string: "mailto:\(value)") else {
      return .failed(title: "无法发送邮件", message: "这条历史记录没有可用的邮箱地址。")
    }

    return NSWorkspace.shared.open(url)
      ? .completed
      : .failed(title: "无法发送邮件", message: "系统无法打开默认邮件客户端。")
  }

  private func showInFinder(_ record: ClipboardRecord) -> ClipboardExternalActionResult {
    let urls = fileURLs(from: record).filter { FileManager.default.fileExists(atPath: $0.path) }
    guard !urls.isEmpty else {
      return .failed(title: "无法在 Finder 中显示", message: "这些文件可能已经被移动或删除。")
    }

    NSWorkspace.shared.activateFileViewerSelecting(urls)
    return .completed
  }

  private func exportImage(_ record: ClipboardRecord) -> ClipboardExternalActionResult {
    guard let snapshot = record.contents.first(where: { $0.storageMode == .external }),
          let sourcePath = snapshot.externalFilePath else {
      return .failed(title: "无法导出图片", message: "这条历史记录没有可导出的图片文件。")
    }

    let sourceURL = URL(fileURLWithPath: sourcePath)
    guard FileManager.default.fileExists(atPath: sourceURL.path) else {
      return .failed(title: "无法导出图片", message: "图片原始数据已经不存在。")
    }

    let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    let destination = uniqueDestination(
      in: downloads,
      filename: exportFilename(for: record, sourceURL: sourceURL)
    )

    do {
      try FileManager.default.copyItem(at: sourceURL, to: destination)
      NSWorkspace.shared.activateFileViewerSelecting([destination])
      return .exportedImage(destination)
    } catch {
      return .failed(title: "导出图片失败", message: error.localizedDescription)
    }
  }

  private func fileURLs(from record: ClipboardRecord) -> [URL] {
    guard let text = record.plainText else {
      return []
    }

    return text
      .split(separator: "\n")
      .map { URL(fileURLWithPath: String($0)) }
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
      "打开链接"
    case .composeEmail:
      "发送邮件"
    case .showInFinder:
      "在 Finder 中显示"
    case .exportImage:
      "导出图片"
    }
  }
}

enum ClipboardExternalActionResult {
  case completed
  case exportedImage(URL)
  case failed(title: String, message: String)
}
