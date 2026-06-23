import SwiftUI

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
