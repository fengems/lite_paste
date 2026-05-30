import SwiftUI

struct IconButton: View {
  let systemName: String
  let accessibilityLabel: String
  var isActive = false
  var tint: Color = .accentColor
  var size: CGFloat = 26
  var iconSize: CGFloat = 13
  var cornerRadius: CGFloat = 7
  var showsInactiveBackground = true
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

      Image(systemName: systemName)
        .font(.system(size: iconSize, weight: .semibold))
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .foregroundStyle(isActive ? tint : Color.secondary)
        .background(backgroundColor, in: shape)
        .overlay(
          shape.stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: isActive ? tint.opacity(0.18) : .clear, radius: 7, y: 2)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
    .panelTooltip(accessibilityLabel)
  }

  private var backgroundColor: Color {
    if isActive {
      return tint.opacity(0.18)
    }
    return showsInactiveBackground ? Color.primary.opacity(0.055) : Color.clear
  }

  private var borderColor: Color {
    if isActive {
      return tint.opacity(0.35)
    }
    return showsInactiveBackground ? Color.white.opacity(0.08) : Color.clear
  }
}
