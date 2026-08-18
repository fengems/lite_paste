import Foundation

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

    if Self.isTabularPlainText(plainText), !imageCandidates.isEmpty {
      if let richTextPayload = richTextPayload(
        from: richTextCandidates.first,
        plainText: plainText,
        pasteboardTypes: pasteboardTypes
      ) {
        return richTextPayload
      }

      if let plainTextPayload = plainText.flatMap({
        textPayloadBuilder.payload(from: $0, pasteboardTypes: pasteboardTypes)
      }) {
        return plainTextPayload
      }
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
      return richTextPayload(
        from: richTextCandidate,
        plainText: plainText,
        pasteboardTypes: pasteboardTypes
      )
    }

    guard let plainText else {
      return nil
    }

    return textPayloadBuilder.payload(from: plainText, pasteboardTypes: pasteboardTypes)
  }

  public static func isTabularPlainText(_ text: String?) -> Bool {
    guard let text else {
      return false
    }

    return text
      .split(whereSeparator: \.isNewline)
      .prefix(16)
      .contains { $0.contains("\t") }
  }

  private func richTextPayload(
    from candidate: ClipboardRichTextCandidate?,
    plainText: String?,
    pasteboardTypes: Set<String>
  ) -> ClipboardPayload? {
    guard let candidate else {
      return nil
    }

    return try? mediaPayloadBuilder.richTextPayload(
      kind: candidate.kind,
      data: candidate.data,
      pasteboardType: candidate.pasteboardType,
      preferredExtension: candidate.preferredExtension,
      fallbackTitle: candidate.fallbackTitle,
      plainText: plainText,
      pasteboardTypes: pasteboardTypes,
      representations: candidate.representations
    )
  }
}
