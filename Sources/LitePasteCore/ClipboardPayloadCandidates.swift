import Foundation

public struct ClipboardImageCandidate: Equatable, Sendable {
  public var data: Data
  public var pasteboardType: String
  public var preferredExtension: String

  public init(data: Data, pasteboardType: String, preferredExtension: String) {
    self.data = data
    self.pasteboardType = pasteboardType
    self.preferredExtension = preferredExtension
  }
}

public struct ClipboardRichTextRepresentation: Equatable, Sendable {
  public var data: Data
  public var pasteboardType: String
  public var preferredExtension: String
  public var displayOrder: Int

  public init(
    data: Data,
    pasteboardType: String,
    preferredExtension: String,
    displayOrder: Int
  ) {
    self.data = data
    self.pasteboardType = pasteboardType
    self.preferredExtension = preferredExtension
    self.displayOrder = displayOrder
  }
}

public struct ClipboardRichTextCandidate: Equatable, Sendable {
  public var kind: ClipboardKind
  public var data: Data
  public var pasteboardType: String
  public var preferredExtension: String
  public var fallbackTitle: String
  public var representations: [ClipboardRichTextRepresentation]

  public init(
    kind: ClipboardKind,
    data: Data,
    pasteboardType: String,
    preferredExtension: String,
    fallbackTitle: String,
    representations: [ClipboardRichTextRepresentation] = []
  ) {
    self.kind = kind
    self.data = data
    self.pasteboardType = pasteboardType
    self.preferredExtension = preferredExtension
    self.fallbackTitle = fallbackTitle
    self.representations = representations
  }
}
