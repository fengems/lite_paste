import LitePasteCore

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
