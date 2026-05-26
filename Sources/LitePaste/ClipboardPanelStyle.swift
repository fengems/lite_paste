import LitePasteCore
import SwiftUI

enum ClipboardPanelMetrics {
  static let cornerRadius: CGFloat = 12
  static let cardCornerRadius: CGFloat = 8
  static let compactCornerRadius: CGFloat = 8
  static let cardWidth: CGFloat = 260
  static let cardHeight: CGFloat = 184
  static let cardContentTopPadding: CGFloat = 1
  static let cardContentBottomPadding: CGFloat = 16
  static let cardContentHeight: CGFloat = cardHeight + cardContentTopPadding + cardContentBottomPadding
  static let toolbarHeightAllowance: CGFloat = 46
  static let drawerHorizontalPadding: CGFloat = 10
  static let drawerVerticalPadding: CGFloat = 10
  static let panelContentSpacing: CGFloat = 8
  static let edgeScreenPadding: CGFloat = cardContentBottomPadding
  static let edgePanelThickness: CGFloat = cardContentHeight + toolbarHeightAllowance + panelContentSpacing + drawerVerticalPadding * 2
}

struct ClipboardFilterChip: View {
  let filter: ClipboardFilter
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(filter.displayName, systemImage: filter.iconName)
        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(backgroundStyle, in: Capsule())
        .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.82))
        .overlay(
          Capsule()
            .stroke(isSelected ? Color.clear : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
  }

  private var backgroundStyle: Color {
    isSelected ? filter.accentColor : Color.primary.opacity(0.055)
  }
}

struct PanelStatusBadge: View {
  let message: String

  var body: some View {
    Label(message, systemImage: "checkmark.circle.fill")
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, 9)
      .padding(.vertical, 6)
      .background(Color.green.gradient, in: Capsule())
      .shadow(color: Color.green.opacity(0.22), radius: 8, y: 3)
      .transition(.opacity.combined(with: .move(edge: .top)))
  }
}

extension ClipboardFilter {
  var iconName: String {
    switch self {
    case .all:
      "square.grid.2x2"
    case .text:
      "text.alignleft"
    case .images:
      "photo"
    case .files:
      "folder"
    case .links:
      "link"
    case .colors:
      "paintpalette"
    case .favorites:
      "star"
    case .pinned:
      "pin"
    }
  }

  var accentColor: Color {
    switch self {
    case .all:
      Color.blue
    case .text:
      Color.indigo
    case .images:
      Color.cyan
    case .files:
      Color.orange
    case .links:
      Color.blue
    case .colors:
      Color.green
    case .favorites:
      Color.yellow
    case .pinned:
      Color.purple
    }
  }
}

extension ClipboardKind {
  var accentColor: Color {
    switch self {
    case .text, .richText, .html:
      Color.indigo
    case .image:
      Color.cyan
    case .files:
      Color.orange
    case .url, .email:
      Color.blue
    case .color:
      Color.green
    case .unknown:
      Color.secondary
    }
  }
}
