import AppKit
import LitePasteCore
import SwiftUI

@MainActor
enum AppWindowFactory {
  static func makeSettingsWindow(delegate: (any NSWindowDelegate)?) -> NSWindow {
    let hostingController = NSHostingController(rootView: SettingsView())
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 860, height: 600),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = AppText.value("\(AppMetadata.displayName) 设置", "\(AppMetadata.displayName) Settings")
    window.contentViewController = hostingController
    window.minSize = NSSize(width: 780, height: 560)
    window.backgroundColor = .windowBackgroundColor
    window.isOpaque = true
    window.delegate = delegate
    window.isReleasedWhenClosed = false
    window.center()
    return window
  }

  static func makePermissionGuideWindow(
    dismissForSession: @escaping () -> Void,
    completeGuide: @escaping () -> Void
  ) -> NSWindow {
    let hostingController = NSHostingController(
      rootView: PermissionGuideView(
        isAccessibilityTrusted: { AccessibilityPermissionController.isTrusted },
        requestPermission: { AccessibilityPermissionController.requestPermission() },
        openSystemSettings: { AccessibilityPermissionController.openSystemSettings() },
        dismissForSession: dismissForSession,
        completeGuide: completeGuide
      )
    )
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = AppText.value("\(AppMetadata.displayName) 权限设置", "\(AppMetadata.displayName) Permission Setup")
    window.contentViewController = hostingController
    window.isReleasedWhenClosed = false
    window.center()
    return window
  }
}
