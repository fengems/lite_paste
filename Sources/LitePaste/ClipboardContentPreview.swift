import AppKit
import LitePasteCore
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
      ClipboardPreviewImage(path: path)
    } else {
      FallbackClipboardPreview(record: record, style: style)
    }
  }
}

private struct FileClipboardPreview: View {
  let record: ClipboardRecord
  let style: ClipboardPreviewStyle

  var body: some View {
    switch style {
    case .card:
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: -6) {
          ForEach(Array(fileURLs.prefix(3).enumerated()), id: \.offset) { _, url in
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
              .resizable()
              .scaledToFit()
              .frame(width: 34, height: 34)
              .padding(4)
              .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
          }

          if fileURLs.count > 3 {
            Text("+\(fileURLs.count - 3)")
              .font(.system(size: 12, weight: .semibold))
              .frame(width: 34, height: 34)
              .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
          }
        }

        VStack(alignment: .leading, spacing: 4) {
          Text("\(fileURLs.count) 个文件")
            .font(.system(size: 15, weight: .semibold))
          Text(fileNames)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }

        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

    case .thumbnail:
      if let firstURL = fileURLs.first {
        Image(nsImage: NSWorkspace.shared.icon(forFile: firstURL.path))
          .resizable()
          .scaledToFit()
          .padding(6)
      } else {
        FallbackClipboardPreview(record: record, style: style)
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

  private var fileNames: String {
    fileURLs
      .prefix(4)
      .map(\.lastPathComponent)
      .joined(separator: ", ")
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
  let record: ClipboardRecord
  let style: ClipboardPreviewStyle

  var body: some View {
    switch style {
    case .card:
      VStack(alignment: .leading, spacing: 8) {
        Label(record.kind.displayName, systemImage: record.kind.previewIconName)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)

        Text(previewText)
          .font(.system(size: 14))
          .lineLimit(4)
          .frame(maxWidth: .infinity, alignment: .leading)

        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

    case .thumbnail:
      Image(systemName: record.kind.previewIconName)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(.secondary)
    }
  }

  private var previewText: String {
    let extracted = richTextFromSnapshots()
      ?? record.plainText
      ?? record.searchText

    let trimmed = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? record.title : trimmed
  }

  private func richTextFromSnapshots() -> String? {
    for snapshot in record.contents.sorted(by: { $0.displayOrder < $1.displayOrder }) {
      guard let data = snapshot.dataForPreview else {
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

private struct FallbackClipboardPreview: View {
  let record: ClipboardRecord
  let style: ClipboardPreviewStyle

  var body: some View {
    switch style {
    case .card:
      Text(record.title)
        .font(.system(size: 17, weight: .semibold))
        .lineLimit(5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

    case .thumbnail:
      Image(systemName: record.kind.previewIconName)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.secondary)
    }
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
