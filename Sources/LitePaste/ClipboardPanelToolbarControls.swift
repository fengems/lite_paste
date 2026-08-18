import LitePasteCore
import SwiftUI

struct ClipboardPanelSearchBox: View {
  @Binding var query: String
  let searchFieldFocused: FocusState<Bool>.Binding

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)

      TextField(AppText.value("搜索剪贴板", "Search Clipboard"), text: $query)
        .textFieldStyle(.plain)
        .font(.system(size: 13))
        .focused(searchFieldFocused)

      if query.isEmpty {
        Text("⌘F")
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 6)
          .frame(height: 18)
          .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
          .accessibilityHidden(true)
      } else {
        Button {
          query = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppText.value("清空搜索", "Clear Search"))
        .panelTooltip(AppText.value("清空搜索", "Clear Search"))
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .frame(maxWidth: .infinity, minHeight: 32)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(Color.white.opacity(0.10), lineWidth: 1)
    )
  }
}

struct ClipboardPanelViewModePicker: View {
  @Binding var viewMode: ClipboardPanelViewMode
  let viewModeDidChange: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      viewModeButton(mode: .card, systemName: "rectangle.grid.2x2", label: AppText.value("卡片视图", "Card View"))
      viewModeButton(mode: .list, systemName: "list.bullet", label: AppText.value("列表视图", "List View"))
    }
    .padding(4)
    .frame(width: 82, height: 32)
    .background(Color.primary.opacity(0.060), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(Color.white.opacity(0.08), lineWidth: 1)
    )
  }

  private func viewModeButton(mode: ClipboardPanelViewMode, systemName: String, label: String) -> some View {
    let isSelected = viewMode == mode

    return Button {
      guard viewMode != mode else {
        return
      }
      viewMode = mode
      viewModeDidChange()
    } label: {
      Image(systemName: systemName)
        .font(.system(size: 13, weight: .semibold))
        .frame(maxWidth: .infinity, minHeight: 24)
        .foregroundStyle(isSelected ? Color.white : Color.secondary)
        .background(
          isSelected ? Color.white.opacity(0.12) : Color.clear,
          in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(alignment: .bottom) {
          if isSelected {
            Capsule()
              .fill(Color.blue)
              .frame(width: 20, height: 2)
              .offset(y: 5)
          }
        }
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
    .panelTooltip(label)
  }
}

struct ClipboardPanelHeaderActions: View {
  @Binding var copyPlainTextByDefault: Bool
  @Binding var pastePlainTextByDefault: Bool
  let openSettingsAction: () -> Void
  let clearUnpinnedAction: () -> Void
  let clearAllAction: () -> Void
  let closeAction: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      ClipboardPanelPlainTextQuickToggles(
        copyPlainTextByDefault: $copyPlainTextByDefault,
        pastePlainTextByDefault: $pastePlainTextByDefault
      )
      IconButton(
        systemName: "gearshape",
        accessibilityLabel: AppText.value("设置", "Settings"),
        action: openSettingsAction
      )
      deleteHistoryMenu
      IconButton(systemName: "xmark", accessibilityLabel: AppText.value("关闭", "Close"), action: closeAction)
    }
  }

  private var deleteHistoryMenu: some View {
    Menu {
      Button(action: clearUnpinnedAction) {
        Label(AppText.value("清空未置顶", "Clear Unpinned"), systemImage: "trash.slash")
      }

      Button(role: .destructive, action: clearAllAction) {
        Label(AppText.value("清空全部", "Clear All"), systemImage: "trash")
      }
    } label: {
      Image(systemName: "trash")
        .font(.system(size: 13, weight: .semibold))
        .frame(width: 26, height: 26)
        .foregroundStyle(Color.secondary)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 7, style: .continuous)
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .accessibilityLabel(AppText.value("清空历史", "Clear History"))
    .panelTooltip(AppText.value("清空历史", "Clear History"))
  }
}

struct ClipboardPanelPlainTextQuickToggles: View {
  @Binding var copyPlainTextByDefault: Bool
  @Binding var pastePlainTextByDefault: Bool

  var body: some View {
    HStack(spacing: 4) {
      quickToggle(
        title: AppText.value("复制为纯文本", "Copy Plain Text"),
        systemName: "doc.plaintext",
        isOn: copyPlainTextByDefault
      ) {
        copyPlainTextByDefault.toggle()
      }

      quickToggle(
        title: AppText.value("粘贴为纯文本", "Paste Plain Text"),
        systemName: "text.justify.left",
        isOn: pastePlainTextByDefault
      ) {
        pastePlainTextByDefault.toggle()
      }
    }
  }

  private func quickToggle(
    title: String,
    systemName: String,
    isOn: Bool,
    action: @escaping () -> Void
  ) -> some View {
    let stateText = toggleStateText(isOn)

    return IconButton(
      systemName: systemName,
      accessibilityLabel: title,
      isActive: isOn,
      action: action
    )
    .accessibilityValue(stateText)
  }

  private func toggleStateText(_ isOn: Bool) -> String {
    isOn ? AppText.value("开", "On") : AppText.value("关", "Off")
  }
}
