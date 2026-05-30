import AppKit
import SwiftUI

private struct PanelTooltipModifier: ViewModifier {
  private static let showDelay: TimeInterval = 0.35

  let text: String

  @State private var hoverToken = UUID()
  @State private var isHovering = false
  @State private var anchorView: NSView?

  func body(content: Content) -> some View {
    content
      .background {
        PanelTooltipAnchorView { view in
          anchorView = view
        }
      }
      .onHover(perform: handleHover)
      .onDisappear {
        hideTooltip()
      }
  }

  private func handleHover(_ hovering: Bool) {
    isHovering = hovering
    hoverToken = UUID()
    let token = hoverToken

    if hovering {
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.showDelay) {
        showTooltipIfNeeded(token: token)
      }
    } else {
      hideTooltip()
    }
  }

  private func showTooltipIfNeeded(token: UUID) {
    guard isHovering, hoverToken == token, let anchorView else {
      return
    }

    Task { @MainActor in
      guard isHovering, hoverToken == token, let anchorRect = anchorView.screenRect else {
        return
      }

      PanelTooltipController.shared.show(text: text, anchorRect: anchorRect)
    }
  }

  private func hideTooltip() {
    Task { @MainActor in
      PanelTooltipController.shared.hide()
    }
  }
}

private struct PanelTooltipAnchorView: NSViewRepresentable {
  let onResolve: (NSView) -> Void

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      onResolve(view)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    DispatchQueue.main.async {
      onResolve(nsView)
    }
  }
}

private struct PanelTooltipBubble: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: 11, weight: .medium))
      .foregroundStyle(.white)
      .lineLimit(1)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(Color.black.opacity(0.78), in: Capsule())
      .shadow(color: Color.black.opacity(0.2), radius: 6, y: 2)
      .fixedSize()
      .accessibilityHidden(true)
  }
}

@MainActor
private final class PanelTooltipController {
  static let shared = PanelTooltipController()

  private let screenPadding: CGFloat = 6
  private let tooltipSpacing: CGFloat = 8
  private var panel: NSPanel?

  func show(text: String, anchorRect: NSRect) {
    let hostingController = NSHostingController(rootView: PanelTooltipBubble(text: text))
    hostingController.view.layoutSubtreeIfNeeded()

    let fittingSize = hostingController.view.fittingSize
    let size = NSSize(
      width: ceil(max(fittingSize.width, 1)),
      height: ceil(max(fittingSize.height, 1))
    )
    let tooltipPanel = panel ?? makePanel()
    panel = tooltipPanel
    tooltipPanel.contentViewController = hostingController
    tooltipPanel.setFrame(frame(for: size, anchorRect: anchorRect), display: true)
    tooltipPanel.orderFront(nil)
  }

  func hide() {
    panel?.orderOut(nil)
  }

  private func makePanel() -> NSPanel {
    let panel = NSPanel(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = false
    panel.ignoresMouseEvents = true
    panel.isReleasedWhenClosed = false
    panel.level = .screenSaver
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    return panel
  }

  private func frame(for size: NSSize, anchorRect: NSRect) -> NSRect {
    let screenFrame = screenFrame(containing: anchorRect)
    let x = clamped(
      anchorRect.midX - size.width / 2,
      lowerBound: screenFrame.minX + screenPadding,
      upperBound: screenFrame.maxX - size.width - screenPadding
    )
    let preferredY = preferredY(for: size, anchorRect: anchorRect, screenFrame: screenFrame)
    let y = clamped(
      preferredY,
      lowerBound: screenFrame.minY + screenPadding,
      upperBound: screenFrame.maxY - size.height - screenPadding
    )

    return NSRect(x: x, y: y, width: size.width, height: size.height)
  }

  private func preferredY(for size: NSSize, anchorRect: NSRect, screenFrame: NSRect) -> CGFloat {
    let aboveY = anchorRect.maxY + tooltipSpacing
    let aboveFits = aboveY + size.height <= screenFrame.maxY - screenPadding
    if aboveFits {
      return aboveY
    }

    return anchorRect.minY - tooltipSpacing - size.height
  }

  private func screenFrame(containing rect: NSRect) -> NSRect {
    let screen = NSScreen.screens.first { screen in
      screen.frame.intersects(rect) || screen.frame.contains(NSPoint(x: rect.midX, y: rect.midY))
    } ?? NSScreen.main
    return screen?.visibleFrame ?? screen?.frame ?? rect
  }

  private func clamped(_ value: CGFloat, lowerBound: CGFloat, upperBound: CGFloat) -> CGFloat {
    min(max(value, lowerBound), max(lowerBound, upperBound))
  }
}

@MainActor
private extension NSView {
  var screenRect: NSRect? {
    guard let window else {
      return nil
    }

    return window.convertToScreen(convert(bounds, to: nil))
  }
}

extension View {
  func panelTooltip(_ text: String) -> some View {
    modifier(PanelTooltipModifier(text: text))
  }
}
