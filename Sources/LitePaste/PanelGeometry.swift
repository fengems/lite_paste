import AppKit
import LitePasteCore

enum PanelGeometry {
  static func topObstruction(for position: PanelPosition, panelFrame: NSRect, on screen: NSScreen) -> PanelTopObstruction? {
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

  static func edgeAttachedFrame(
    for position: PanelPosition,
    on screen: NSScreen,
    coversMenuBar: Bool,
    edgePanelThickness: CGFloat
  ) -> NSRect {
    let displayFrame = screen.frame
    let visibleFrame = screen.visibleFrame
    let thickness = clampedEdgePanelThickness(edgePanelThickness, for: visibleFrame)

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
    case .cursor, .screenCenter, .mouseScreenCenter:
      return NSRect(origin: visibleFrame.origin, size: floatingPanelSize(in: visibleFrame))
    }
  }

  static func floatingPanelSize(in visibleFrame: NSRect) -> NSSize {
    let width = min(max(visibleFrame.width * 0.56, min(760, visibleFrame.width)), min(920, visibleFrame.width))
    let height = min(max(visibleFrame.height * 0.5, min(420, visibleFrame.height)), min(560, visibleFrame.height))
    return NSSize(width: width, height: height)
  }

  static func screenContainingMouse() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
      return screen
    }
    return NSScreen.screens.min { first, second in
      first.frame.distanceSquared(to: mouseLocation) < second.frame.distanceSquared(to: mouseLocation)
    }
  }

  private static func topObstructionRect(on screen: NSScreen) -> NSRect? {
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

  private static func sideEdgeWidth(in visibleFrame: NSRect) -> CGFloat {
    min(max(visibleFrame.width * 0.38, min(420, visibleFrame.width)), min(760, visibleFrame.width))
  }

  private static func clampedEdgePanelThickness(_ thickness: CGFloat, for visibleFrame: NSRect) -> CGFloat {
    let minimumThickness = ClipboardPanelMetrics.edgePanelThickness
    return min(max(thickness, minimumThickness), max(minimumThickness, visibleFrame.height * 0.62))
  }
}

extension NSRect {
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

extension NSPoint {
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
