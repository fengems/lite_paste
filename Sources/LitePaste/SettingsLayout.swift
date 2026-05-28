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
  static let contentBackground = Color(nsColor: .windowBackgroundColor)
  static let sidebarBackground = Color(nsColor: .underPageBackgroundColor)
  static let cardBackground = Color(nsColor: .controlBackgroundColor).opacity(0.72)
  static let rowHover = Color.primary.opacity(0.04)
  static let border = Color.primary.opacity(0.09)
}

struct SettingsSidebarButton: View {
  let page: SettingsPage
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: page.systemImage)
          .font(.system(size: 17, weight: .semibold))
          .frame(width: 22)

        Text(page.title)
          .font(.system(size: 15, weight: .semibold))

        Spacer(minLength: 0)
      }
      .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.72))
      .padding(.horizontal, 14)
      .frame(height: 46)
      .background(
        RoundedRectangle(cornerRadius: 10)
          .fill(isSelected ? Color.accentColor : Color.clear)
      )
      .contentShape(RoundedRectangle(cornerRadius: 10))
    }
    .buttonStyle(.plain)
  }
}

struct SettingsPageHeader: View {
  let page: SettingsPage

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: page.systemImage)
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(Color.accentColor)

      Text(page.title)
        .font(.system(size: 24, weight: .bold))
        .foregroundStyle(.primary)
    }
  }
}

struct SettingsPageStack<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      content
    }
  }
}

struct SettingsSectionCard<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(.primary)
        .padding(.leading, 2)

      VStack(spacing: 0) {
        content
      }
      .background(SettingsSurface.cardBackground, in: RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
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
    HStack(alignment: .center, spacing: 18) {
      VStack(alignment: .leading, spacing: 5) {
        Text(title)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.primary)

        if let detail {
          Text(detail)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }

      Spacer(minLength: 20)

      control
        .controlSize(.regular)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .frame(minHeight: 58)
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
    }
  }
}

struct SettingsInfoRow: View {
  let title: String
  let value: String
  var systemImage: String?
  var tint: Color = .secondary

  var body: some View {
    HStack(spacing: 12) {
      Text(title)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.primary)

      Spacer(minLength: 20)

      if let systemImage {
        Image(systemName: systemImage)
          .foregroundStyle(tint)
      }

      Text(value)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .frame(minHeight: 52)
  }
}

struct SettingsWarningRow: View {
  let message: String

  var body: some View {
    Label(message, systemImage: "exclamationmark.triangle.fill")
      .font(.system(size: 13, weight: .medium))
      .foregroundStyle(.orange)
      .lineLimit(2)
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct SettingsActionRow<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    HStack(spacing: 10) {
      content
    }
    .buttonStyle(.bordered)
    .controlSize(.regular)
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct SettingsDivider: View {
  var body: some View {
    Divider()
      .opacity(0.65)
  }
}
