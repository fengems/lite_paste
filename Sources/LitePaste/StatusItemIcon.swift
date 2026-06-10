import AppKit

enum StatusItemIcon {
  static func makeImage() -> NSImage {
    let image = NSImage(size: NSSize(width: 18, height: 18))
    image.lockFocus()

    NSColor.black.setStroke()
    NSColor.black.setFill()

    let board = NSBezierPath(
      roundedRect: NSRect(x: 4.15, y: 2.65, width: 8.25, height: 10.7),
      xRadius: 1.85,
      yRadius: 1.85
    )
    board.fill()

    let boardNotch = NSBezierPath(
      roundedRect: NSRect(x: 5.95, y: 12.05, width: 4.75, height: 1.7),
      xRadius: 0.9,
      yRadius: 0.9
    )
    clear(boardNotch)

    let tab = NSBezierPath(ovalIn: NSRect(x: 6.75, y: 13.35, width: 3.95, height: 3.35))
    let clipBase = NSBezierPath(
      roundedRect: NSRect(x: 5.9, y: 12.25, width: 5.65, height: 2.6),
      xRadius: 0.9,
      yRadius: 0.9
    )

    tab.fill()
    clipBase.fill()

    let hole = NSBezierPath(ovalIn: NSRect(x: 7.95, y: 14.18, width: 1.55, height: 1.55))
    clear(hole)

    let lowerRightFoldCut = NSBezierPath()
    lowerRightFoldCut.move(to: CGPoint(x: 10.65, y: 2.6))
    lowerRightFoldCut.curve(
      to: CGPoint(x: 12.55, y: 5.3),
      controlPoint1: CGPoint(x: 11.8, y: 2.9),
      controlPoint2: CGPoint(x: 12.35, y: 3.85)
    )
    lowerRightFoldCut.line(to: CGPoint(x: 12.55, y: 2.6))
    lowerRightFoldCut.close()
    clear(lowerRightFoldCut)

    drawSparkle(center: CGPoint(x: 13.1, y: 4.4), radius: 2.35)

    image.unlockFocus()
    image.isTemplate = true
    return image
  }

  private static func clear(_ path: NSBezierPath) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current?.compositingOperation = .clear
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
  }

  private static func drawSparkle(center: CGPoint, radius: CGFloat) {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: center.x, y: center.y + radius))
    path.curve(
      to: CGPoint(x: center.x + radius, y: center.y),
      controlPoint1: CGPoint(x: center.x + radius * 0.18, y: center.y + radius * 0.34),
      controlPoint2: CGPoint(x: center.x + radius * 0.34, y: center.y + radius * 0.18)
    )
    path.curve(
      to: CGPoint(x: center.x, y: center.y - radius),
      controlPoint1: CGPoint(x: center.x + radius * 0.34, y: center.y - radius * 0.18),
      controlPoint2: CGPoint(x: center.x + radius * 0.18, y: center.y - radius * 0.34)
    )
    path.curve(
      to: CGPoint(x: center.x - radius, y: center.y),
      controlPoint1: CGPoint(x: center.x - radius * 0.18, y: center.y - radius * 0.34),
      controlPoint2: CGPoint(x: center.x - radius * 0.34, y: center.y - radius * 0.18)
    )
    path.curve(
      to: CGPoint(x: center.x, y: center.y + radius),
      controlPoint1: CGPoint(x: center.x - radius * 0.34, y: center.y + radius * 0.18),
      controlPoint2: CGPoint(x: center.x - radius * 0.18, y: center.y + radius * 0.34)
    )
    path.close()
    path.fill()
  }
}
