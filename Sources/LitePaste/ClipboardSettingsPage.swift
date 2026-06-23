import LitePasteCore
import SwiftUI

struct ClipboardSettingsPage: View {
  @Binding var panelPosition: PanelPosition
  @Binding var viewMode: ClipboardPanelViewMode
  @Binding var coverMenuBarWhenEdgeAttached: Bool
  @Binding var focusSearchOnOpen: Bool
  @Binding var clearSearchOnOpen: Bool
  @Binding var autoPasteMode: AutoPasteMode
  @Binding var copySoundEnabled: Bool
  @Binding var imageOCREnabled: Bool
  @Binding var copyPlainTextByDefault: Bool
  @Binding var pastePlainTextByDefault: Bool
  @Binding var visibleQuickActions: Set<ClipboardQuickAction>
  @Binding var autoFavoriteAfterNote: Bool
  @Binding var restoreClipboardAfterPaste: Bool
  @Binding var moveDuplicatesToTop: Bool
  let panelPositionDescription: String
  @State private var showsQuickActionEditor = false

  var body: some View {
    SettingsPageStack {
      SettingsSectionCard(title: AppText.value("窗口设置", "Window")) {
        SettingsRow(title: AppText.value("窗口位置", "Position"), detail: panelPositionDescription) {
          Picker("", selection: $panelPosition) {
            ForEach(PanelPosition.allCases) { position in
              Text(position.localizedDisplayName).tag(position)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .controlSize(.regular)
          .frame(width: SettingsControlMetrics.menuWidth, alignment: .trailing)
        }

        SettingsDivider()

        SettingsRow(title: AppText.value("默认视图", "Default View")) {
          Picker("", selection: $viewMode) {
            Text(AppText.value("卡片", "Cards")).tag(ClipboardPanelViewMode.card)
            Text(AppText.value("列表", "List")).tag(ClipboardPanelViewMode.list)
          }
          .labelsHidden()
          .pickerStyle(.segmented)
          .controlSize(.regular)
          .frame(width: SettingsControlMetrics.segmentedWidth, alignment: .trailing)
        }

        SettingsDivider()

        SettingsSwitchRow(
          title: AppText.value("贴边时覆盖菜单栏", "Cover Menu Bar At Edges"),
          detail: AppText.value(
            "靠上、靠左和靠右时尝试覆盖系统菜单栏区域。",
            "When attached to the top, left, or right edge, the panel can use the menu bar area."
          ),
          isOn: $coverMenuBarWhenEdgeAttached
        )
      }

      SettingsSectionCard(title: AppText.value("音效设置", "Sound")) {
        SettingsSwitchRow(
          title: AppText.value("复制音效", "Copy Sound"),
          detail: AppText.value("新内容进入历史记录时播放提示音。", "Play a sound when new content is saved."),
          isOn: $copySoundEnabled
        )
      }

      SettingsSectionCard(title: AppText.value("搜索设置", "Search")) {
        SettingsSwitchRow(
          title: AppText.value("默认聚焦", "Focus Search"),
          detail: AppText.value("打开面板时自动聚焦搜索框。", "Focus the search field when the panel opens."),
          isOn: $focusSearchOnOpen
        )

        SettingsDivider()

        SettingsSwitchRow(
          title: AppText.value("自动清除", "Clear On Open"),
          detail: AppText.value("打开面板时清除上一次搜索内容。", "Clear the previous search when the panel opens."),
          isOn: $clearSearchOnOpen
        )
      }

      SettingsSectionCard(title: AppText.value("内容设置", "Content")) {
        SettingsRow(
          title: AppText.value("默认操作", "Default Action"),
          detail: AppText.value("选择记录后的默认行为。", "Choose what happens when an item is selected.")
        ) {
          Picker("", selection: $autoPasteMode) {
            Text(AppText.value("仅复制", "Copy Only")).tag(AutoPasteMode.copyOnly)
            Text(AppText.value("自动粘贴", "Auto Paste")).tag(AutoPasteMode.paste)
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .controlSize(.regular)
          .frame(width: SettingsControlMetrics.menuWidth, alignment: .trailing)
        }

        SettingsDivider()

        SettingsSwitchRow(
          title: AppText.value("自动识别图片文字", "Auto Image OCR"),
          detail: AppText.value(
            "复制新图片时后台识别文字并加入搜索；手动复制图片文字不受此开关影响。",
            "Recognize text in newly copied images for search. Manual image text actions still work when this is off."
          ),
          isOn: $imageOCREnabled
        )

        SettingsDivider()

        SettingsSwitchRow(
          title: AppText.value("复制为纯文本", "Copy Plain Text"),
          detail: AppText.value(
            "富文本和 HTML 默认复制时仅保留纯文本内容。",
            "Rich text and HTML are copied as plain text by default."
          ),
          isOn: $copyPlainTextByDefault
        )

        SettingsDivider()

        SettingsSwitchRow(
          title: AppText.value("粘贴为纯文本", "Paste Plain Text"),
          detail: AppText.value(
            "富文本和 HTML 默认粘贴时仅保留纯文本内容。",
            "Rich text and HTML are pasted as plain text by default."
          ),
          isOn: $pastePlainTextByDefault
        )

        SettingsDivider()

        SettingsRow(
          title: AppText.value("操作按钮", "Action Buttons"),
          detail: quickActionSummary
        ) {
          Button {
            showsQuickActionEditor = true
          } label: {
            Label(AppText.value("自定义", "Customize"), systemImage: "slider.horizontal.3")
          }
        }
        .sheet(isPresented: $showsQuickActionEditor) {
          QuickActionSettingsSheet(visibleQuickActions: $visibleQuickActions)
        }

        SettingsDivider()

        SettingsSwitchRow(
          title: AppText.value("自动收藏", "Auto Favorite"),
          detail: AppText.value(
            "新增或编辑备注后自动收藏该记录。",
            "Favorite an item automatically after a note is added or edited."
          ),
          isOn: $autoFavoriteAfterNote
        )

        SettingsDivider()

        SettingsSwitchRow(
          title: AppText.value("恢复原剪贴板", "Restore Clipboard"),
          detail: AppText.value(
            "自动粘贴后恢复执行前的剪贴板内容。",
            "Restore the previous clipboard content after auto paste."
          ),
          isOn: $restoreClipboardAfterPaste
        )

        SettingsDivider()

        SettingsSwitchRow(
          title: AppText.value("自动排序", "Move Duplicates To Top"),
          detail: AppText.value("复制已存在内容时移动到最前面。", "Move existing content to the top when copied again."),
          isOn: $moveDuplicatesToTop
        )
      }
    }
  }

  private var quickActionSummary: String {
    let names = ClipboardQuickAction.displayOrder
      .filter { visibleQuickActions.contains($0) }
      .map(\.localizedDisplayName)

    if names.isEmpty {
      return AppText.value("仅显示右键菜单。", "Only the context menu is shown.")
    }

    return names.joined(separator: AppText.value("、", ", "))
  }
}
