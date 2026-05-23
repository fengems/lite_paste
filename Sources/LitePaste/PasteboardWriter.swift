import AppKit
import ApplicationServices
import Foundation
import LitePasteCore

@MainActor
final class PasteboardWriter {
  private let pasteboard: NSPasteboard
  private let store: HistoryStore
  private let writeTracker: ClipboardWriteTracker
  private let restorePlanner: PasteboardRestorePlanner

  init(
    pasteboard: NSPasteboard = .general,
    store: HistoryStore,
    writeTracker: ClipboardWriteTracker,
    restorePlanner: PasteboardRestorePlanner = PasteboardRestorePlanner()
  ) {
    self.pasteboard = pasteboard
    self.store = store
    self.writeTracker = writeTracker
    self.restorePlanner = restorePlanner
  }

  @discardableResult
  func copy(_ record: ClipboardRecord, asPlainText: Bool = false) -> PasteActionResult {
    guard let plan = restorePlanner.plan(for: record, asPlainText: asPlainText) else {
      return .missingContent
    }

    if apply(plan) {
      store.markUsed(record.id)
      return .copied
    }

    return .missingContent
  }

  @discardableResult
  func paste(
    _ record: ClipboardRecord,
    targetApplication: NSRunningApplication?,
    asPlainText: Bool = false,
    restorePreviousClipboard: Bool = false
  ) -> PasteActionResult {
    let previousClipboard = restorePreviousClipboard ? PasteboardSnapshot(pasteboard: pasteboard) : nil
    let copyResult = copy(record, asPlainText: asPlainText)
    guard copyResult == .copied else {
      return copyResult
    }

    guard AccessibilityPermissionController.isTrusted else {
      AccessibilityPermissionController.requestPermission()
      return .accessibilityPermissionRequired
    }

    guard activate(targetApplication) else {
      return .targetApplicationUnavailable
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
      Self.sendPasteShortcut()

      if let previousClipboard {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
          self?.restorePreviousClipboard(previousClipboard)
        }
      }
    }

    return .pasted
  }

  private func activate(_ targetApplication: NSRunningApplication?) -> Bool {
    guard let targetApplication,
          !targetApplication.isTerminated else {
      return false
    }

    return targetApplication.activate()
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

  private func apply(_ plan: PasteboardRestorePlan) -> Bool {
    pasteboard.clearContents()

    let restored: Bool
    switch plan {
    case let .fileURLs(urls):
      restored = pasteboard.writeObjects(urls as [NSURL])
    case let .items(items):
      for item in items {
        let type = NSPasteboard.PasteboardType(item.pasteboardType)
        pasteboard.setData(item.data, forType: type)
      }
      restored = true
    case let .plainText(text):
      pasteboard.setString(text, forType: .string)
      restored = true
    }

    if restored {
      markCurrentPasteboardChangeIgnored()
    }
    return restored
  }

  private func markCurrentPasteboardChangeIgnored() {
    writeTracker.markIgnoredChangeCount(pasteboard.changeCount)
  }

  private func restorePreviousClipboard(_ snapshot: PasteboardSnapshot) {
    if snapshot.restore(to: pasteboard) {
      markCurrentPasteboardChangeIgnored()
    }
  }
}

enum PasteActionResult: Equatable {
  case copied
  case pasted
  case accessibilityPermissionRequired
  case missingContent
  case targetApplicationUnavailable
}
