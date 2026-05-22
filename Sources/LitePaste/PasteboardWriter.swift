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
}

enum PasteActionResult: Equatable {
  case copied
  case pasted
  case accessibilityPermissionRequired
  case missingContent
}
