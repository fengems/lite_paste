import AppKit
import Foundation
import LitePasteCore
import SwiftUI

@MainActor
final class PanelCoordinator {
  private let store: HistoryStore
  private let writer: PasteboardWriter
  private var panel: NSPanel?

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
    panel.makeKeyAndOrderFront(nil)
  }

  private func makePanel() -> NSPanel {
    let rootView = ClipboardPanelView(store: store) { [weak self] record in
      self?.writer.copy(record)
    } pasteAction: { [weak self] record in
      _ = self?.writer.paste(record)
      self?.panel?.orderOut(nil)
    }

    let hostingController = NSHostingController(rootView: rootView)
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
      styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

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
