import LitePasteCore
import SwiftUI

struct ClipboardCard: View {
  let record: ClipboardRecord
  let isSelected: Bool
  let primaryAction: (ClipboardRecord) -> Void
  let copyAction: (ClipboardRecord) -> Void
  let copyPlainTextAction: (ClipboardRecord) -> Void
  let pasteAction: (ClipboardRecord) -> Void
  let pastePlainTextAction: (ClipboardRecord) -> Void
  let externalAction: ClipboardExternalAction?
  let performExternalAction: (ClipboardExternalAction) -> Void
  let editNote: () -> Void
  let toggleFavorite: () -> Void
  let togglePinned: () -> Void
  let deleteAction: () -> Void
  let visibleQuickActions: Set<ClipboardQuickAction>

  var body: some View {
    ZStack(alignment: .leading) {
      cardBackground
      accentStrip

      VStack(alignment: .leading, spacing: 9) {
        header
        preview
      }
      .padding(.vertical, 10)
      .padding(.leading, 18)
      .padding(.trailing, 10)
    }
    .frame(maxWidth: .infinity, minHeight: ClipboardPanelMetrics.cardHeight, maxHeight: ClipboardPanelMetrics.cardHeight)
    .clipShape(cardShape)
    .overlay(selectionStroke)
    .shadow(color: isSelected ? record.kind.accentColor.opacity(0.28) : Color.black.opacity(0.10), radius: isSelected ? 13 : 6, y: 3)
    .contentShape(RoundedRectangle(cornerRadius: ClipboardPanelMetrics.cardCornerRadius))
    .onTapGesture {
      primaryAction(record)
    }
  }

  private var header: some View {
    HStack(spacing: 8) {
      SourceAppIcon(record: record, size: 30, cornerRadius: 8, symbolSize: 14)

      VStack(alignment: .leading, spacing: 2) {
        Text(record.kind.localizedDisplayName)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.primary)
          .lineLimit(1)

        Text(cardMetadata)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 0)

      quickActions
    }
  }

  private var quickActions: some View {
    HStack(spacing: 5) {
      ForEach(orderedQuickActions, id: \.self) { action in
        quickActionButton(action)
      }

      actionMenu
    }
  }

  private var orderedQuickActions: [ClipboardQuickAction] {
    Array(ClipboardQuickAction.displayOrder.filter { visibleQuickActions.contains($0) }.prefix(4))
  }

  @ViewBuilder
  private func quickActionButton(_ action: ClipboardQuickAction) -> some View {
    switch action {
    case .favorite:
      IconButton(
        systemName: record.isFavorite ? "star.fill" : "star",
        accessibilityLabel: action.localizedDisplayName,
        isActive: record.isFavorite,
        tint: .yellow,
        showsInactiveBackground: false,
        action: toggleFavorite
      )
    case .pin:
      IconButton(
        systemName: record.isPinned ? "pin.fill" : "pin",
        accessibilityLabel: action.localizedDisplayName,
        isActive: record.isPinned,
        tint: .blue,
        showsInactiveBackground: false,
        action: togglePinned
      )
    case .copy:
      IconButton(systemName: action.iconName, accessibilityLabel: action.localizedDisplayName, action: { copyAction(record) })
    case .copyPlainText:
      IconButton(systemName: action.iconName, accessibilityLabel: plainTextCopyLabel, action: { copyPlainTextAction(record) })
    case .paste:
      IconButton(systemName: action.iconName, accessibilityLabel: action.localizedDisplayName, action: { pasteAction(record) })
    case .pastePlainText:
      IconButton(systemName: action.iconName, accessibilityLabel: plainTextPasteLabel, action: { pastePlainTextAction(record) })
    case .note:
      IconButton(
        systemName: record.note.isEmpty ? action.iconName : "note.text",
        accessibilityLabel: action.localizedDisplayName,
        isActive: !record.note.isEmpty,
        tint: .blue,
        action: editNote
      )
    case .delete:
      IconButton(systemName: action.iconName, accessibilityLabel: action.localizedDisplayName, tint: .red, action: deleteAction)
    case .external:
      if let externalAction {
        IconButton(
          systemName: externalAction.iconName,
          accessibilityLabel: externalAction.accessibilityLabel,
          action: { performExternalAction(externalAction) }
        )
      }
    }
  }

  private var preview: some View {
    ClipboardContentPreview(record: record, style: .card)
      .padding(10)
      .padding(2)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .stroke(Color.white.opacity(0.10), lineWidth: 1)
      )
  }

  private var actionMenu: some View {
    Menu {
      Button {
        pasteAction(record)
      } label: {
        Label(AppText.value("粘贴", "Paste"), systemImage: "arrow.turn.down.left")
      }

      Button {
        copyAction(record)
      } label: {
        Label(AppText.value("复制", "Copy"), systemImage: "doc.on.doc")
      }

      Button {
        pastePlainTextAction(record)
      } label: {
        Label(plainTextPasteLabel, systemImage: "textformat")
      }

      Button {
        copyPlainTextAction(record)
      } label: {
        Label(plainTextCopyLabel, systemImage: "doc.plaintext")
      }

      if let externalAction {
        Button {
          performExternalAction(externalAction)
        } label: {
          Label(externalAction.accessibilityLabel, systemImage: externalAction.iconName)
        }
      }

      Divider()

      Button(action: editNote) {
        Label(
          record.note.isEmpty ? AppText.value("添加备注", "Add Note") : AppText.value("编辑备注", "Edit Note"),
          systemImage: "note.text"
        )
      }

      Button(role: .destructive, action: deleteAction) {
        Label(AppText.value("删除", "Delete"), systemImage: "trash")
      }
    } label: {
      Image(systemName: "ellipsis")
        .font(.system(size: 13, weight: .semibold))
        .frame(width: 26, height: 26)
        .contentShape(Rectangle())
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .accessibilityLabel(AppText.value("更多操作", "More Actions"))
    .panelTooltip(AppText.value("更多操作", "More Actions"))
  }

  private var cardMetadata: String {
    [record.sourceAppName, record.panelRelativeTimeText]
      .compactMap { $0 }
      .joined(separator: "  •  ")
  }

  private var plainTextCopyLabel: String {
    record.kind == .image
      ? AppText.value("复制图片文字", "Copy Image Text")
      : AppText.value("复制纯文本", "Copy Plain Text")
  }

  private var plainTextPasteLabel: String {
    record.kind == .image
      ? AppText.value("粘贴为文本", "Paste As Text")
      : AppText.value("纯文本粘贴", "Paste Plain Text")
  }

  private var selectionStroke: some View {
    cardShape
      .strokeBorder(
        isSelected ? record.kind.accentColor.opacity(0.95) : Color.white.opacity(0.10),
        lineWidth: isSelected ? 2 : 1
      )
  }

  private var cardShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: ClipboardPanelMetrics.cardCornerRadius)
  }

  @ViewBuilder
  private var cardBackground: some View {
    cardShape
      .fill(.regularMaterial)
      .overlay(
        cardShape.fill(record.kind.accentColor.opacity(isSelected ? 0.14 : 0.055))
      )
      .overlay(
        cardShape
          .stroke(Color.white.opacity(0.08), lineWidth: 1)
      )
  }

  private var accentStrip: some View {
    RoundedRectangle(cornerRadius: 2, style: .continuous)
      .fill(record.kind.accentColor)
      .frame(width: ClipboardPanelMetrics.accentStripWidth)
      .padding(.vertical, 0)
      .padding(.leading, 0)
      .shadow(color: record.kind.accentColor.opacity(0.36), radius: 9, y: 2)
  }
}
