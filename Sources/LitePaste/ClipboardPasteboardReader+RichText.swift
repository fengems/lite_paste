import AppKit
import Foundation
import LitePasteCore

extension ClipboardPasteboardReader {
  func readRichTextCandidates(
    pasteboardTypes: Set<String>,
    sourceAppBundleId: String?,
    preserveLargeRichTextFormats: Bool
  ) -> [ClipboardRichTextCandidate] {
    let candidateTypes: [(NSPasteboard.PasteboardType, ClipboardKind, String, String)] = [
      (.html, .html, "html", "HTML"),
      (.rtf, .richText, "rtf", "富文本")
    ]

    for (type, kind, fileExtension, fallbackTitle) in candidateTypes {
      guard let data = pasteboard.data(forType: type) else {
        continue
      }
      let shouldPreserveOriginalFormats = shouldPreserveOriginalFormats(
        dataSize: data.count,
        pasteboardTypes: pasteboardTypes,
        sourceAppBundleId: sourceAppBundleId,
        preserveLargeRichTextFormats: preserveLargeRichTextFormats
      )
      guard data.count <= Self.richTextCaptureByteLimit || shouldPreserveOriginalFormats else {
        continue
      }

      return [
        ClipboardRichTextCandidate(
          kind: kind,
          data: data,
          pasteboardType: type.rawValue,
          preferredExtension: fileExtension,
          fallbackTitle: fallbackTitle,
          representations: shouldPreserveOriginalFormats
            ? readOriginalFormatRepresentations(primaryType: type, primaryData: data)
            : []
        )
      ]
    }

    return []
  }

  private func shouldPreserveOriginalFormats(
    dataSize: Int,
    pasteboardTypes: Set<String>,
    sourceAppBundleId: String?,
    preserveLargeRichTextFormats: Bool
  ) -> Bool {
    guard preserveLargeRichTextFormats else {
      return false
    }

    if dataSize > Self.richTextCaptureByteLimit {
      return true
    }

    return isExcelPasteboard(pasteboardTypes: pasteboardTypes, sourceAppBundleId: sourceAppBundleId)
  }

  private func isExcelPasteboard(pasteboardTypes: Set<String>, sourceAppBundleId: String?) -> Bool {
    if sourceAppBundleId?.range(of: "microsoft.excel", options: .caseInsensitive) != nil {
      return true
    }

    return pasteboardTypes.contains { type in
      let lowercasedType = type.lowercased()
      return lowercasedType.contains("microsoft") && lowercasedType.contains("excel")
    }
  }

  private func readOriginalFormatRepresentations(
    primaryType: NSPasteboard.PasteboardType,
    primaryData: Data
  ) -> [ClipboardRichTextRepresentation] {
    var seenTypes = Set<String>()
    var representations: [ClipboardRichTextRepresentation] = []

    for item in pasteboard.pasteboardItems ?? [] {
      for type in item.types where !seenTypes.contains(type.rawValue) {
        guard let data = item.data(forType: type) else {
          continue
        }

        seenTypes.insert(type.rawValue)
        representations.append(
          ClipboardRichTextRepresentation(
            data: data,
            pasteboardType: type.rawValue,
            preferredExtension: preferredExtension(for: type),
            displayOrder: representations.count
          )
        )
      }
    }

    if !seenTypes.contains(primaryType.rawValue) {
      representations.insert(primaryRepresentation(type: primaryType, data: primaryData), at: 0)
    }
    return representations.enumerated().map { offset, representation in
      var orderedRepresentation = representation
      orderedRepresentation.displayOrder = offset
      return orderedRepresentation
    }
  }

  private func primaryRepresentation(
    type: NSPasteboard.PasteboardType,
    data: Data
  ) -> ClipboardRichTextRepresentation {
    ClipboardRichTextRepresentation(
      data: data,
      pasteboardType: type.rawValue,
      preferredExtension: preferredExtension(for: type),
      displayOrder: 0
    )
  }

  private func preferredExtension(for type: NSPasteboard.PasteboardType) -> String {
    switch type {
    case .html:
      "html"
    case .rtf:
      "rtf"
    case .string:
      "txt"
    case .png:
      "png"
    case .tiff:
      "tiff"
    case .pdf:
      "pdf"
    default:
      "pbdata"
    }
  }
}
