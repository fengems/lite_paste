import AppKit

enum UserAlerts {
  @MainActor
  static func showAccessibilityPermissionRequired(message: String) {
    let alert = NSAlert()
    alert.messageText = "需要辅助功能权限"
    alert.informativeText = message
    alert.addButton(withTitle: "打开系统设置")
    alert.addButton(withTitle: "稍后")
    alert.alertStyle = .informational

    if alert.runModal() == .alertFirstButtonReturn {
      AccessibilityPermissionController.openSystemSettings()
    }
  }
}
