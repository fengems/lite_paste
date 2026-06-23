import AppKit
import LitePasteCore
import SwiftUI

private let clipboardPreviewTextLimit = 1_600

struct RichClipboardPreview: View {
  // Parsing huge HTML snippets blocks SwiftUI rendering; fall back to plain text previews.
  private static let richPreviewParseByteLimit = 256 * 1024

  let record: ClipboardRecord
  let style: ClipboardPreviewStyle

  var body: some View {
    switch style {
    case .card:
      Text(previewText)
        .font(.system(size: 14))
        .foregroundStyle(.primary)
        .lineLimit(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

    case .thumbnail:
      Image(systemName: record.kind.previewIconName)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(.secondary)
    }
  }

  private var previewText: String {
    if let plainText = clippedClipboardPreviewText(record.plainText) {
      return plainText
    }

    if let richText = clippedClipboardPreviewText(richTextFromSnapshots()) {
      return richText
    }

    if let searchText = clippedClipboardPreviewText(record.searchText) {
      return searchText
    }

    return record.title
  }

  private func richTextFromSnapshots() -> String? {
    for snapshot in record.contents.sorted(by: { $0.displayOrder < $1.displayOrder }) {
      guard let data = snapshot.dataForPreview else {
        continue
      }
      guard data.count <= Self.richPreviewParseByteLimit else {
        continue
      }

      if snapshot.pasteboardType == NSPasteboard.PasteboardType.rtf.rawValue,
         let attributed = try? NSAttributedString(
          data: data,
          options: [.documentType: NSAttributedString.DocumentType.rtf],
          documentAttributes: nil
         ) {
        return attributed.string
      }

      if snapshot.pasteboardType == NSPasteboard.PasteboardType.html.rawValue,
         let attributed = try? NSAttributedString(
          data: data,
          options: [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
          ],
          documentAttributes: nil
         ) {
        return attributed.string
      }
    }

    return nil
  }
}

struct FallbackClipboardPreview: View {
  let record: ClipboardRecord
  let style: ClipboardPreviewStyle

  var body: some View {
    switch style {
    case .card:
      Text(previewText)
        .font(.system(size: 14))
        .lineLimit(7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

    case .thumbnail:
      Image(systemName: record.kind.previewIconName)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.secondary)
    }
  }

  private var previewText: String {
    clippedClipboardPreviewText(record.plainText)
      ?? clippedClipboardPreviewText(record.title)
      ?? record.title
  }
}

private func clippedClipboardPreviewText(_ text: String?) -> String? {
  guard let text else {
    return nil
  }

  let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmed.isEmpty else {
    return nil
  }

  guard let endIndex = trimmed.index(
    trimmed.startIndex,
    offsetBy: clipboardPreviewTextLimit,
    limitedBy: trimmed.endIndex
  ) else {
    return trimmed
  }

  return endIndex == trimmed.endIndex ? trimmed : String(trimmed[..<endIndex]) + "..."
}

private extension ClipboardContentSnapshot {
  var dataForPreview: Data? {
    if let inlineData {
      return inlineData
    }

    guard let externalFilePath else {
      return nil
    }

    return try? Data(contentsOf: URL(fileURLWithPath: externalFilePath))
  }
}
