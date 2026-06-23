import AppKit
import LitePasteCore

extension ClipboardPasteboardReader {
  func readImageCandidates() -> [ClipboardImageCandidate] {
    let candidateTypes: [(NSPasteboard.PasteboardType, String)] = [
      (.png, "png"),
      (.tiff, "tiff")
    ]

    var candidates = candidateTypes.compactMap { type, fileExtension -> ClipboardImageCandidate? in
      guard let data = pasteboard.data(forType: type) else {
        return nil
      }

      return ClipboardImageCandidate(
        data: data,
        pasteboardType: type.rawValue,
        preferredExtension: fileExtension
      )
    }

    guard candidates.isEmpty,
          let image = NSImage(pasteboard: pasteboard),
          let data = image.tiffRepresentation else {
      return candidates
    }

    candidates.append(
      ClipboardImageCandidate(
        data: data,
        pasteboardType: NSPasteboard.PasteboardType.tiff.rawValue,
        preferredExtension: "tiff"
      )
    )
    return candidates
  }
}
