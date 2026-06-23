import LitePasteCore
import SwiftUI

struct GeneralSettingsPage: View {
  @Binding var launchAtLogin: Bool
  @Binding var showMenuBarIcon: Bool
  @Binding var showDockIcon: Bool
  let recordingStatusTitle: String
  let currentApplicationTitle: String
  let statusErrorMessage: String?
  let historyPersistenceErrorMessage: String?
  let settingsSaveErrorMessage: String?
  let accessibilityStatusTitle: String
  let accessibilityTrusted: Bool
  let requestAccessibilityPermission: () -> Void
  let openAccessibilitySettings: () -> Void
  let refreshAccessibilityStatus: () -> Void

  var body: some View {
    SettingsPageStack {
      SettingsSectionCard(title: AppText.value("应用设置", "App")) {
        SettingsSwitchRow(title: AppText.value("开机启动", "Launch At Login"), isOn: $launchAtLogin)
        SettingsDivider()
        SettingsSwitchRow(
          title: AppText.value("显示菜单栏图标", "Show Menu Bar Icon"),
          detail: AppText.value(
            "关闭后仍可通过全局快捷键打开面板。",
            "When hidden, the panel can still be opened with the global shortcut."
          ),
          isOn: $showMenuBarIcon
        )
        SettingsDivider()
        SettingsSwitchRow(
          title: AppText.value("显示 Dock 图标", "Show Dock Icon"),
          detail: AppText.value(
            "菜单栏和 Dock 至少保留一个可见入口。",
            "At least one visible entry point is kept between the menu bar and Dock."
          ),
          isOn: $showDockIcon
        )
      }

      SettingsSectionCard(title: AppText.value("运行状态", "Status")) {
        SettingsInfoRow(title: AppText.value("剪贴板记录", "Clipboard Recording"), value: recordingStatusTitle)
        SettingsDivider()
        SettingsInfoRow(title: AppText.value("最近应用", "Recent App"), value: currentApplicationTitle)

        if let statusErrorMessage {
          SettingsDivider()
          SettingsWarningRow(message: statusErrorMessage)
        }

        if let historyPersistenceErrorMessage {
          SettingsDivider()
          SettingsWarningRow(message: historyPersistenceErrorMessage)
        }

        if let settingsSaveErrorMessage {
          SettingsDivider()
          SettingsWarningRow(message: settingsSaveErrorMessage)
        }
      }

      SettingsSectionCard(title: AppText.value("权限", "Permissions")) {
        SettingsInfoRow(
          title: AppText.value("辅助功能", "Accessibility"),
          value: accessibilityStatusTitle,
          systemImage: accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
          tint: accessibilityTrusted ? .green : .orange
        )

        SettingsDivider()

        SettingsActionRow {
          Button(action: requestAccessibilityPermission) {
            Label(AppText.value("请求权限", "Request Permission"), systemImage: "hand.raised")
          }

          Button(action: openAccessibilitySettings) {
            Label(AppText.value("打开系统设置", "Open System Settings"), systemImage: "gearshape")
          }

          Button(action: refreshAccessibilityStatus) {
            Label(AppText.value("刷新", "Refresh"), systemImage: "arrow.clockwise")
          }
        }
      }
    }
  }
}
