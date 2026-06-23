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
      ClipboardPreviewImage(path: path, style: style)
    } else {
      FallbackClipboardPreview(record: record, style: style)
    }
  }
}
