import AppKit
import Foundation
import LitePasteCore

@MainActor
final class ClipboardMonitor {
  private let pasteboard: NSPasteboard
  private let store: HistoryStore
  private let blobStore: ClipboardBlobStore
  private var privacyFilter: PrivacyFilter
  private var timer: Timer?
  private var lastChangeCount: Int

  init(
    pasteboard: NSPasteboard = .general,
    store: HistoryStore,
    blobStore: ClipboardBlobStore = ClipboardBlobStore(),
    privacyFilter: PrivacyFilter = PrivacyFilter()
  ) {
    self.pasteboard = pasteboard
    self.store = store
    self.blobStore = blobStore
    self.privacyFilter = privacyFilter
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

  private func captureIfNeeded() {
    guard pasteboard.changeCount != lastChangeCount else {
      return
    }

    lastChangeCount = pasteboard.changeCount

    guard let payload = readPayload() else {
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
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else {
        return nil
      }

      let kind = classify(text)
      let title = Self.makeTitle(from: text)
      return ClipboardPayload(
        kind: kind,
        title: title,
        searchText: text,
        plainText: text,
        pasteboardTypes: types,
        contents: [
          ClipboardContentSnapshot(
            pasteboardType: NSPasteboard.PasteboardType.string.rawValue,
            storageMode: .inline,
            inlineData: Data(text.utf8),
            byteSize: text.utf8.count,
            displayOrder: 0
          )
        ]
      )
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

    let paths = fileURLs.map(\.path)
    let title = fileURLs.count == 1 ? fileURLs[0].lastPathComponent : "\(fileURLs.count) 个文件"
    let text = paths.joined(separator: "\n")

    return ClipboardPayload(
      kind: .files,
      title: title,
      searchText: text,
      plainText: text,
      contentHashBasis: text,
      pasteboardTypes: types,
      contents: paths.enumerated().map { index, path in
        ClipboardContentSnapshot(
          pasteboardType: NSPasteboard.PasteboardType.fileURL.rawValue,
          storageMode: .inline,
          inlineData: Data(path.utf8),
          byteSize: path.utf8.count,
          displayOrder: index
        )
      }
    )
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
        let snapshot = try blobStore.snapshot(
          data: data,
          pasteboardType: type.rawValue,
          preferredExtension: fileExtension,
          displayOrder: 0
        )
        return ClipboardPayload(
          kind: .image,
          title: "图片",
          searchText: "图片 image",
          contentHashBasis: ContentHasher.hash(kind: .image, data: data),
          pasteboardTypes: types,
          contents: [snapshot],
          previewFilePath: snapshot.externalFilePath
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
      let snapshot = try blobStore.snapshot(
        data: data,
        pasteboardType: NSPasteboard.PasteboardType.tiff.rawValue,
        preferredExtension: "tiff",
        displayOrder: 0
      )
      return ClipboardPayload(
        kind: .image,
        title: "图片",
        searchText: "图片 image",
        contentHashBasis: ContentHasher.hash(kind: .image, data: data),
        pasteboardTypes: types,
        contents: [snapshot],
        previewFilePath: snapshot.externalFilePath
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
    let title = plainText.map(Self.makeTitle(from:)) ?? fallbackTitle

    do {
      let snapshot = try blobStore.snapshot(
        data: data,
        pasteboardType: pasteboardType.rawValue,
        preferredExtension: fileExtension,
        displayOrder: 0
      )
      return ClipboardPayload(
        kind: kind,
        title: title,
        searchText: plainText ?? fallbackTitle,
        plainText: plainText,
        contentHashBasis: ContentHasher.hash(kind: kind, data: data),
        pasteboardTypes: types,
        contents: [snapshot]
      )
    } catch {
      print("Unable to persist rich clipboard data: \(error)")
      return nil
    }
  }

  private func classify(_ text: String) -> ClipboardKind {
    if URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines))?.scheme != nil {
      return .url
    }

    if text.range(
      of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#,
      options: [.regularExpression, .caseInsensitive]
    ) != nil {
      return .email
    }

    if text.range(
      of: #"^#(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$"#,
      options: .regularExpression
    ) != nil {
      return .color
    }

    return .text
  }

  private static func makeTitle(from text: String) -> String {
    let compact = text
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "\t", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    if compact.count <= 140 {
      return compact
    }

    let index = compact.index(compact.startIndex, offsetBy: 140)
    return String(compact[..<index])
  }
}
