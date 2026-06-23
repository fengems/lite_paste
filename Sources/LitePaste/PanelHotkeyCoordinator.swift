import LitePasteCore

@MainActor
final class PanelHotkeyCoordinator {
  private let settingsStore: AppSettingsStore
  private let controller: GlobalHotkeyController
  private var registeredHotkey: String?
  private var isRevertingSettings = false

  init(settingsStore: AppSettingsStore, onTrigger: @escaping () -> Void) {
    self.settingsStore = settingsStore
    self.controller = GlobalHotkeyController(action: onTrigger)
  }

  func start() {
    register(settingsStore.settings.hotkey)
  }

  func stop() {
    controller.unregister()
  }

  func apply(_ hotkey: String) {
    guard !isRevertingSettings else {
      return
    }

    register(hotkey)
  }

  private func register(_ hotkey: String) {
    guard registeredHotkey != hotkey else {
      return
    }

    let previousHotkey = registeredHotkey
    let result = controller.register(hotkey: hotkey)
    guard result.isRegistered else {
      let restoredPreviousHotkey = restorePreviousHotkey(previousHotkey)
      showRegistrationAlert(
        hotkey: hotkey,
        result: result,
        restoredPreviousHotkey: restoredPreviousHotkey
      )
      revertSetting(to: restoredPreviousHotkey ?? AppSettings().hotkey)
      return
    }

    registeredHotkey = hotkey
  }

  private func restorePreviousHotkey(_ previousHotkey: String?) -> String? {
    guard let previousHotkey else {
      return nil
    }

    if controller.register(hotkey: previousHotkey).isRegistered {
      registeredHotkey = previousHotkey
      return previousHotkey
    }

    registeredHotkey = nil
    return nil
  }

  private func revertSetting(to hotkey: String) {
    guard settingsStore.settings.hotkey != hotkey else {
      return
    }

    isRevertingSettings = true
    settingsStore.update { $0.hotkey = hotkey }
    isRevertingSettings = false
  }

  private func showRegistrationAlert(
    hotkey: String,
    result: GlobalHotkeyRegistrationResult,
    restoredPreviousHotkey: String?
  ) {
    let requestedHotkey = PanelHotkeyCatalog.displayName(for: hotkey)
    let restoredMessage = restoredPreviousHotkey.map {
      AppText.value(
        "已恢复为之前可用的快捷键 \(PanelHotkeyCatalog.displayName(for: $0))。",
        "Restored the previous available shortcut \(PanelHotkeyCatalog.displayName(for: $0))."
      )
    } ?? AppText.value(
      "当前没有可用的面板快捷键，请在设置中选择其他组合。",
      "No panel shortcut is currently available. Choose another combination in Settings."
    )

    UserAlerts.showMessage(
      title: AppText.value("无法注册面板快捷键", "Unable To Register Panel Shortcut"),
      message: AppText.value(
        "\(requestedHotkey) 无法注册。\(failureReason(for: result)) \(restoredMessage)",
        "\(requestedHotkey) could not be registered. \(failureReason(for: result)) \(restoredMessage)"
      )
    )
  }

  private func failureReason(for result: GlobalHotkeyRegistrationResult) -> String {
    switch result {
    case .registered:
      AppText.value("快捷键已注册。", "Shortcut registered.")
    case .invalidHotkey:
      AppText.value("该快捷键格式无效。", "The shortcut format is invalid.")
    case let .registrationFailed(status):
      AppText.value(
        "可能已被其他应用或系统快捷键占用。系统状态码：\(status)。",
        "It may already be used by another app or a system shortcut. System status: \(status)."
      )
    case let .handlerFailed(status):
      AppText.value(
        "快捷键事件监听无法启动。系统状态码：\(status)。",
        "Shortcut event monitoring could not start. System status: \(status)."
      )
    }
  }
}
