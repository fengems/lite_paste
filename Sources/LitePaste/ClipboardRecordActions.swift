import LitePasteCore

@MainActor
final class ClipboardRecordActions {
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
}
