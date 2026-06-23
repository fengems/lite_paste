import SwiftUI

struct SettingsPageStack<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      content
    }
  }
}

struct SettingsSectionCard<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(Color.primary.opacity(0.92))
        .padding(.leading, 2)

      VStack(spacing: 0) {
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .background(SettingsSurface.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(SettingsSurface.border.opacity(0.76), lineWidth: 1)
      )
      .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
