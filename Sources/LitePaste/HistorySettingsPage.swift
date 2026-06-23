import LitePasteCore
import SwiftUI

struct HistorySettingsPage: View {
  @Binding var maxHistoryCount: Int
  @Binding var retentionDays: Int
  @Binding var preserveLargeRichTextFormats: Bool
  @Binding var isMonitoringPaused: Bool
  let historyCountText: String
  let storageSizeText: String
  let refreshStatus: () -> Void
  let revealDataDirectory: () -> Void

  var body: some View {
    SettingsPageStack {
      historySettingsCard
      monitoringSettingsCard
      dataStatusCard
    }
  }

  private var historySettingsCard: some View {
    SettingsSectionCard(title: AppText.value("历史设置", "History")) {
      SettingsRow(
        title: AppText.value("最大历史数量", "Maximum Items"),
        detail: AppText.value("超过数量后会自动清理旧记录。", "Older items are removed automatically after this limit.")
      ) {
        SettingsNumberStepperField(
          value: $maxHistoryCount,
          range: 50...10_000,
          step: 50,
          unit: AppText.value("条", "items")
        )
      }

      SettingsDivider()

      SettingsRow(
        title: AppText.value("历史保留", "Retention"),
        detail: AppText.value("输入 0 表示永久，不会按天数清理。", "Use 0 to keep history permanently.")
      ) {
        SettingsNumberStepperField(
          value: $retentionDays,
          range: 0...365,
          step: 1,
          unit: AppText.value("天", "days")
        )
      }

      SettingsDivider()

      SettingsSwitchRow(
        title: AppText.value("大表格原始格式", "Preserve Large Table Formats"),
        detail: AppText.value(
          "复制大型表格时保留更多原始格式，粘回表格软件时更可能保留公式；会增加内存和磁盘占用。",
          "Keep richer formats for large copied tables. This can improve fidelity when pasting back into spreadsheet apps, but uses more memory and disk space."
        ),
        isOn: $preserveLargeRichTextFormats
      )
    }
  }

  private var monitoringSettingsCard: some View {
    SettingsSectionCard(title: AppText.value("监听", "Monitoring")) {
      SettingsSwitchRow(
        title: AppText.value("停止监听", "Pause Monitoring"),
        detail: AppText.value(
          "开启后不再监听系统剪贴板，也不会保存新的历史记录。",
          "When enabled, Lite Paste stops watching the system clipboard and will not save new history."
        ),
        isOn: $isMonitoringPaused
      )
    }
  }

  private var dataStatusCard: some View {
    SettingsSectionCard(title: AppText.value("数据状态", "Data Status")) {
      SettingsInfoRow(title: AppText.value("历史数量", "History Items"), value: historyCountText)
      SettingsDivider()
      SettingsInfoRow(title: AppText.value("数据占用", "Storage Used"), value: storageSizeText)
      SettingsDivider()
      SettingsActionRow {
        Button(action: refreshStatus) {
          Label(AppText.value("刷新状态", "Refresh Status"), systemImage: "arrow.clockwise")
        }

        Button(action: revealDataDirectory) {
          Label(AppText.value("显示数据目录", "Show Data Folder"), systemImage: "folder")
        }
      }
    }
  }
}
