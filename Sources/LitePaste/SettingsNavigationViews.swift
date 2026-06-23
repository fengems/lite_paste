import SwiftUI

struct SettingsSidebarButton: View {
  let page: SettingsPage
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: page.systemImage)
          .font(.system(size: 13, weight: .semibold))
          .frame(width: 17)

        Text(page.title)
          .font(.system(size: 13, weight: .semibold))

        Spacer(minLength: 0)
      }
      .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.74))
      .padding(.horizontal, 11)
      .frame(height: 36)
      .background(sidebarBackground)
      .overlay(sidebarBorder)
      .overlay(alignment: .leading) {
        if isSelected {
          Capsule()
            .fill(page.accentColor.opacity(0.72))
            .frame(width: 3, height: 18)
            .padding(.leading, 3)
        }
      }
      .contentShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var sidebarBackground: some View {
    if isSelected {
      RoundedRectangle(cornerRadius: 8)
        .fill(page.accentColor.opacity(0.10))
    } else {
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.clear)
    }
  }

  @ViewBuilder
  private var sidebarBorder: some View {
    if isSelected {
      RoundedRectangle(cornerRadius: 8)
        .stroke(page.accentColor.opacity(0.18), lineWidth: 1)
    }
  }
}

struct SettingsPageHeader: View {
  let page: SettingsPage

  var body: some View {
    HStack(spacing: 9) {
      Image(systemName: page.systemImage)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(page.accentColor)
        .frame(width: 30, height: 30)
        .background(page.accentColor.opacity(0.075), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(page.accentColor.opacity(0.14), lineWidth: 1)
        )

      Text(page.title)
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(.primary)
    }
  }
}
