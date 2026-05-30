import AppKit
import Foundation
import LitePasteCore

@MainActor
final class ClipboardMonitor {
  // Large Excel ranges can expose multi-megabyte HTML/RTF payloads; plain text remains the default.
  private static let richTextCaptureByteLimit = 512 * 1024

  private let pasteboard: NSPasteboard
  private let store: HistoryStore
  private let writeTracker: ClipboardWriteTracker
  private let payloadResolver: ClipboardPayloadResolver
  private var captureGate: ClipboardCaptureGate
  private var preserveLargeRichTextFormats: Bool
  private var timer: Timer?
  private var lastChangeCount: Int

  init(
    pasteboard: NSPasteboard = .general,
    store: HistoryStore,
    blobStorage: any BlobStorage = LocalBlobStorage(),
    writeTracker: ClipboardWriteTracker,
    payloadResolver: ClipboardPayloadResolver? = nil,
    privacyFilter: PrivacyFilter = PrivacyFilter(),
    enabledTypes: Set<ClipboardKind> = Set(ClipboardKind.allCases),
    preserveLargeRichTextFormats: Bool = false
  ) {
    self.pasteboard = pasteboard
    self.store = store
    self.writeTracker = writeTracker
    self.payloadResolver = payloadResolver ?? ClipboardPayloadResolver(
      mediaPayloadBuilder: ClipboardMediaPayloadBuilder(blobStorage: blobStorage)
    )
    self.captureGate = ClipboardCaptureGate(
      enabledTypes: enabledTypes,
      privacyFilter: privacyFilter
    )
    self.preserveLargeRichTextFormats = preserveLargeRichTextFormats
    self.lastChangeCount = pasteboard.changeCount
  }

  func start() {
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.captureIfNeeded()
      }
    }
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }

  func updatePrivacyFilter(_ privacyFilter: PrivacyFilter) {
    captureGate.privacyFilter = privacyFilter
  }

  func updateEnabledTypes(_ enabledTypes: Set<ClipboardKind>) {
    captureGate.enabledTypes = enabledTypes
  }

  func updatePreserveLargeRichTextFormats(_ enabled: Bool) {
    preserveLargeRichTextFormats = enabled
  }

  private func captureIfNeeded() {
    let changeCount = pasteboard.changeCount
    guard changeCount != lastChangeCount else {
      return
    }

    lastChangeCount = changeCount

    guard !writeTracker.shouldIgnore(changeCount: changeCount) else {
      return
    }

    let types = readPasteboardTypes()
    let sourceApp = NSWorkspace.shared.frontmostApplication
    let bundleId = sourceApp?.bundleIdentifier

    guard captureGate.privacyFilter.shouldRecord(sourceAppBundleId: bundleId, pasteboardTypes: types) else {
      return
    }

    guard let payload = readPayload(pasteboardTypes: types, sourceAppBundleId: bundleId) else {
      return
    }

    guard captureGate.shouldRecord(payload: payload, sourceAppBundleId: bundleId) else {
      return
    }

    store.ingest(
      payload,
      sourceAppBundleId: bundleId,
      sourceAppName: sourceApp?.localizedName
    )
  }

  private func readPasteboardTypes() -> Set<String> {
    Set(pasteboard.types?.map(\.rawValue) ?? [])
  }

  private func readPayload(pasteboardTypes types: Set<String>, sourceAppBundleId: String?) -> ClipboardPayload? {
    let fileURLs = readFileURLs()
    let imageCandidates = readImageCandidates()
    let richTextCandidates = readRichTextCandidates(
      pasteboardTypes: types,
      sourceAppBundleId: sourceAppBundleId
    )
    let plainText = pasteboard.string(forType: .string)

    return payloadResolver.resolve(
      pasteboardTypes: types,
      fileURLs: fileURLs,
      imageCandidates: imageCandidates,
      richTextCandidates: richTextCandidates,
      plainText: plainText
    )
  }

  private func readFileURLs() -> [URL] {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [
      .urlReadingFileURLsOnly: true
    ]
    let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options)
    let urls = (objects as? [URL]) ?? (objects as? [NSURL])?.map { $0 as URL } ?? []
    return urls.filter { $0.isFileURL }
  }

  private func readImageCandidates() -> [ClipboardImageCandidate] {
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

  private func readRichTextCandidates(
    pasteboardTypes: Set<String>,
    sourceAppBundleId: String?
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
        sourceAppBundleId: sourceAppBundleId
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
    sourceAppBundleId: String?
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
