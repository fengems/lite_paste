import ApplicationServices
import AppKit
import Foundation

enum AccessibilityPermissionController {
  static var isTrusted: Bool {
    AXIsProcessTrusted()
  }

  static func requestPermission() {
    let options = [
      "AXTrustedCheckOptionPrompt": true
    ] as CFDictionary
    AXIsProcessTrustedWithOptions(options)
  }

  static func openSystemSettings() {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
      return
    }

    NSWorkspace.shared.open(url)
  }
}
