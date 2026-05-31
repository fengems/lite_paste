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
      AppText.value("剪贴板", "Clipboard")
    case .history:
      AppText.value("历史记录", "History")
    case .general:
      AppText.value("通用设置", "General")
    case .hotkeys:
      AppText.value("快捷键", "Shortcuts")
    case .backup:
      AppText.value("数据备份", "Backups")
    case .about:
      AppText.value("关于", "About")
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

  var accentColor: Color {
    switch self {
    case .clipboard:
      Color(nsColor: NSColor(calibratedRed: 0.34, green: 0.48, blue: 0.68, alpha: 1))
    case .history:
      Color(nsColor: NSColor(calibratedRed: 0.30, green: 0.56, blue: 0.62, alpha: 1))
    case .general:
      Color(nsColor: NSColor(calibratedRed: 0.43, green: 0.47, blue: 0.66, alpha: 1))
    case .hotkeys:
      Color(nsColor: NSColor(calibratedRed: 0.54, green: 0.43, blue: 0.64, alpha: 1))
    case .backup:
      Color(nsColor: NSColor(calibratedRed: 0.67, green: 0.49, blue: 0.32, alpha: 1))
    case .about:
      Color(nsColor: NSColor(calibratedRed: 0.38, green: 0.57, blue: 0.42, alpha: 1))
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
