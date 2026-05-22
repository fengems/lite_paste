import AppKit
import Foundation
import LitePasteCore

@MainActor
final class ClipboardMonitor {
  private let pasteboard: NSPasteboard
  private let store: HistoryStore
  private let blobStorage: any BlobStorage
  private let writeTracker: ClipboardWriteTracker
  private let textPayloadBuilder: ClipboardTextPayloadBuilder
  private let filePayloadBuilder: ClipboardFilePayloadBuilder
  private let mediaPayloadBuilder: ClipboardMediaPayloadBuilder
  private var privacyFilter: PrivacyFilter
  private var enabledTypes: Set<ClipboardKind>
  private var timer: Timer?
  private var lastChangeCount: Int

  init(
    pasteboard: NSPasteboard = .general,
    store: HistoryStore,
    blobStorage: any BlobStorage = LocalBlobStorage(),
    writeTracker: ClipboardWriteTracker,
    textPayloadBuilder: ClipboardTextPayloadBuilder = ClipboardTextPayloadBuilder(),
    filePayloadBuilder: ClipboardFilePayloadBuilder = ClipboardFilePayloadBuilder(),
    mediaPayloadBuilder: ClipboardMediaPayloadBuilder? = nil,
    privacyFilter: PrivacyFilter = PrivacyFilter(),
    enabledTypes: Set<ClipboardKind> = Set(ClipboardKind.allCases)
  ) {
    self.pasteboard = pasteboard
    self.store = store
    self.blobStorage = blobStorage
    self.writeTracker = writeTracker
    self.textPayloadBuilder = textPayloadBuilder
    self.filePayloadBuilder = filePayloadBuilder
    self.mediaPayloadBuilder = mediaPayloadBuilder ?? ClipboardMediaPayloadBuilder(
      blobStorage: blobStorage,
      textPayloadBuilder: textPayloadBuilder
    )
    self.privacyFilter = privacyFilter
    self.enabledTypes = enabledTypes
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
    self.privacyFilter = privacyFilter
  }

  func updateEnabledTypes(_ enabledTypes: Set<ClipboardKind>) {
    self.enabledTypes = enabledTypes
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

    guard enabledTypes.contains(payload.kind) else {
      return
    }

    let sourceApp = NSWorkspace.shared.frontmostApplication
    let bundleId = sourceApp?.bundleIdentifier

    guard privacyFilter.shouldRecord(
      sourceAppBundleId: bundleId,
      pasteboardTypes: payload.pasteboardTypes
    ) else {
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

    if let filePayload = readFilePayload(types: types) {
      return filePayload
    }

    if let imagePayload = readImagePayload(types: types) {
      return imagePayload
    }

    if let richPayload = readRichTextPayload(types: types) {
      return richPayload
    }

    if let text = pasteboard.string(forType: .string) {
      return textPayloadBuilder.payload(from: text, pasteboardTypes: types)
    }

    return nil
  }

  private func readFilePayload(types: Set<String>) -> ClipboardPayload? {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [
      .urlReadingFileURLsOnly: true
    ]
    let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options)
    let urls = (objects as? [URL]) ?? (objects as? [NSURL])?.map { $0 as URL } ?? []
    let fileURLs = urls.filter { $0.isFileURL }

    guard !fileURLs.isEmpty else {
      return nil
    }

    return filePayloadBuilder.payload(from: fileURLs, pasteboardTypes: types)
  }

  private func readImagePayload(types: Set<String>) -> ClipboardPayload? {
    let candidateTypes: [(NSPasteboard.PasteboardType, String)] = [
      (.png, "png"),
      (.tiff, "tiff")
    ]

    for (type, fileExtension) in candidateTypes {
      guard let data = pasteboard.data(forType: type) else {
        continue
      }

      do {
        return try mediaPayloadBuilder.imagePayload(
          data: data,
          pasteboardType: type.rawValue,
          preferredExtension: fileExtension,
          pasteboardTypes: types
        )
      } catch {
        print("Unable to persist image clipboard data: \(error)")
        return nil
      }
    }

    guard let image = NSImage(pasteboard: pasteboard),
          let data = image.tiffRepresentation else {
      return nil
    }

    do {
      return try mediaPayloadBuilder.imagePayload(
        data: data,
        pasteboardType: NSPasteboard.PasteboardType.tiff.rawValue,
        preferredExtension: "tiff",
        pasteboardTypes: types
      )
    } catch {
      print("Unable to persist image clipboard data: \(error)")
      return nil
    }
  }

  private func readRichTextPayload(types: Set<String>) -> ClipboardPayload? {
    if let htmlData = pasteboard.data(forType: .html) {
      return makeRichPayload(
        kind: .html,
        data: htmlData,
        pasteboardType: .html,
        fileExtension: "html",
        fallbackTitle: "HTML",
        types: types
      )
    }

    if let rtfData = pasteboard.data(forType: .rtf) {
      return makeRichPayload(
        kind: .richText,
        data: rtfData,
        pasteboardType: .rtf,
        fileExtension: "rtf",
        fallbackTitle: "富文本",
        types: types
      )
    }

    return nil
  }

  private func makeRichPayload(
    kind: ClipboardKind,
    data: Data,
    pasteboardType: NSPasteboard.PasteboardType,
    fileExtension: String,
    fallbackTitle: String,
    types: Set<String>
  ) -> ClipboardPayload? {
    let plainText = pasteboard.string(forType: .string)

    do {
      return try mediaPayloadBuilder.richTextPayload(
        kind: kind,
        data: data,
        pasteboardType: pasteboardType.rawValue,
        preferredExtension: fileExtension,
        fallbackTitle: fallbackTitle,
        plainText: plainText,
        pasteboardTypes: types
      )
    } catch {
      print("Unable to persist rich clipboard data: \(error)")
      return nil
    }
  }
}
