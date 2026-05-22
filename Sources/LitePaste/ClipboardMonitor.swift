import AppKit
import Foundation
import LitePasteCore

@MainActor
final class ClipboardMonitor {
  private let pasteboard: NSPasteboard
  private let store: HistoryStore
  private var privacyFilter: PrivacyFilter
  private var timer: Timer?
  private var lastChangeCount: Int

  init(
    pasteboard: NSPasteboard = .general,
    store: HistoryStore,
    privacyFilter: PrivacyFilter = PrivacyFilter()
  ) {
    self.pasteboard = pasteboard
    self.store = store
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
        pasteboardTypes: types
      )
    }

    return nil
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

