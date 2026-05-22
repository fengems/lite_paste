import Carbon
import Foundation

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

  func registerDefaultHotkey() {
    let signature = fourCharacterCode("LTPA")
    let hotKeyID = EventHotKeyID(signature: signature, id: 1)
    let modifiers = UInt32(cmdKey | shiftKey)

    let hotKeyStatus = RegisterEventHotKey(
      UInt32(kVK_ANSI_V),
      modifiers,
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )

    guard hotKeyStatus == noErr else {
      print("Unable to register Lite Paste global hotkey: \(hotKeyStatus)")
      return
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
      print("Unable to install Lite Paste hotkey handler: \(handlerStatus)")
    }
  }

  private func fourCharacterCode(_ string: String) -> FourCharCode {
    assert(string.utf8.count == 4)
    return string.utf8.reduce(0) { result, character in
      (result << 8) + FourCharCode(character)
    }
  }
}
