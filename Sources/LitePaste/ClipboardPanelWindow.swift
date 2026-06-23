import AppKit

final class ClipboardPanelWindow: NSPanel {
  var usesExactFramePlacement = false

  override var canBecomeKey: Bool {
    true
  }

  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    usesExactFramePlacement ? frameRect : super.constrainFrameRect(frameRect, to: screen)
  }
}
