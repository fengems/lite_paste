import AppKit
import Foundation
import LitePasteCore

private struct ResolvedClipboardPayload {
  var payload: ClipboardPayload
  var imageOCRData: Data?
}

@MainActor
final class ClipboardMonitor {
  // Large Excel ranges can expose multi-megabyte HTML/RTF payloads; plain text remains the default.
  private static let richTextCaptureByteLimit = 512 * 1024

  private let pasteboard: NSPasteboard
  private let store: HistoryStore
  private let writeTracker: ClipboardWriteTracker
  private let payloadResolver: ClipboardPayloadResolver
  private let imageOCRService: ImageOCRService
  private var captureGate: ClipboardCaptureGate
  private var preserveLargeRichTextFormats: Bool
  private var copySoundEnabled: Bool
  private var imageOCREnabled: Bool
  private var imageOCRTasks: [ClipboardRecord.ID: Task<Void, Never>] = [:]
  private var timer: Timer?
  private var lastChangeCount: Int

  init(
    pasteboard: NSPasteboard = .general,
    store: HistoryStore,
    blobStorage: any BlobStorage = LocalBlobStorage(),
    writeTracker: ClipboardWriteTracker,
    payloadResolver: ClipboardPayloadResolver? = nil,
    privacyFilter: PrivacyFilter = PrivacyFilter(),
    preserveLargeRichTextFormats: Bool = false,
    copySoundEnabled: Bool = false,
    imageOCREnabled: Bool = false,
    imageOCRService: ImageOCRService = ImageOCRService()
  ) {
    self.pasteboard = pasteboard
    self.store = store
    self.writeTracker = writeTracker
    self.imageOCRService = imageOCRService
    self.payloadResolver = payloadResolver ?? ClipboardPayloadResolver(
      mediaPayloadBuilder: ClipboardMediaPayloadBuilder(blobStorage: blobStorage)
    )
    self.captureGate = ClipboardCaptureGate(privacyFilter: privacyFilter)
    self.preserveLargeRichTextFormats = preserveLargeRichTextFormats
    self.copySoundEnabled = copySoundEnabled
    self.imageOCREnabled = imageOCREnabled
    self.lastChangeCount = pasteboard.changeCount
  }

  func start() {
    guard timer == nil else {
      return
    }
    lastChangeCount = pasteboard.changeCount
    timer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.captureIfNeeded()
      }
    }
  }

  func stop() {
    timer?.invalidate()
    timer = nil
    cancelImageOCRTasks()
  }

  func updatePrivacyFilter(_ privacyFilter: PrivacyFilter) {
    captureGate.privacyFilter = privacyFilter
  }

  func updatePreserveLargeRichTextFormats(_ enabled: Bool) {
    preserveLargeRichTextFormats = enabled
  }

  func updateCopySoundEnabled(_ enabled: Bool) {
    copySoundEnabled = enabled
  }

  func updateImageOCREnabled(_ enabled: Bool) {
    imageOCREnabled = enabled
    if !enabled {
      cancelImageOCRTasks()
    }
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

    guard captureGate.privacyFilter.shouldRecord() else {
      return
    }

    let types = readPasteboardTypes()
    let sourceApp = NSWorkspace.shared.frontmostApplication
    let bundleId = sourceApp?.bundleIdentifier

    guard let resolvedPayload = readPayload(pasteboardTypes: types, sourceAppBundleId: bundleId) else {
      return
    }
    let payload = resolvedPayload.payload

    guard captureGate.shouldRecord(payload: payload) else {
      return
    }

    let record = store.ingest(
      payload,
      sourceAppBundleId: bundleId,
      sourceAppName: sourceApp?.localizedName
    )
    playCopySoundIfNeeded(for: record)
    scheduleImageOCRIfNeeded(record: record, imageData: resolvedPayload.imageOCRData)
  }

  private func playCopySoundIfNeeded(for record: ClipboardRecord) {
    guard copySoundEnabled, record.copyCount == 1 else {
      return
    }

    NSSound(named: "Tink")?.play()
  }

  private func readPasteboardTypes() -> Set<String> {
    Set(pasteboard.types?.map(\.rawValue) ?? [])
  }

  private func readPayload(pasteboardTypes types: Set<String>, sourceAppBundleId: String?) -> ResolvedClipboardPayload? {
    let fileURLs = readFileURLs()
    let plainText = pasteboard.string(forType: .string)
    let richTextCandidates = readRichTextCandidates(
      pasteboardTypes: types,
      sourceAppBundleId: sourceAppBundleId
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

  private func scheduleImageOCRIfNeeded(record: ClipboardRecord, imageData: Data?) {
    guard imageOCREnabled, record.kind == .image, record.copyCount == 1, let imageData else {
      return
    }

    guard imageOCRTasks.isEmpty else {
      return
    }

    let recordID = record.id
    imageOCRTasks[recordID] = Task { [weak self] in
      guard let self else {
        return
      }

      let recognizedText = await imageOCRService.recognizeText(in: imageData)
      guard !Task.isCancelled else {
        return
      }

      if let recognizedText {
        store.updateOCRText(recordID, text: recognizedText)
      }
      imageOCRTasks[recordID] = nil
    }
  }

  private func cancelImageOCRTasks() {
    imageOCRTasks.values.forEach { $0.cancel() }
    imageOCRTasks.removeAll()
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
