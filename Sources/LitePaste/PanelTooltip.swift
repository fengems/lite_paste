import SwiftUI

private struct PanelTooltipModifier: ViewModifier {
  let text: String

  @State private var hoverToken = UUID()
  @State private var isHovering = false
  @State private var isVisible = false

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .bottom) {
        if isVisible {
          PanelTooltipBubble(text: text)
            .offset(y: 30)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .allowsHitTesting(false)
        }
      }
      .onHover(perform: handleHover)
      .zIndex(isVisible ? 1_000 : 0)
  }

  private func handleHover(_ hovering: Bool) {
    isHovering = hovering
    hoverToken = UUID()
    let token = hoverToken

    if hovering {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
        guard isHovering, hoverToken == token else {
          return
        }
        withAnimation(.easeOut(duration: 0.1)) {
          isVisible = true
        }
      }
    } else {
      withAnimation(.easeOut(duration: 0.08)) {
        isVisible = false
      }
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

extension View {
  func panelTooltip(_ text: String) -> some View {
    modifier(PanelTooltipModifier(text: text))
  }
}
