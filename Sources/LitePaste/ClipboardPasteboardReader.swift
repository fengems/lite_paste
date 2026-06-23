import AppKit
import Foundation
import LitePasteCore

struct ResolvedClipboardPayload {
  var payload: ClipboardPayload
  var imageOCRData: Data?
}

struct ClipboardPasteboardReader {
  // Large Excel ranges can expose multi-megabyte HTML/RTF payloads; plain text remains the default.
  static let richTextCaptureByteLimit = 512 * 1024

  let pasteboard: NSPasteboard
  private let payloadResolver: ClipboardPayloadResolver

  init(pasteboard: NSPasteboard, payloadResolver: ClipboardPayloadResolver) {
    self.pasteboard = pasteboard
    self.payloadResolver = payloadResolver
  }

  func readTypes() -> Set<String> {
    Set(pasteboard.types?.map(\.rawValue) ?? [])
  }

  func readPayload(
    pasteboardTypes types: Set<String>,
    sourceAppBundleId: String?,
    preserveLargeRichTextFormats: Bool,
    imageOCREnabled: Bool
  ) -> ResolvedClipboardPayload? {
    let fileURLs = readFileURLs()
    let plainText = pasteboard.string(forType: .string)
    let richTextCandidates = readRichTextCandidates(
      pasteboardTypes: types,
      sourceAppBundleId: sourceAppBundleId,
      preserveLargeRichTextFormats: preserveLargeRichTextFormats
    )
    let imageCandidates = ClipboardPayloadResolver.isTabularPlainText(plainText)
      ? []
      : readImageCandidates()

    guard let payload = payloadResolver.resolve(
      pasteboardTypes: types,
      fileURLs: fileURLs,
      imageCandidates: imageCandidates,
      richTextCandidates: richTextCandidates,
      plainText: plainText
    ) else {
      return nil
    }

    let shouldRunImageOCR = imageOCREnabled &&
      payload.kind == .image &&
      !ClipboardOCRPolicy.shouldSkipImageOCR(
        pasteboardTypes: types,
        sourceAppBundleId: sourceAppBundleId,
        plainText: plainText
      )

    return ResolvedClipboardPayload(
      payload: payload,
      imageOCRData: shouldRunImageOCR ? imageCandidates.first?.data : nil
    )
  }
}
