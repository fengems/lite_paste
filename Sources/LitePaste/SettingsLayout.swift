import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
  case clipboard
  case history
  case general
  case hotkeys
  case backup
  case about

  var id: String {
    rawValue
  }

  var title: String {
    switch self {
    case .clipboard:
      "剪贴板"
    case .history:
      "历史记录"
    case .general:
      "通用设置"
    case .hotkeys:
      "快捷键"
    case .backup:
      "数据备份"
    case .about:
      "关于"
    }
  }

  var systemImage: String {
    switch self {
    case .clipboard:
      "clipboard"
    case .history:
      "clock.arrow.circlepath"
    case .general:
      "gearshape"
    case .hotkeys:
      "keyboard"
    case .backup:
      "externaldrive"
    case .about:
      "info.circle"
    }
  }
}

enum SettingsSurface {
  static let windowBackground = dynamicColor(
    light: NSColor(calibratedWhite: 0.99, alpha: 1),
    dark: NSColor(calibratedWhite: 0.145, alpha: 1)
  )
  static let sidebarBackground = dynamicColor(
    light: NSColor(calibratedWhite: 0.985, alpha: 1),
    dark: NSColor(calibratedWhite: 0.13, alpha: 1)
  )
  static let cardBackground = dynamicColor(
    light: NSColor(calibratedWhite: 0.965, alpha: 1),
    dark: NSColor(calibratedWhite: 0.165, alpha: 1)
  )
  static let fieldBackground = dynamicColor(
    light: NSColor(calibratedWhite: 0.925, alpha: 1),
    dark: NSColor(calibratedWhite: 0.195, alpha: 1)
  )
  static let selectedSidebarBackground = Color(nsColor: .selectedContentBackgroundColor)
  static let separator = dynamicColor(
    light: NSColor(calibratedWhite: 0.875, alpha: 1),
    dark: NSColor(calibratedWhite: 0.22, alpha: 1)
  )
  static let border = separator.opacity(0.48)

  private static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
      let mode = appearance.bestMatch(from: [.darkAqua, .aqua])
      return mode == .darkAqua ? dark : light
    })
  }
}

enum SettingsControlMetrics {
  static let columnWidth: CGFloat = 176
  static let menuWidth: CGFloat = columnWidth
  static let segmentedWidth: CGFloat = columnWidth
  static let actionButtonControlSize: ControlSize = .large
}

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
      .foregroundStyle(isSelected ? Color.white : Color.primary)
      .padding(.horizontal, 10)
      .frame(height: 36)
      .background(sidebarBackground)
      .overlay(sidebarBorder)
      .contentShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var sidebarBackground: some View {
    if isSelected {
      RoundedRectangle(cornerRadius: 8)
        .fill(SettingsSurface.selectedSidebarBackground)
    } else {
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.clear)
    }
  }

  @ViewBuilder
  private var sidebarBorder: some View {
    if isSelected {
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.white.opacity(0.10), lineWidth: 1)
    }
  }
}

struct SettingsPageHeader: View {
  let page: SettingsPage

  var body: some View {
    HStack(spacing: 9) {
      Image(systemName: page.systemImage)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(Color.accentColor)

      Text(page.title)
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(.primary)
    }
  }
}

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
        .foregroundStyle(.primary)
        .padding(.leading, 2)

      VStack(spacing: 0) {
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(SettingsSurface.cardBackground, in: RoundedRectangle(cornerRadius: 14))
      .overlay(
        RoundedRectangle(cornerRadius: 14)
          .stroke(SettingsSurface.border, lineWidth: 1)
      )
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct SettingsRow<Control: View>: View {
  let title: String
  var detail: String?
  @ViewBuilder var control: Control

  init(title: String, detail: String? = nil, @ViewBuilder control: () -> Control) {
    self.title = title
    self.detail = detail
    self.control = control()
  }

  var body: some View {
    HStack(alignment: .center, spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.primary)

        if let detail {
          Text(detail)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Spacer(minLength: 16)

      control
        .frame(width: SettingsControlMetrics.columnWidth, alignment: .trailing)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(minHeight: 48)
  }
}

struct SettingsSwitchRow: View {
  let title: String
  var detail: String?
  @Binding var isOn: Bool

  var body: some View {
    SettingsRow(title: title, detail: detail) {
      Toggle("", isOn: $isOn)
        .labelsHidden()
        .toggleStyle(.switch)
        .controlSize(.small)
    }
  }
}

struct SettingsInfoRow: View {
  let title: String
  let value: String
  var systemImage: String?
  var tint: Color = .secondary

  var body: some View {
    HStack(spacing: 10) {
      Text(title)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.primary)

      Spacer(minLength: 16)

      if let systemImage {
        Image(systemName: systemImage)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(tint)
      }

      Text(value)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .frame(minHeight: 46)
  }
}

struct SettingsWarningRow: View {
  let message: String

  var body: some View {
    Label(message, systemImage: "exclamationmark.triangle.fill")
      .font(.system(size: 12, weight: .medium))
      .foregroundStyle(.orange)
      .lineLimit(2)
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct SettingsActionRow<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    HStack(spacing: 12) {
      content
    }
    .buttonStyle(.bordered)
    .controlSize(SettingsControlMetrics.actionButtonControlSize)
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct SettingsDivider: View {
  var body: some View {
    Rectangle()
      .fill(SettingsSurface.separator.opacity(0.68))
      .frame(height: 1)
  }
}

struct SettingsVerticalDivider: View {
  var body: some View {
    Rectangle()
      .fill(SettingsSurface.separator.opacity(0.82))
      .frame(width: 1)
  }
}
