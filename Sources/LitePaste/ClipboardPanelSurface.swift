import SwiftUI

struct ClipboardPanelSurface<Content: View>: View {
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    ZStack {
      VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
        .ignoresSafeArea()
      content
    }
    .clipShape(cornerShape)
    .overlay(innerGlow)
    .overlay(border)
    .shadow(color: Color.black.opacity(0.20), radius: 18, y: 8)
  }

  private var cornerShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: ClipboardPanelMetrics.cornerRadius, style: .continuous)
  }

  private var border: some View {
    cornerShape
      .stroke(
        LinearGradient(
          colors: [
            Color.cyan.opacity(0.75),
            Color.blue.opacity(0.55),
            Color.purple.opacity(0.48),
            Color.orange.opacity(0.70)
          ],
          startPoint: .bottomLeading,
          endPoint: .topTrailing
        ),
        lineWidth: 1.4
      )
  }

  private var innerGlow: some View {
    cornerShape
      .stroke(
        LinearGradient(
          colors: [
            Color.cyan.opacity(0.45),
            Color.blue.opacity(0.28),
            Color.purple.opacity(0.24),
            Color.orange.opacity(0.38)
          ],
          startPoint: .bottomLeading,
          endPoint: .topTrailing
        ),
        lineWidth: 5
      )
      .blur(radius: 7)
      .opacity(0.62)
      .clipShape(cornerShape)
      .allowsHitTesting(false)
  }
}
