import Foundation

enum ClipboardSearchText {
  static let maxLength = 64 * 1024

  static func limited(_ text: String) -> String {
    guard let endIndex = text.index(
      text.startIndex,
      offsetBy: maxLength,
      limitedBy: text.endIndex
    ) else {
      return String(text.prefix(maxLength))
    }

    return endIndex == text.endIndex ? text : String(text[..<endIndex])
  }

  static func normalizedFragment(_ text: String) -> String {
    let compact = text
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return limited(compact)
  }

  static func appendingFragment(_ fragment: String, to searchText: String) -> String {
    limited([searchText, fragment].joined(separator: " "))
  }
}
