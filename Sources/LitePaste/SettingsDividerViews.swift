import SwiftUI

struct SettingsDivider: View {
  var body: some View {
    Rectangle()
      .fill(SettingsSurface.separator.opacity(0.42))
      .frame(height: 1)
  }
}

struct SettingsVerticalDivider: View {
  var body: some View {
    Rectangle()
      .fill(SettingsSurface.separator.opacity(0.48))
      .frame(width: 1)
  }
}
