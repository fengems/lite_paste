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

public struct ClipboardPayloadResolver: Sendable {
  private let textPayloadBuilder: ClipboardTextPayloadBuilder
  private let filePayloadBuilder: ClipboardFilePayloadBuilder
  private let mediaPayloadBuilder: ClipboardMediaPayloadBuilder

  public init(
    textPayloadBuilder: ClipboardTextPayloadBuilder = ClipboardTextPayloadBuilder(),
    filePayloadBuilder: ClipboardFilePayloadBuilder = ClipboardFilePayloadBuilder(),
    mediaPayloadBuilder: ClipboardMediaPayloadBuilder = ClipboardMediaPayloadBuilder()
  ) {
    self.textPayloadBuilder = textPayloadBuilder
    self.filePayloadBuilder = filePayloadBuilder
    self.mediaPayloadBuilder = mediaPayloadBuilder
  }

  public func resolve(
    pasteboardTypes: Set<String>,
    fileURLs: [URL],
    imageCandidates: [ClipboardImageCandidate],
    richTextCandidates: [ClipboardRichTextCandidate],
    plainText: String?
  ) -> ClipboardPayload? {
    if let payload = filePayloadBuilder.payload(from: fileURLs, pasteboardTypes: pasteboardTypes) {
      return payload
    }

    if let imageCandidate = imageCandidates.first {
      return try? mediaPayloadBuilder.imagePayload(
        data: imageCandidate.data,
        pasteboardType: imageCandidate.pasteboardType,
        preferredExtension: imageCandidate.preferredExtension,
        pasteboardTypes: pasteboardTypes
      )
    }

    if let richTextCandidate = richTextCandidates.first {
      return try? mediaPayloadBuilder.richTextPayload(
        kind: richTextCandidate.kind,
        data: richTextCandidate.data,
        pasteboardType: richTextCandidate.pasteboardType,
        preferredExtension: richTextCandidate.preferredExtension,
        fallbackTitle: richTextCandidate.fallbackTitle,
        plainText: plainText,
        pasteboardTypes: pasteboardTypes,
        representations: richTextCandidate.representations
      )
    }

    guard let plainText else {
      return nil
    }

    return textPayloadBuilder.payload(from: plainText, pasteboardTypes: pasteboardTypes)
  }
}
