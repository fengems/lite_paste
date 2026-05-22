import Foundation

public struct ClipboardPayload: Equatable, Sendable {
  public var kind: ClipboardKind
  public var title: String
  public var searchText: String
  public var plainText: String?
  public var pasteboardTypes: Set<String>

  public init(
    kind: ClipboardKind,
    title: String,
    searchText: String,
    plainText: String? = nil,
    pasteboardTypes: Set<String>
  ) {
    self.kind = kind
    self.title = title
    self.searchText = searchText
    self.plainText = plainText
    self.pasteboardTypes = pasteboardTypes
  }
}

