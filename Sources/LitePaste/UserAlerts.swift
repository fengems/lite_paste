import AppKit

enum UserAlerts {
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
