import AppKit
import LitePasteCore
import QuickLookThumbnailing
import SwiftUI

enum ClipboardPreviewStyle {
  case card
  case thumbnail
}

struct ClipboardContentPreview: View {
  let record: ClipboardRecord
  let style: ClipboardPreviewStyle

  var body: some View {
    switch record.kind {
    case .image:
      imagePreview
    case .files:
      FileClipboardPreview(record: record, style: style)
    case .color:
      ColorClipboardPreview(record: record, style: style)
    case .richText, .html:
      RichClipboardPreview(record: record, style: style)
    case .url, .email, .text, .unknown:
      FallbackClipboardPreview(record: record, style: style)
    }
  }

  @ViewBuilder
  private var imagePreview: some View {
    if let path = record.previewFilePath {
      ClipboardPreviewImage(path: path, style: style)
    } else {
      FallbackClipboardPreview(record: record, style: style)
    }
  }
}

private struct FileClipboardPreview: View {
  let record: ClipboardRecord
  let style: ClipboardPreviewStyle

  var body: some View {
    let items = fileItems

    switch style {
    case .card:
      fileGrid(for: items)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

    case .thumbnail:
      if let firstItem = items.first {
        fileIcon(for: firstItem, size: 34)
          .padding(2)
      } else {
        FallbackClipboardPreview(record: record, style: style)
      }
    }
  }

  private func fileIcon(for item: FilePreviewItem, size: CGFloat) -> some View {
    FileThumbnailPreview(item: item, size: size)
      .opacity(item.exists ? 1 : 0.46)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
      .overlay(alignment: .bottomTrailing) {
        if !item.exists {
          Image(systemName: "exclamationmark.circle.fill")
            .font(.system(size: 11, weight: .bold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .orange)
            .padding(1)
        }
      }
  }

  private func fileGrid(for items: [FilePreviewItem]) -> some View {
    let visibleItems = items.count > 4 ? Array(items.prefix(3)) : Array(items.prefix(4))

    return LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2),
      alignment: .leading,
      spacing: 6
    ) {
      ForEach(visibleItems, id: \.url) { item in
        fileIcon(for: item, size: 50)
      }

      if items.count > visibleItems.count {
        Text("+\(items.count - visibleItems.count)")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.secondary)
          .frame(width: 50, height: 50)
          .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
      }
    }
  }

  private var fileURLs: [URL] {
    record.contents
      .sorted { $0.displayOrder < $1.displayOrder }
      .compactMap { snapshot -> URL? in
        guard let data = snapshot.inlineData,
              let path = String(data: data, encoding: .utf8),
              !path.isEmpty else {
          return nil
        }
        return URL(fileURLWithPath: path)
      }
  }

  private var fileItems: [FilePreviewItem] {
    fileURLs.map(FilePreviewItem.init(url:))
  }

}

private struct FilePreviewItem {
  let url: URL
  let exists: Bool
  let isDirectory: Bool

  init(url: URL) {
    self.url = url
    var isDirectoryValue: ObjCBool = false
    exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectoryValue)
    isDirectory = isDirectoryValue.boolValue
  }
}

private struct FileThumbnailPreview: View {
  let item: FilePreviewItem
  let size: CGFloat
  @State private var thumbnail: NSImage?

  var body: some View {
    ZStack {
      if let thumbnail {
        Image(nsImage: thumbnail)
          .resizable()
          .scaledToFill()
      } else {
        Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
          .resizable()
          .scaledToFit()
          .padding(size * 0.14)
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(alignment: .bottomLeading) {
      if item.isDirectory {
        Image(systemName: "folder.fill")
          .font(.system(size: max(9, size * 0.24), weight: .semibold))
          .foregroundStyle(.blue)
          .padding(3)
      }
    }
    .task(id: item.url.path) {
      thumbnail = await loadThumbnail(for: item.url, size: size)
    }
  }

  private func loadThumbnail(for url: URL, size: CGFloat) async -> NSImage? {
    guard item.exists else {
      return nil
    }

    let request = QLThumbnailGenerator.Request(
      fileAt: url,
      size: CGSize(width: size * 2, height: size * 2),
      scale: NSScreen.main?.backingScaleFactor ?? 2,
      representationTypes: [.thumbnail, .icon]
    )

    return await withCheckedContinuation { continuation in
      QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
        continuation.resume(returning: representation?.nsImage)
      }
    }
  }
}

private struct ColorClipboardPreview: View {
  let record: ClipboardRecord
  let style: ClipboardPreviewStyle

  var body: some View {
    let parsedColor = ParsedHexColor(text: record.plainText ?? record.title)

    switch style {
    case .card:
      VStack(alignment: .leading, spacing: 10) {
        RoundedRectangle(cornerRadius: 10)
          .fill(parsedColor?.color ?? Color.secondary.opacity(0.18))
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(.white.opacity(0.18), lineWidth: 1)
          )
          .frame(height: 58)

        Text(parsedColor?.normalizedText ?? record.title)
          .font(.system(size: 16, weight: .semibold))
          .textSelection(.enabled)

        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

    case .thumbnail:
      RoundedRectangle(cornerRadius: 8)
        .fill(parsedColor?.color ?? Color.secondary.opacity(0.18))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .padding(3)
    }
  }
}

private struct RichClipboardPreview: View {
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
    if let plainText = normalizedPreviewText(record.plainText) {
      return plainText
    }

    if let richText = normalizedPreviewText(richTextFromSnapshots()) {
      return richText
    }

    if let searchText = normalizedPreviewText(record.searchText) {
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

  private func normalizedPreviewText(_ text: String?) -> String? {
    guard let text else {
      return nil
    }

    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}

private struct FallbackClipboardPreview: View {
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
    let trimmed = (record.plainText ?? record.title).trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? record.title : trimmed
  }
}

private struct ParsedHexColor {
  let normalizedText: String
  let color: Color

  init?(text: String) {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let hex = value.hasPrefix("#") ? String(value.dropFirst()) : value

    guard [3, 6, 8].contains(hex.count),
          let number = UInt64(hex, radix: 16) else {
      return nil
    }

    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    if hex.count == 3 {
      red = Double((number >> 8) & 0xF) / 15
      green = Double((number >> 4) & 0xF) / 15
      blue = Double(number & 0xF) / 15
      alpha = 1
    } else if hex.count == 6 {
      red = Double((number >> 16) & 0xFF) / 255
      green = Double((number >> 8) & 0xFF) / 255
      blue = Double(number & 0xFF) / 255
      alpha = 1
    } else {
      red = Double((number >> 24) & 0xFF) / 255
      green = Double((number >> 16) & 0xFF) / 255
      blue = Double((number >> 8) & 0xFF) / 255
      alpha = Double(number & 0xFF) / 255
    }

    normalizedText = "#\(hex.uppercased())"
    color = Color(red: red, green: green, blue: blue, opacity: alpha)
  }
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

extension ClipboardKind {
  var previewIconName: String {
    switch self {
    case .text:
      "text.alignleft"
    case .richText, .html:
      "doc.richtext"
    case .image:
      "photo"
    case .files:
      "folder"
    case .url:
      "link"
    case .email:
      "envelope"
    case .color:
      "paintpalette"
    case .unknown:
      "questionmark.square"
    }
  }
}
