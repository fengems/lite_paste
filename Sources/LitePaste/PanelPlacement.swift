import AppKit
import LitePasteCore

@MainActor
enum PanelPlacement {
  static func position(
    _ panel: NSPanel,
    settings: AppSettings,
    presentationState: PanelPresentationState,
    edgePanelThickness: CGFloat
  ) {
    let isEdgeAttached = settings.panelPosition.isEdgeAttached
    panel.isMovableByWindowBackground = !isEdgeAttached
    (panel as? ClipboardPanelWindow)?.usesExactFramePlacement = isEdgeAttached
    applyLevel(to: panel, settings: settings)

    switch settings.panelPosition {
    case .edgeBottom, .edgeTop, .edgeLeft, .edgeRight, .bottomDrawer, .statusItem:
      positionEdgeAttached(
        panel,
        position: settings.panelPosition,
        coversMenuBar: settings.coverMenuBarWhenEdgeAttached,
        edgePanelThickness: edgePanelThickness,
        presentationState: presentationState
      )
    case .cursor:
      presentationState.updateTopObstruction(nil)
      positionNearMouse(panel)
    case .screenCenter, .mouseScreenCenter:
      presentationState.updateTopObstruction(nil)
      positionScreenCenter(panel)
    }
  }

  static func applyLevel(to panel: NSPanel, settings: AppSettings) {
    panel.level = settings.coverMenuBarWhenEdgeAttached ? .screenSaver : .floating
  }

  private static func positionEdgeAttached(
    _ panel: NSPanel,
    position: PanelPosition,
    coversMenuBar: Bool,
    edgePanelThickness: CGFloat,
    presentationState: PanelPresentationState
  ) {
    guard let screen = PanelGeometry.screenContainingMouse() ?? NSScreen.main else {
      panel.center()
      presentationState.updateTopObstruction(nil)
      return
    }

    let frame = PanelGeometry.edgeAttachedFrame(
      for: position,
      on: screen,
      coversMenuBar: coversMenuBar,
      edgePanelThickness: edgePanelThickness
    )
    .roundedToScreenPoints()
    panel.setFrame(frame, display: true)
    presentationState.updateTopObstruction(
      PanelGeometry.topObstruction(for: position, panelFrame: frame, on: screen)
    )
  }

  private static func positionNearMouse(_ panel: NSPanel) {
    guard let screen = PanelGeometry.screenContainingMouse() ?? NSScreen.main else {
      panel.center()
      return
    }

    let visibleFrame = screen.visibleFrame
    let size = PanelGeometry.floatingPanelSize(in: visibleFrame)
    let mouseLocation = NSEvent.mouseLocation
    let preferredOrigin = NSPoint(
      x: mouseLocation.x + 10,
      y: mouseLocation.y - size.height - 10
    )
    let origin = preferredOrigin.clamped(panelSize: size, to: visibleFrame)
    panel.setFrame(NSRect(origin: origin, size: size).roundedToScreenPoints(), display: true)
  }

  private static func positionScreenCenter(_ panel: NSPanel) {
    guard let screen = PanelGeometry.screenContainingMouse() ?? NSScreen.main else {
      panel.center()
      return
    }

    let visibleFrame = screen.visibleFrame
    let size = PanelGeometry.floatingPanelSize(in: visibleFrame)
    let origin = NSPoint(
      x: visibleFrame.midX - size.width / 2,
      y: visibleFrame.midY - size.height / 2
    )
    panel.setFrame(NSRect(origin: origin, size: size).roundedToScreenPoints(), display: true)
  }
}
