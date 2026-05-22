import Carbon
import Foundation
import LitePasteCore

@MainActor
final class GlobalHotkeyController {
  private var hotKeyRef: EventHotKeyRef?
  private var eventHandlerRef: EventHandlerRef?
  private let action: () -> Void

  init(action: @escaping () -> Void) {
    self.action = action
  }

  func unregister() {
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }

    if let eventHandlerRef {
      RemoveEventHandler(eventHandlerRef)
      self.eventHandlerRef = nil
    }
  }

  @discardableResult
  func register(hotkey: String) -> GlobalHotkeyRegistrationResult {
    unregister()

    guard let descriptor = HotkeyDescriptor(hotkey) else {
      return .invalidHotkey
    }

    let signature = fourCharacterCode("LTPA")
    let hotKeyID = EventHotKeyID(signature: signature, id: 1)

    let hotKeyStatus = RegisterEventHotKey(
      descriptor.keyCode,
      descriptor.modifiers,
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )

    guard hotKeyStatus == noErr else {
      return .registrationFailed(hotKeyStatus)
    }

    var eventSpec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )

    let handlerStatus = InstallEventHandler(
      GetApplicationEventTarget(),
      { _, _, userData in
        guard let userData else {
          return noErr
        }

        let controller = Unmanaged<GlobalHotkeyController>
          .fromOpaque(userData)
          .takeUnretainedValue()

        Task { @MainActor in
          controller.action()
        }

        return noErr
      },
      1,
      &eventSpec,
      Unmanaged.passUnretained(self).toOpaque(),
      &eventHandlerRef
    )

    if handlerStatus != noErr {
      unregister()
      return .handlerFailed(handlerStatus)
    }

    return .registered
  }

  func registerDefaultHotkey() {
    register(hotkey: AppSettings().hotkey)
  }

  private func fourCharacterCode(_ string: String) -> FourCharCode {
    assert(string.utf8.count == 4)
    return string.utf8.reduce(0) { result, character in
      (result << 8) + FourCharCode(character)
    }
  }
}

enum GlobalHotkeyRegistrationResult: Equatable {
  case registered
  case invalidHotkey
  case registrationFailed(OSStatus)
  case handlerFailed(OSStatus)

  var isRegistered: Bool {
    self == .registered
  }
}

private struct HotkeyDescriptor {
  var keyCode: UInt32
  var modifiers: UInt32

  init?(_ hotkey: String) {
    let parts = Set(
      hotkey
        .lowercased()
        .split(separator: "+")
        .map(String.init)
    )

    var modifiers: UInt32 = 0
    if parts.contains("command") {
      modifiers |= UInt32(cmdKey)
    }
    if parts.contains("shift") {
      modifiers |= UInt32(shiftKey)
    }
    if parts.contains("option") {
      modifiers |= UInt32(optionKey)
    }
    if parts.contains("control") {
      modifiers |= UInt32(controlKey)
    }

    guard let key = parts.first(where: { !["command", "shift", "option", "control"].contains($0) }),
          let keyCode = Self.keyCode(for: key),
          modifiers != 0 else {
      return nil
    }

    self.keyCode = keyCode
    self.modifiers = modifiers
  }

  private static func keyCode(for key: String) -> UInt32? {
    switch key {
    case "v":
      UInt32(kVK_ANSI_V)
    case "space":
      UInt32(kVK_Space)
    default:
      nil
    }
  }
}
