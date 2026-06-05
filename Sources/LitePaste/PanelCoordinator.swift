import AppKit
import Combine
import Foundation
import LitePasteCore
import SwiftUI

final class ClipboardPanelWindow: NSPanel {
  var usesExactFramePlacement = false

  override var canBecomeKey: Bool {
    true
  }

  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    usesExactFramePlacement ? frameRect : super.constrainFrameRect(frameRect, to: screen)
  }
}

@MainActor
final class PanelCoordinator {
  private let store: HistoryStore
  private let writer: PasteboardWriter
  private let settingsStore = AppSettingsStore.shared
  private let presentationState = PanelPresentationState()
  private var panel: NSPanel?
  private var previousApplication: NSRunningApplication?
  private var edgePanelThickness: CGFloat = ClipboardPanelMetrics.edgePanelThickness
  private var cancellables = Set<AnyCancellable>()

  init(store: HistoryStore, writer: PasteboardWriter) {
    self.store = store
    self.writer = writer
    observeAppDeactivation()
    observePanelSettings()
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

  func hide() {
    hidePanel()
  }

  private func makePanel() -> NSPanel {
    let panel = ClipboardPanelWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1120, height: edgePanelThickness),
      styleMask: [.borderless, .nonactivatingPanel],
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
    applyRoundedContentMask(to: hostingController.view)

    panel.title = AppMetadata.displayName
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isFloatingPanel = true
    applyPanelLevel(panel)
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.isReleasedWhenClosed = false
    panel.contentViewController = hostingController
    applyRoundedContentMask(to: panel.contentView)
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = true
    panel.isMovableByWindowBackground = false

    return panel
  }

  private func applyRoundedContentMask(to view: NSView?) {
    view?.wantsLayer = true
    view?.layer?.cornerRadius = ClipboardPanelMetrics.cornerRadius
    view?.layer?.masksToBounds = true
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

  private func observePanelSettings() {
    settingsStore.settingsPublisher
      .sink { [weak self] _ in
        Task { @MainActor in
          guard let self, let panel = self.panel, panel.isVisible else {
            return
          }
          self.position(panel, relativeTo: nil)
        }
      }
      .store(in: &cancellables)
  }

  private func position(_ panel: NSPanel, relativeTo statusButton: NSStatusBarButton?) {
    let isEdgeAttached = settingsStore.settings.panelPosition.isEdgeAttached
    panel.isMovableByWindowBackground = !isEdgeAttached
    (panel as? ClipboardPanelWindow)?.usesExactFramePlacement = isEdgeAttached
    applyPanelLevel(panel)

    switch settingsStore.settings.panelPosition {
    case .edgeBottom, .edgeTop, .edgeLeft, .edgeRight, .bottomDrawer, .statusItem:
      positionEdgeAttached(panel, position: settingsStore.settings.panelPosition)
    case .cursor, .mouseScreenCenter:
      presentationState.updateTopObstruction(nil)
      positionNearMouse(panel)
    }
  }

  private func positionEdgeAttached(_ panel: NSPanel, position: PanelPosition) {
    guard let screen = Self.screenContainingMouse() ?? NSScreen.main else {
      panel.center()
      presentationState.updateTopObstruction(nil)
      return
    }

    let frame = edgeAttachedFrame(for: position, on: screen).roundedToScreenPoints()
    panel.setFrame(frame, display: true)
    presentationState.updateTopObstruction(topObstruction(for: position, panelFrame: frame, on: screen))
  }

  private func positionNearMouse(_ panel: NSPanel) {
    guard let screen = Self.screenContainingMouse() ?? NSScreen.main else {
      panel.center()
      return
    }

    let visibleFrame = screen.visibleFrame
    let size = floatingPanelSize(in: visibleFrame)
    let mouseLocation = NSEvent.mouseLocation
    let preferredOrigin = NSPoint(
      x: mouseLocation.x + 10,
      y: mouseLocation.y - size.height - 10
    )
    let origin = preferredOrigin.clamped(panelSize: size, to: visibleFrame)
    panel.setFrame(NSRect(origin: origin, size: size).roundedToScreenPoints(), display: true)
  }

  private func edgeAttachedFrame(for position: PanelPosition, on screen: NSScreen) -> NSRect {
    let displayFrame = screen.frame
    let visibleFrame = screen.visibleFrame
    let coversMenuBar = settingsStore.settings.coverMenuBarWhenEdgeAttached
    let thickness = clampedEdgePanelThickness(for: visibleFrame)
    switch position {
    case .edgeTop:
      let maxY = coversMenuBar ? displayFrame.maxY : visibleFrame.maxY
      return NSRect(x: displayFrame.minX, y: maxY - thickness, width: displayFrame.width, height: thickness)
    case .edgeLeft:
      let maxY = coversMenuBar ? displayFrame.maxY : visibleFrame.maxY
      return NSRect(
        x: displayFrame.minX,
        y: visibleFrame.minY,
        width: sideEdgeWidth(in: visibleFrame),
        height: maxY - visibleFrame.minY
      )
    case .edgeRight:
      let width = sideEdgeWidth(in: visibleFrame)
      let maxY = coversMenuBar ? displayFrame.maxY : visibleFrame.maxY
      return NSRect(
        x: displayFrame.maxX - width,
        y: visibleFrame.minY,
        width: width,
        height: maxY - visibleFrame.minY
      )
    case .edgeBottom, .bottomDrawer, .statusItem:
      return NSRect(
        x: displayFrame.minX,
        y: visibleFrame.minY,
        width: displayFrame.width,
        height: thickness
      )
    case .cursor, .mouseScreenCenter:
      return NSRect(origin: visibleFrame.origin, size: floatingPanelSize(in: visibleFrame))
    }
  }

  private func floatingPanelSize(in visibleFrame: NSRect) -> NSSize {
    let width = min(max(visibleFrame.width * 0.56, min(760, visibleFrame.width)), min(920, visibleFrame.width))
    let height = min(max(visibleFrame.height * 0.5, min(420, visibleFrame.height)), min(560, visibleFrame.height))
    return NSSize(width: width, height: height)
  }

  private func sideEdgeWidth(in visibleFrame: NSRect) -> CGFloat {
    min(max(visibleFrame.width * 0.38, min(420, visibleFrame.width)), min(760, visibleFrame.width))
  }

  private func applyPanelLevel(_ panel: NSPanel) {
    panel.level = settingsStore.settings.coverMenuBarWhenEdgeAttached ? .screenSaver : .floating
  }

  private func clampedEdgePanelThickness(for visibleFrame: NSRect) -> CGFloat {
    clampedEdgePanelThickness(edgePanelThickness, for: visibleFrame)
  }

  private func clampedEdgePanelThickness(_ thickness: CGFloat, for visibleFrame: NSRect) -> CGFloat {
    let minimumThickness = ClipboardPanelMetrics.edgePanelThickness
    return min(max(thickness, minimumThickness), max(minimumThickness, visibleFrame.height * 0.62))
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
      presentationState.showActionMessage(AppText.value("已复制", "Copied"))
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
    case .targetApplicationUnavailable:
      if closesPanelOnSuccess {
        hidePanel()
      }
      showTargetApplicationUnavailableAlert()
    }
  }

  private func showAccessibilityPermissionAlert() {
    UserAlerts.showAccessibilityPermissionRequired(
      message: AppText.value(
        "Lite Paste 已复制该内容。授予辅助功能权限后，可以自动粘贴到上一个应用。",
        "Lite Paste copied the content. Grant Accessibility permission to paste into the previous app automatically."
      )
    )
  }

  private func showMissingContentAlert() {
    let alert = NSAlert()
    alert.messageText = AppText.value("无法恢复该内容", "Unable To Restore This Content")
    alert.informativeText = AppText.value(
      "该历史记录引用的文件或媒体数据已经不存在。你可以删除这条记录，或从备份恢复缺失的 Blobs 数据。",
      "The file or media data referenced by this history item no longer exists. Delete the item or restore the missing Blobs data from a backup."
    )
    alert.addButton(withTitle: AppText.value("好", "OK"))
    alert.alertStyle = .warning
    alert.runModal()
  }

  private func showTargetApplicationUnavailableAlert() {
    let alert = NSAlert()
    alert.messageText = AppText.value("无法自动粘贴", "Unable To Auto Paste")
    alert.informativeText = AppText.value(
      "Lite Paste 已复制该内容，但无法回到原来的目标应用。你可以手动按 ⌘V 粘贴。",
      "Lite Paste copied the content, but could not return to the original target app. Press ⌘V manually to paste."
    )
    alert.addButton(withTitle: AppText.value("好", "OK"))
    alert.alertStyle = .informational
    alert.runModal()
  }

  private func hidePanel() {
    panel?.orderOut(nil)
    presentationState.updateTopObstruction(nil)
  }
}

private extension PanelCoordinator {
  func topObstruction(for position: PanelPosition, panelFrame: NSRect, on screen: NSScreen) -> PanelTopObstruction? {
    guard position == .edgeTop,
          let screenObstruction = topObstructionRect(on: screen),
          panelFrame.intersects(screenObstruction) else {
      return nil
    }

    let contentInset = ClipboardPanelMetrics.drawerHorizontalPadding
    let contentWidth = panelFrame.width - contentInset * 2
    guard contentWidth > 0 else {
      return nil
    }

    let minX = screenObstruction.minX - panelFrame.minX - contentInset
    let maxX = screenObstruction.maxX - panelFrame.minX - contentInset
    let clampedMinX = min(max(minX, 0), contentWidth)
    let clampedMaxX = min(max(maxX, clampedMinX), contentWidth)

    guard clampedMaxX > clampedMinX else {
      return nil
    }

    return PanelTopObstruction(minX: clampedMinX, maxX: clampedMaxX)
  }

  func topObstructionRect(on screen: NSScreen) -> NSRect? {
    guard let leftArea = screen.auxiliaryTopLeftArea,
          let rightArea = screen.auxiliaryTopRightArea,
          !leftArea.isEmpty,
          !rightArea.isEmpty else {
      return nil
    }

    let minX = leftArea.maxX
    let maxX = rightArea.minX
    let minY = min(leftArea.minY, rightArea.minY)
    let maxY = max(leftArea.maxY, rightArea.maxY)
    guard maxX > minX, maxY > minY, screen.safeAreaInsets.top > 0 else {
      return nil
    }

    return NSRect(
      x: minX,
      y: minY,
      width: maxX - minX,
      height: maxY - minY
    )
  }
}

private extension PanelCoordinator {
  static func screenContainingMouse() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
      return screen
    }
    return NSScreen.screens.min { first, second in
      first.frame.distanceSquared(to: mouseLocation) < second.frame.distanceSquared(to: mouseLocation)
    }
  }
}

private extension NSRect {
  func roundedToScreenPoints() -> NSRect {
    NSRect(
      x: minX.rounded(.toNearestOrAwayFromZero),
      y: minY.rounded(.toNearestOrAwayFromZero),
      width: width.rounded(.toNearestOrAwayFromZero),
      height: height.rounded(.toNearestOrAwayFromZero)
    )
  }

  func distanceSquared(to point: NSPoint) -> CGFloat {
    let closestX = min(max(point.x, minX), maxX)
    let closestY = min(max(point.y, minY), maxY)
    return pow(point.x - closestX, 2) + pow(point.y - closestY, 2)
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
