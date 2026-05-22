import AppKit
import Foundation
import LitePasteCore
import SwiftUI

@MainActor
final class PanelCoordinator {
  private let store: HistoryStore
  private let writer: PasteboardWriter
  private let settingsStore = AppSettingsStore.shared
  private let presentationState = PanelPresentationState()
  private var panel: NSPanel?
  private var previousApplication: NSRunningApplication?

  init(store: HistoryStore, writer: PasteboardWriter) {
    self.store = store
    self.writer = writer
  }

  func toggle(relativeTo statusButton: NSStatusBarButton?) {
    if let panel, panel.isVisible {
      panel.orderOut(nil)
      return
    }

    show(relativeTo: statusButton)
  }

  func show(relativeTo statusButton: NSStatusBarButton?) {
    let panel = panel ?? makePanel()
    self.panel = panel
    previousApplication = NSWorkspace.shared.frontmostApplication

    if let statusButton, let statusWindow = statusButton.window {
      let buttonFrame = statusButton.convert(statusButton.bounds, to: nil)
      let screenFrame = statusWindow.convertToScreen(buttonFrame)
      let origin = NSPoint(
        x: screenFrame.midX - panel.frame.width / 2,
        y: screenFrame.minY - panel.frame.height - 10
      )
      panel.setFrameOrigin(origin)
    } else if let screen = NSScreen.main {
      panel.center(in: screen.visibleFrame)
    }

    NSApp.activate(ignoringOtherApps: true)
    presentationState.markOpened()
    panel.makeKeyAndOrderFront(nil)
  }

  private func makePanel() -> NSPanel {
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
      styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    let rootView = ClipboardPanelView(
      store: store,
      presentationState: presentationState,
      copyAction: { [weak self] record in
        self?.writer.copy(record)
      },
      pasteAction: { [weak self] record in
        self?.paste(record)
      },
      primaryCopyAction: { [weak self] record in
        self?.writer.copy(record, asPlainText: self?.settingsStore.settings.pastePlainByDefault ?? false)
      },
      primaryPasteAction: { [weak self] record in
        self?.paste(record, asPlainText: self?.settingsStore.settings.pastePlainByDefault ?? false)
      },
      closeAction: { [weak panel] in
        panel?.orderOut(nil)
      }
    )
    let hostingController = NSHostingController(rootView: rootView)

    panel.title = "Lite Paste"
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isFloatingPanel = true
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.isReleasedWhenClosed = false
    panel.contentViewController = hostingController
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = true

    return panel
  }

  private func paste(_ record: ClipboardRecord) {
    paste(record, asPlainText: false)
  }

  private func paste(_ record: ClipboardRecord, asPlainText: Bool) {
    panel?.orderOut(nil)
    let result = writer.paste(
      record,
      targetApplication: previousApplication,
      asPlainText: asPlainText
    )

    if result == .accessibilityPermissionRequired {
      showAccessibilityPermissionAlert()
    }
  }

  private func showAccessibilityPermissionAlert() {
    let alert = NSAlert()
    alert.messageText = "需要辅助功能权限"
    alert.informativeText = "Lite Paste 已复制该内容。授予辅助功能权限后，可以自动粘贴到上一个应用。"
    alert.addButton(withTitle: "好")
    alert.alertStyle = .informational
    alert.runModal()
  }
}

private extension NSPanel {
  func center(in frame: NSRect) {
    setFrameOrigin(
      NSPoint(
        x: frame.midX - self.frame.width / 2,
        y: frame.midY - self.frame.height / 2
      )
    )
  }
}
