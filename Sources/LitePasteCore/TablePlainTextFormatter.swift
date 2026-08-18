import Foundation

public enum TablePlainTextWrapper: String, Codable, CaseIterable, Sendable {
  case none
  case doubleQuote
  case singleQuote
  case chineseQuote
  case squareBracket
  case curlyBrace

  public func wrap(_ field: String) -> String {
    switch self {
    case .none:
      return field
    case .doubleQuote:
      return "\"\(escaping(field, boundary: "\""))\""
    case .singleQuote:
      return "'\(escaping(field, boundary: "'"))'"
    case .chineseQuote:
      return "“\(escaping(field, boundary: "”"))”"
    case .squareBracket:
      return "[\(escaping(field, boundary: "]"))]"
    case .curlyBrace:
      return "{\(escaping(field, boundary: "}"))}"
    }
  }

  private func escaping(_ field: String, boundary: String) -> String {
    field.replacingOccurrences(of: boundary, with: String(repeating: boundary, count: 2))
  }
}

public struct TablePlainTextFormatter: Sendable, Equatable {
  public var isEnabled: Bool
  public var separator: String
  public var wrapper: TablePlainTextWrapper

  public init(
    isEnabled: Bool = false,
    separator: String = "、",
    wrapper: TablePlainTextWrapper = .none
  ) {
    self.isEnabled = isEnabled
    self.separator = Self.normalizedSeparator(separator)
    self.wrapper = wrapper
  }

  public func formatIfTable(_ text: String) -> String {
    guard isEnabled, ClipboardPayloadResolver.isTabularPlainText(text) else {
      return text
    }

    let rows = text
      .split(whereSeparator: \.isNewline)
      .compactMap { formattedRow(String($0)) }

    guard !rows.isEmpty else {
      return text
    }

    return rows.joined(separator: "\n")
  }

  public static func normalizedSeparator(_ separator: String) -> String {
    guard !separator.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !separator.contains(where: \.isNewline) else {
      return "、"
    }

    return separator
  }

  private func formattedRow(_ row: String) -> String? {
    let fields = row
      .split(separator: "\t", omittingEmptySubsequences: false)
      .map { trimmedField(String($0)) }
      .filter { !$0.isEmpty }

    guard !fields.isEmpty else {
      return nil
    }

    return fields.map(wrapper.wrap).joined(separator: separator)
  }

  private func trimmedField(_ field: String) -> String {
    field.trimmingCharacters(in: Self.fieldEdges)
  }

  private static let fieldEdges: CharacterSet = {
    var characters = CharacterSet.whitespacesAndNewlines
    [
      "\u{00A0}",
      "\u{2007}",
      "\u{202F}",
      "\u{200B}",
      "\u{FEFF}",
      "\u{FFFC}"
    ].forEach { characters.insert($0) }
    return characters
  }()
}
