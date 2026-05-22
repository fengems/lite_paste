import Carbon
import Foundation
import LitePasteCore

@MainActor
final class PinnedHotkeyController {
  private var hotKeyRefs: [EventHotKeyRef] = []
  private var eventHandlerRef: EventHandlerRef?
  private var shortcutByHotKeyID: [UInt32: ClipboardRecord.ID] = [:]
  private let action: (ClipboardRecord.ID) -> Void

  init(action: @escaping (ClipboardRecord.ID) -> Void) {
    self.action = action
  }

  @discardableResult
  func update(records: [ClipboardRecord]) -> [PinnedHotkeyRegistrationIssue] {
    unregisterHotKeys()
    shortcutByHotKeyID.removeAll()

    let pinnedRecords = records
      .filter { $0.isPinned && $0.pinShortcut != nil }
      .sorted { $0.lastCopiedAt > $1.lastCopiedAt }

    guard !pinnedRecords.isEmpty else {
      return []
    }

    if let handlerStatus = installHandlerIfNeeded() {
      return pinnedRecords.compactMap { record in
        guard let shortcut = record.pinShortcut else {
          return nil
        }

        return PinnedHotkeyRegistrationIssue(
          recordID: record.id,
          recordTitle: record.title,
          shortcut: shortcut,
          reason: .handlerFailed(handlerStatus)
        )
      }
    }

    var issues: [PinnedHotkeyRegistrationIssue] = []
    for record in pinnedRecords {
      guard let shortcut = record.pinShortcut else {
        continue
      }

      guard let keyCode = Self.keyCode(for: shortcut),
            let hotKeyID = Self.hotKeyID(for: shortcut) else {
        issues.append(
          PinnedHotkeyRegistrationIssue(
            recordID: record.id,
            recordTitle: record.title,
            shortcut: shortcut,
            reason: .invalidShortcut
          )
        )
        continue
      }

      var hotKeyRef: EventHotKeyRef?
      let status = RegisterEventHotKey(
        keyCode,
        UInt32(cmdKey | optionKey),
        hotKeyID,
        GetApplicationEventTarget(),
        0,
        &hotKeyRef
      )

      guard status == noErr, let hotKeyRef else {
        issues.append(
          PinnedHotkeyRegistrationIssue(
            recordID: record.id,
            recordTitle: record.title,
            shortcut: shortcut,
            reason: .registrationFailed(status)
          )
        )
        continue
      }

      hotKeyRefs.append(hotKeyRef)
      shortcutByHotKeyID[hotKeyID.id] = record.id
    }

    return issues
  }

  func unregister() {
    unregisterHotKeys()

    if let eventHandlerRef {
      RemoveEventHandler(eventHandlerRef)
      self.eventHandlerRef = nil
    }

    shortcutByHotKeyID.removeAll()
  }

  private func unregisterHotKeys() {
    for hotKeyRef in hotKeyRefs {
      UnregisterEventHotKey(hotKeyRef)
    }
    hotKeyRefs.removeAll()
  }

  private func installHandlerIfNeeded() -> OSStatus? {
    guard eventHandlerRef == nil else {
      return nil
    }

    var eventSpec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )

    let status = InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, userData in
        guard let event, let userData else {
          return noErr
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
          event,
          EventParamName(kEventParamDirectObject),
          EventParamType(typeEventHotKeyID),
          nil,
          MemoryLayout<EventHotKeyID>.size,
          nil,
          &hotKeyID
        )

        guard status == noErr else {
          return noErr
        }

        let controller = Unmanaged<PinnedHotkeyController>
          .fromOpaque(userData)
          .takeUnretainedValue()

        Task { @MainActor in
          controller.trigger(hotKeyID.id)
        }

        return noErr
      },
      1,
      &eventSpec,
      Unmanaged.passUnretained(self).toOpaque(),
      &eventHandlerRef
    )

    if status == noErr {
      return nil
    }

    eventHandlerRef = nil
    return status
  }

  private func trigger(_ hotKeyID: UInt32) {
    guard let recordID = shortcutByHotKeyID[hotKeyID] else {
      return
    }

    action(recordID)
  }

  private static func keyCode(for shortcut: String) -> UInt32? {
    switch PinShortcutCatalog.normalized(shortcut) {
    case "command+option+1":
      UInt32(kVK_ANSI_1)
    case "command+option+2":
      UInt32(kVK_ANSI_2)
    case "command+option+3":
      UInt32(kVK_ANSI_3)
    case "command+option+4":
      UInt32(kVK_ANSI_4)
    case "command+option+5":
      UInt32(kVK_ANSI_5)
    case "command+option+6":
      UInt32(kVK_ANSI_6)
    case "command+option+7":
      UInt32(kVK_ANSI_7)
    case "command+option+8":
      UInt32(kVK_ANSI_8)
    case "command+option+9":
      UInt32(kVK_ANSI_9)
    default:
      nil
    }
  }

  private static func hotKeyID(for shortcut: String) -> EventHotKeyID? {
    guard let shortcut = PinShortcutCatalog.normalized(shortcut),
          let index = PinShortcutCatalog.shortcuts.firstIndex(of: shortcut) else {
      return nil
    }

    return EventHotKeyID(signature: fourCharacterCode("LTPN"), id: UInt32(index + 1))
  }

  private static func fourCharacterCode(_ string: String) -> FourCharCode {
    assert(string.utf8.count == 4)
    return string.utf8.reduce(0) { result, character in
      (result << 8) + FourCharCode(character)
    }
  }
}

struct PinnedHotkeyRegistrationIssue: Equatable {
  var recordID: ClipboardRecord.ID
  var recordTitle: String
  var shortcut: String
  var reason: PinnedHotkeyRegistrationIssueReason
}

enum PinnedHotkeyRegistrationIssueReason: Equatable {
  case invalidShortcut
  case registrationFailed(OSStatus)
  case handlerFailed(OSStatus)
}
