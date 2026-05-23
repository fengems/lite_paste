import Foundation

public struct ClipboardTextPayloadBuilder: Sendable {
  public static let plainTextPasteboardType = "public.utf8-plain-text"
  public static let maxTitleLength = 140

  public init() {}

  public func payload(from text: String, pasteboardTypes: Set<String>) -> ClipboardPayload? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return nil
    }

    let data = Data(text.utf8)
    return ClipboardPayload(
      kind: classify(text),
      title: makeTitle(from: text),
      searchText: text,
      plainText: text,
      pasteboardTypes: pasteboardTypes,
      contents: [
        ClipboardContentSnapshot(
          pasteboardType: Self.plainTextPasteboardType,
          storageMode: .inline,
          inlineData: data,
          byteSize: data.count,
          displayOrder: 0
        )
      ]
    )
  }

  public func classify(_ text: String) -> ClipboardKind {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

    if isEmail(trimmed) {
      return .email
    }

    if isHexColor(trimmed) {
      return .color
    }

    if isURL(trimmed) {
      return .url
    }

    return .text
  }

  public func makeTitle(from text: String) -> String {
    let compact = text
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "\t", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard compact.count > Self.maxTitleLength else {
      return compact
    }

    let index = compact.index(compact.startIndex, offsetBy: Self.maxTitleLength)
    return String(compact[..<index])
  }

  private func isURL(_ text: String) -> Bool {
    guard let url = URL(string: text),
          let scheme = url.scheme?.lowercased(),
          !scheme.isEmpty else {
      return isBareWebURL(text)
    }

    return true
  }

  private func isBareWebURL(_ text: String) -> Bool {
    text.range(
      of: #"^(?:www\.)?[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?(?:\.[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?)+(?:[/:?#][^\s]*)?$"#,
      options: [.regularExpression, .caseInsensitive]
    ) != nil
  }

  private func isEmail(_ text: String) -> Bool {
    text.range(
      of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#,
      options: [.regularExpression, .caseInsensitive]
    ) != nil
  }

  private func isHexColor(_ text: String) -> Bool {
    text.range(
      of: #"^#(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$"#,
      options: .regularExpression
    ) != nil
  }
}
