import AppKit
import Combine
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
  private var cancellables = Set<AnyCancellable>()

  init(store: HistoryStore, writer: PasteboardWriter) {
    self.store = store
    self.writer = writer
    observeAppDeactivation()
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

    position(panel, relativeTo: statusButton)

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
        self?.copy(record)
      },
      copyPlainTextAction: { [weak self] record in
        self?.copy(record, asPlainText: true)
      },
      pasteAction: { [weak self] record in
        self?.paste(record)
      },
      pastePlainTextAction: { [weak self] record in
        self?.paste(record, asPlainText: true)
      },
      primaryCopyAction: { [weak self] record in
        self?.copy(record, asPlainText: self?.settingsStore.settings.pastePlainByDefault ?? false)
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

  private func observeAppDeactivation() {
    NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
      .sink { [weak self] _ in
        Task { @MainActor in
          self?.hidePanel()
        }
      }
      .store(in: &cancellables)
  }

  private func position(_ panel: NSPanel, relativeTo statusButton: NSStatusBarButton?) {
    switch settingsStore.settings.panelPosition {
    case .statusItem:
      positionBelowStatusItem(panel, relativeTo: statusButton)
    case .mouseScreenCenter:
      panel.center(in: Self.screenContainingMouse()?.visibleFrame ?? NSScreen.main?.visibleFrame)
    }
  }

  private func positionBelowStatusItem(_ panel: NSPanel, relativeTo statusButton: NSStatusBarButton?) {
    guard let statusButton, let statusWindow = statusButton.window else {
      panel.center(in: Self.screenContainingMouse()?.visibleFrame ?? NSScreen.main?.visibleFrame)
      return
    }

    let buttonFrame = statusButton.convert(statusButton.bounds, to: nil)
    let screenFrame = statusWindow.convertToScreen(buttonFrame)
    let visibleFrame = statusWindow.screen?.visibleFrame ?? Self.screenContainingMouse()?.visibleFrame
    let origin = NSPoint(
      x: screenFrame.midX - panel.frame.width / 2,
      y: screenFrame.minY - panel.frame.height - 10
    )
    panel.setFrameOrigin(origin.clamped(panelSize: panel.frame.size, to: visibleFrame))
  }

  private func paste(_ record: ClipboardRecord) {
    paste(record, asPlainText: false)
  }

  private func copy(_ record: ClipboardRecord, asPlainText: Bool = false) {
    let result = writer.copy(record, asPlainText: asPlainText)
    handleActionResult(result)
  }

  private func paste(_ record: ClipboardRecord, asPlainText: Bool) {
    let result = writer.paste(
      record,
      targetApplication: previousApplication,
      asPlainText: asPlainText,
      restorePreviousClipboard: settingsStore.settings.restoreClipboardAfterPaste
    )

    handleActionResult(result, closesPanelOnSuccess: true)
  }

  private func handleActionResult(_ result: PasteActionResult, closesPanelOnSuccess: Bool = false) {
    switch result {
    case .copied:
      break
    case .pasted:
      if closesPanelOnSuccess {
        hidePanel()
      }
    case .accessibilityPermissionRequired:
      if closesPanelOnSuccess {
        hidePanel()
      }
      showAccessibilityPermissionAlert()
    case .missingContent:
      showMissingContentAlert()
    }
  }

  private func showAccessibilityPermissionAlert() {
    let alert = NSAlert()
    alert.messageText = "需要辅助功能权限"
    alert.informativeText = "Lite Paste 已复制该内容。授予辅助功能权限后，可以自动粘贴到上一个应用。"
    alert.addButton(withTitle: "打开系统设置")
    alert.addButton(withTitle: "稍后")
    alert.alertStyle = .informational

    if alert.runModal() == .alertFirstButtonReturn {
      AccessibilityPermissionController.openSystemSettings()
    }
  }

  private func showMissingContentAlert() {
    let alert = NSAlert()
    alert.messageText = "无法恢复该内容"
    alert.informativeText = "该历史记录引用的文件或媒体数据已经不存在。你可以删除这条记录，或从备份恢复缺失的 Blobs 数据。"
    alert.addButton(withTitle: "好")
    alert.alertStyle = .warning
    alert.runModal()
  }

  private func hidePanel() {
    panel?.orderOut(nil)
  }
}

private extension NSPanel {
  func center(in frame: NSRect?) {
    guard let frame else {
      center()
      return
    }

    setFrameOrigin(
      NSPoint(
        x: frame.midX - self.frame.width / 2,
        y: frame.midY - self.frame.height / 2
      ).clamped(panelSize: self.frame.size, to: frame)
    )
  }
}

private extension PanelCoordinator {
  static func screenContainingMouse() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
  }
}

private extension NSPoint {
  func clamped(panelSize: NSSize, to frame: NSRect?) -> NSPoint {
    guard let frame else {
      return self
    }

    let maxX = max(frame.minX, frame.maxX - panelSize.width)
    let maxY = max(frame.minY, frame.maxY - panelSize.height)
    return NSPoint(
      x: min(max(x, frame.minX), maxX),
      y: min(max(y, frame.minY), maxY)
    )
  }
}
