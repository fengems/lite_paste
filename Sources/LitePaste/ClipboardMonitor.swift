import AppKit
import Foundation
import LitePasteCore

@MainActor
final class ClipboardMonitor {
  private let pasteboard: NSPasteboard
  private let store: HistoryStore
  private let writeTracker: ClipboardWriteTracker
  private let payloadResolver: ClipboardPayloadResolver
  private var captureGate: ClipboardCaptureGate
  private var timer: Timer?
  private var lastChangeCount: Int

  init(
    pasteboard: NSPasteboard = .general,
    store: HistoryStore,
    blobStorage: any BlobStorage = LocalBlobStorage(),
    writeTracker: ClipboardWriteTracker,
    payloadResolver: ClipboardPayloadResolver? = nil,
    privacyFilter: PrivacyFilter = PrivacyFilter(),
    enabledTypes: Set<ClipboardKind> = Set(ClipboardKind.allCases)
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

  private func captureIfNeeded() {
    let changeCount = pasteboard.changeCount
    guard changeCount != lastChangeCount else {
      return
    }

    lastChangeCount = changeCount

    guard !writeTracker.shouldIgnore(changeCount: changeCount) else {
      return
    }

    guard let payload = readPayload() else {
      return
    }

    let sourceApp = NSWorkspace.shared.frontmostApplication
    let bundleId = sourceApp?.bundleIdentifier

    guard captureGate.shouldRecord(payload: payload, sourceAppBundleId: bundleId) else {
      return
    }

    store.ingest(
      payload,
      sourceAppBundleId: bundleId,
      sourceAppName: sourceApp?.localizedName
    )
  }

  private func readPayload() -> ClipboardPayload? {
    let types = Set(pasteboard.types?.map(\.rawValue) ?? [])
    let fileURLs = readFileURLs()
    let imageCandidates = readImageCandidates()
    let richTextCandidates = readRichTextCandidates()
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

  private func readRichTextCandidates() -> [ClipboardRichTextCandidate] {
    let candidateTypes: [(NSPasteboard.PasteboardType, ClipboardKind, String, String)] = [
      (.html, .html, "html", "HTML"),
      (.rtf, .richText, "rtf", "富文本")
    ]

    return candidateTypes.compactMap { type, kind, fileExtension, fallbackTitle in
      guard let data = pasteboard.data(forType: type) else {
        return nil
      }

      return ClipboardRichTextCandidate(
        kind: kind,
        data: data,
        pasteboardType: type.rawValue,
        preferredExtension: fileExtension,
        fallbackTitle: fallbackTitle
      )
    }
  }
}
