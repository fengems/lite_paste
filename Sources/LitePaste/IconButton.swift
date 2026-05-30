import SwiftUI

struct IconButton: View {
  let systemName: String
  let accessibilityLabel: String
  var isActive = false
  var tint: Color = .accentColor
  var size: CGFloat = 26
  var iconSize: CGFloat = 13
  var cornerRadius: CGFloat = 7
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: iconSize, weight: .semibold))
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .foregroundStyle(isActive ? tint : Color.secondary)
        .background(
          (isActive ? tint.opacity(0.16) : Color.primary.opacity(0.055)),
          in: RoundedRectangle(cornerRadius: cornerRadius)
        )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
    .panelTooltip(accessibilityLabel)
  }
}
