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

  var accentColor: Color {
    switch self {
    case .clipboard:
      Color.blue
    case .history:
      Color.cyan
    case .general:
      Color.indigo
    case .hotkeys:
      Color.purple
    case .backup:
      Color.orange
    case .about:
      Color.green
    }
  }
}

enum SettingsSurface {
  static let windowBackground = dynamicColor(
    light: NSColor(calibratedRed: 0.955, green: 0.968, blue: 0.985, alpha: 1),
    dark: NSColor(calibratedRed: 0.075, green: 0.088, blue: 0.115, alpha: 1)
  )
  static let sidebarBackground = dynamicColor(
    light: NSColor(calibratedRed: 0.925, green: 0.945, blue: 0.970, alpha: 0.92),
    dark: NSColor(calibratedRed: 0.090, green: 0.105, blue: 0.135, alpha: 0.92)
  )
  static let cardBackground = dynamicColor(
    light: NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 0.72),
    dark: NSColor(calibratedRed: 0.165, green: 0.180, blue: 0.215, alpha: 0.70)
  )
  static let fieldBackground = dynamicColor(
    light: NSColor(calibratedRed: 0.905, green: 0.925, blue: 0.955, alpha: 0.78),
    dark: NSColor(calibratedRed: 0.205, green: 0.220, blue: 0.260, alpha: 0.78)
  )
  static let separator = dynamicColor(
    light: NSColor(calibratedRed: 0.755, green: 0.790, blue: 0.835, alpha: 1),
    dark: NSColor(calibratedRed: 0.325, green: 0.345, blue: 0.390, alpha: 1)
  )
  static let border = separator.opacity(0.48)

  static var windowBackdrop: some View {
    windowBackground
      .overlay(
        LinearGradient(
          colors: [
            Color.cyan.opacity(0.055),
            Color.blue.opacity(0.025),
            Color.purple.opacity(0.035)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
  }

  static var sidebarBackdrop: some View {
    sidebarBackground
      .overlay(
        LinearGradient(
          colors: [
            Color.white.opacity(0.10),
            Color.blue.opacity(0.035),
            Color.black.opacity(0.035)
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      )
  }

  static var cardOverlay: some View {
    LinearGradient(
      colors: [
        Color.white.opacity(0.085),
        Color.cyan.opacity(0.020),
        Color.purple.opacity(0.018)
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .allowsHitTesting(false)
  }

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
            .fill(page.accentColor)
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
        .fill(
          LinearGradient(
            colors: [
              page.accentColor.opacity(0.20),
              Color.white.opacity(0.08)
            ],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
    } else {
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.clear)
    }
  }

  @ViewBuilder
  private var sidebarBorder: some View {
    if isSelected {
      RoundedRectangle(cornerRadius: 8)
        .stroke(page.accentColor.opacity(0.32), lineWidth: 1)
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
        .background(page.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(page.accentColor.opacity(0.25), lineWidth: 1)
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
      .overlay(SettingsSurface.cardOverlay.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(
            LinearGradient(
              colors: [
                Color.white.opacity(0.18),
                SettingsSurface.border
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 1
          )
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
