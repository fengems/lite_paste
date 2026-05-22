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

  func perform(_ action: ClipboardExternalAction, for record: ClipboardRecord) {
    switch action {
    case .openURL:
      openURL(record)
    case .composeEmail:
      composeEmail(record)
    case .showInFinder:
      showInFinder(record)
    case .exportImage:
      exportImage(record)
    }
  }

  private func openURL(_ record: ClipboardRecord) {
    guard let value = record.plainText?.trimmingCharacters(in: .whitespacesAndNewlines),
          let url = URL(string: value) else {
      return
    }

    NSWorkspace.shared.open(url)
  }

  private func composeEmail(_ record: ClipboardRecord) {
    guard let value = record.plainText?.trimmingCharacters(in: .whitespacesAndNewlines),
          let url = URL(string: "mailto:\(value)") else {
      return
    }

    NSWorkspace.shared.open(url)
  }

  private func showInFinder(_ record: ClipboardRecord) {
    let urls = fileURLs(from: record)
    guard !urls.isEmpty else {
      return
    }

    NSWorkspace.shared.activateFileViewerSelecting(urls)
  }

  private func exportImage(_ record: ClipboardRecord) {
    guard let snapshot = record.contents.first(where: { $0.storageMode == .external }),
          let sourcePath = snapshot.externalFilePath else {
      return
    }

    let sourceURL = URL(fileURLWithPath: sourcePath)
    let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    let destination = uniqueDestination(
      in: downloads,
      filename: exportFilename(for: record, sourceURL: sourceURL)
    )

    do {
      try FileManager.default.copyItem(at: sourceURL, to: destination)
      NSWorkspace.shared.activateFileViewerSelecting([destination])
    } catch {
      print("Unable to export image: \(error)")
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
