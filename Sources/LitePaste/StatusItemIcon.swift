import AppKit

enum StatusItemIcon {
  static func makeImage() -> NSImage {
    let image = NSImage(size: NSSize(width: 18, height: 18))
    image.lockFocus()

    NSColor.black.setStroke()
    NSColor.black.setFill()

    let board = NSBezierPath(
      roundedRect: NSRect(x: 4.25, y: 2.75, width: 9.5, height: 12.5),
      xRadius: 2.1,
      yRadius: 2.1
    )
    board.lineWidth = 1.55
    board.stroke()

    let clip = NSBezierPath(
      roundedRect: NSRect(x: 6.3, y: 13.15, width: 5.4, height: 2.45),
      xRadius: 1.1,
      yRadius: 1.1
    )
    clip.fill()

    drawLine(from: CGPoint(x: 6.4, y: 10.6), to: CGPoint(x: 11.6, y: 10.6))
    drawLine(from: CGPoint(x: 6.4, y: 8.15), to: CGPoint(x: 11.6, y: 8.15))
    drawLine(from: CGPoint(x: 6.4, y: 5.7), to: CGPoint(x: 9.8, y: 5.7))

    image.unlockFocus()
    image.isTemplate = true
    return image
  }

  private static func drawLine(from start: CGPoint, to end: CGPoint) {
    let line = NSBezierPath()
    line.move(to: start)
    line.line(to: end)
    line.lineWidth = 1.25
    line.lineCapStyle = .round
    line.stroke()
  }
}
