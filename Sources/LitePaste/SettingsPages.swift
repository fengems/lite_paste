import AppKit
import LitePasteCore
import SwiftUI

struct AppearanceSettingsPage: View {
  @Binding var interfaceLanguage: AppLanguage
  @Binding var themeMode: AppThemeMode

  var body: some View {
    SettingsPageStack {
      SettingsSectionCard(title: AppText.value("外观设置", "Appearance")) {
        SettingsRow(title: AppText.value("界面语言", "Interface Language")) {
          Picker("", selection: $interfaceLanguage) {
            ForEach(AppLanguage.allCases) { language in
              Text(language.localizedDisplayName).tag(language)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .controlSize(.regular)
          .frame(width: SettingsControlMetrics.menuWidth, alignment: .trailing)
        }

        SettingsDivider()

        SettingsRow(title: AppText.value("主题模式", "Theme")) {
          Picker("", selection: $themeMode) {
            ForEach(AppThemeMode.allCases) { mode in
              Text(mode.localizedDisplayName).tag(mode)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .controlSize(.regular)
          .frame(width: SettingsControlMetrics.menuWidth, alignment: .trailing)
        }
      }
    }
  }
}

struct HotkeySettingsPage: View {
  @Binding var panelHotkey: String

  var body: some View {
    SettingsPageStack {
      SettingsSectionCard(title: AppText.value("全局快捷键", "Global Shortcut")) {
        SettingsRow(title: AppText.value("打开面板", "Open Panel")) {
          Picker("", selection: $panelHotkey) {
            ForEach(PanelHotkeyCatalog.hotkeys, id: \.self) { hotkey in
              Text(PanelHotkeyCatalog.displayName(for: hotkey)).tag(hotkey)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .controlSize(.regular)
          .frame(width: SettingsControlMetrics.menuWidth, alignment: .trailing)
        }
      }

      SettingsSectionCard(title: AppText.value("面板快捷键", "Panel Shortcuts")) {
        SettingsInfoRow(title: AppText.value("快速粘贴", "Quick Paste"), value: AppText.value("⌘1 到 ⌘9", "⌘1 to ⌘9"))
        SettingsDivider()
        SettingsInfoRow(title: AppText.value("行首/行尾", "Row Start/End"), value: AppText.value("⌘← / ⌘→", "⌘← / ⌘→"))
        SettingsDivider()
        SettingsInfoRow(title: AppText.value("确认粘贴", "Paste Selected"), value: "Return")
        SettingsDivider()
        SettingsInfoRow(title: AppText.value("复制条目", "Copy Selected"), value: "⌘C")
        SettingsDivider()
        SettingsInfoRow(title: AppText.value("删除条目", "Delete Selected"), value: "Delete")
      }
    }
  }
}

struct BackupSettingsPage: View {
  let exportBackup: () -> Void
  let mergeImport: () -> Void
  let replaceImport: () -> Void
  let iCloudStatusText: String
  let refreshICloudStatus: () -> Void
  let exportICloudBackup: () -> Void
  let mergeImportICloudBackup: () -> Void
  let replaceImportICloudBackup: () -> Void
  let revealICloudBackupsDirectory: () -> Void

  var body: some View {
    SettingsPageStack {
      SettingsSectionCard(title: AppText.value("数据备份", "Local Backups")) {
        SettingsActionRow {
          Button(action: exportBackup) {
            Label(AppText.value("导出", "Export"), systemImage: "square.and.arrow.up")
          }

          Button(action: mergeImport) {
            Label(AppText.value("合并导入", "Merge Import"), systemImage: "arrow.triangle.merge")
          }

          Button(action: replaceImport) {
            Label(AppText.value("覆盖导入", "Replace Import"), systemImage: "arrow.down.doc")
          }
        }
      }

      SettingsSectionCard(title: AppText.value("iCloud 备份", "iCloud Backup")) {
        SettingsInfoRow(title: AppText.value("状态", "Status"), value: iCloudStatusText)

        SettingsDivider()

        SettingsActionRow {
          Button(action: exportICloudBackup) {
            Label(AppText.value("备份到 iCloud", "Back Up To iCloud"), systemImage: "icloud.and.arrow.up")
          }

          Button(action: refreshICloudStatus) {
            Label(AppText.value("刷新", "Refresh"), systemImage: "arrow.clockwise")
          }

          Button(action: revealICloudBackupsDirectory) {
            Label(AppText.value("显示目录", "Show Folder"), systemImage: "folder")
          }
        }

        SettingsDivider()

        SettingsActionRow {
          Button(action: mergeImportICloudBackup) {
            Label(AppText.value("从 iCloud 合并", "Merge From iCloud"), systemImage: "icloud.and.arrow.down")
          }

          Button(action: replaceImportICloudBackup) {
            Label(AppText.value("从 iCloud 覆盖", "Replace From iCloud"), systemImage: "arrow.down.doc")
          }
        }
      }
    }
  }
}

struct AboutSettingsPage: View {
  var body: some View {
    SettingsPageStack {
      SettingsSectionCard(title: AppText.value("应用信息", "App Info")) {
        SettingsInfoRow(title: AppText.value("应用", "App"), value: AppMetadata.displayName)
        SettingsDivider()
        SettingsInfoRow(title: AppText.value("版本", "Version"), value: AppMetadata.versionSummary)
        SettingsDivider()
        SettingsInfoRow(title: "Bundle ID", value: AppMetadata.bundleIdentifier)
        SettingsDivider()
        SettingsInfoRow(title: AppText.value("最低系统", "Minimum macOS"), value: "macOS \(AppMetadata.minimumMacOSVersion)+")
        SettingsDivider()
        SettingsInfoRow(title: AppText.value("许可证", "License"), value: AppMetadata.licenseName)
        SettingsDivider()
        SettingsActionRow {
          Button {
            NSWorkspace.shared.open(AppMetadata.repositoryURL)
          } label: {
            Label(AppText.value("打开项目仓库", "Open Repository"), systemImage: "arrow.up.right.square")
          }
        }
      }
    }
  }
}
