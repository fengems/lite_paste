import Foundation

public struct ClipboardPayload: Equatable, Sendable {
  public var kind: ClipboardKind
  public var title: String
  public var searchText: String
  public var plainText: String?
  public var contentHashBasis: String
  public var pasteboardTypes: Set<String>
  public var contents: [ClipboardContentSnapshot]
  public var previewFilePath: String?

  public init(
    kind: ClipboardKind,
    title: String,
    searchText: String,
    plainText: String? = nil,
    contentHashBasis: String? = nil,
    pasteboardTypes: Set<String>,
    contents: [ClipboardContentSnapshot] = [],
    previewFilePath: String? = nil
  ) {
    self.kind = kind
    self.title = title
    self.searchText = searchText
    self.plainText = plainText
    self.contentHashBasis = contentHashBasis ?? plainText ?? searchText
    self.pasteboardTypes = pasteboardTypes
    self.contents = contents
    self.previewFilePath = previewFilePath
  }
}
