import AppKit
import ApplicationServices
import Foundation
import LitePasteCore

@MainActor
final class PasteboardWriter {
  private let pasteboard: NSPasteboard
  private let store: HistoryStore

  init(pasteboard: NSPasteboard = .general, store: HistoryStore) {
    self.pasteboard = pasteboard
    self.store = store
  }

  @discardableResult
  func copy(_ record: ClipboardRecord) -> PasteActionResult {
    if restoreFileURLs(record) {
      store.markUsed(record.id)
      return .copied
    }

    if restoreContentSnapshots(record) {
      store.markUsed(record.id)
      return .copied
    }

    guard let text = record.plainText else {
      return .missingContent
    }

    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    store.markUsed(record.id)
    return .copied
  }

  @discardableResult
  func paste(_ record: ClipboardRecord) -> PasteActionResult {
    let copyResult = copy(record)
    guard copyResult == .copied else {
      return copyResult
    }

    guard AXIsProcessTrusted() else {
      requestAccessibilityPermission()
      return .accessibilityPermissionRequired
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
      Self.sendPasteShortcut()
    }

    return .pasted
  }

  private func requestAccessibilityPermission() {
    let options = [
      "AXTrustedCheckOptionPrompt": true
    ] as CFDictionary
    AXIsProcessTrustedWithOptions(options)
  }

  private static func sendPasteShortcut() {
    let source = CGEventSource(stateID: .combinedSessionState)
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)

    keyDown?.flags = .maskCommand
    keyUp?.flags = .maskCommand
    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
  }

  private func restoreFileURLs(_ record: ClipboardRecord) -> Bool {
    guard record.kind == .files,
          let text = record.plainText else {
      return false
    }

    let urls = text
      .split(separator: "\n")
      .map { URL(fileURLWithPath: String($0)) }

    guard !urls.isEmpty else {
      return false
    }

    pasteboard.clearContents()
    return pasteboard.writeObjects(urls as [NSURL])
  }

  private func restoreContentSnapshots(_ record: ClipboardRecord) -> Bool {
    let snapshots = record.contents.sorted { $0.displayOrder < $1.displayOrder }
    guard !snapshots.isEmpty else {
      return false
    }

    pasteboard.clearContents()

    var restored = false
    for snapshot in snapshots {
      guard let data = data(for: snapshot) else {
        continue
      }

      let type = NSPasteboard.PasteboardType(snapshot.pasteboardType)
      pasteboard.setData(data, forType: type)
      restored = true
    }

    if let text = record.plainText, !text.isEmpty {
      pasteboard.setString(text, forType: .string)
      restored = true
    }

    return restored
  }

  private func data(for snapshot: ClipboardContentSnapshot) -> Data? {
    switch snapshot.storageMode {
    case .inline:
      return snapshot.inlineData
    case .external:
      guard let externalFilePath = snapshot.externalFilePath else {
        return nil
      }

      return try? Data(contentsOf: URL(fileURLWithPath: externalFilePath))
    }
  }
}

enum PasteActionResult: Equatable {
  case copied
  case pasted
  case accessibilityPermissionRequired
  case missingContent
}
