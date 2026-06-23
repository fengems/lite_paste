import AppKit

enum UserAlerts {
  @discardableResult
  @MainActor
  static func showMessage(
    title: String,
    message: String,
    style: NSAlert.Style = .informational,
    buttonTitle: String = AppText.value("好", "OK")
  ) -> NSApplication.ModalResponse {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: buttonTitle)
    alert.alertStyle = style
    return alert.runModal()
  }

  @MainActor
  static func confirm(
    title: String,
    message: String,
    confirmTitle: String = AppText.value("确认", "Confirm"),
    cancelTitle: String = AppText.value("取消", "Cancel"),
    style: NSAlert.Style = .warning
  ) -> Bool {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: confirmTitle)
    alert.addButton(withTitle: cancelTitle)
    alert.alertStyle = style
    return alert.runModal() == .alertFirstButtonReturn
  }

  @MainActor
  static func showAccessibilityPermissionRequired(message: String) {
    let alert = NSAlert()
    alert.messageText = AppText.value("需要辅助功能权限", "Accessibility Permission Required")
    alert.informativeText = message
    alert.addButton(withTitle: AppText.value("打开系统设置", "Open System Settings"))
    alert.addButton(withTitle: AppText.value("稍后", "Later"))
    alert.alertStyle = .informational

    if alert.runModal() == .alertFirstButtonReturn {
      AccessibilityPermissionController.openSystemSettings()
    }
  }
}
