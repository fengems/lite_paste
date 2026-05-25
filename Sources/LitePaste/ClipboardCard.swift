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
  let editPinShortcut: () -> Void
  let toggleFavorite: () -> Void
  let togglePinned: () -> Void
  let deleteAction: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      header
      preview
      footer
    }
    .padding(10)
    .frame(width: 194, height: 160)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: ClipboardPanelMetrics.cardCornerRadius))
    .overlay(selectionStroke)
    .shadow(color: shadowColor, radius: isSelected ? 12 : 4, y: isSelected ? 5 : 2)
    .contentShape(RoundedRectangle(cornerRadius: ClipboardPanelMetrics.cardCornerRadius))
    .onTapGesture {
      primaryAction(record)
    }
  }

  private var header: some View {
    HStack(spacing: 6) {
      Label(sourceTitle, systemImage: record.kind.previewIconName)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(record.kind.accentColor)
        .lineLimit(1)

      Text(record.lastCopiedAt, style: .relative)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)

      Spacer(minLength: 0)

      IconButton(
        systemName: record.isFavorite ? "star.fill" : "star",
        accessibilityLabel: "收藏",
        isActive: record.isFavorite,
        tint: .yellow,
        action: toggleFavorite
      )
    }
  }

  private var preview: some View {
    ClipboardContentPreview(record: record, style: .card)
      .padding(8)
      .frame(maxWidth: .infinity, minHeight: 76, maxHeight: 76, alignment: .topLeading)
      .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
      .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  private var footer: some View {
    HStack(spacing: 6) {
      Label(record.kind.displayName, systemImage: record.kind.previewIconName)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(record.kind.accentColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(record.kind.accentColor.opacity(0.12), in: Capsule())
        .lineLimit(1)

      if let pinShortcut = record.pinShortcut {
        Text(PinShortcutCatalog.displayName(for: pinShortcut))
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 6)
          .padding(.vertical, 4)
          .background(Color.primary.opacity(0.055), in: Capsule())
      }

      Spacer(minLength: 0)

      IconButton(
        systemName: "arrow.turn.down.left",
        accessibilityLabel: "粘贴",
        tint: record.kind.accentColor
      ) {
        pasteAction(record)
      }
      IconButton(
        systemName: "doc.on.doc",
        accessibilityLabel: "复制",
        tint: record.kind.accentColor
      ) {
        copyAction(record)
      }
      actionMenu
    }
  }

  private var actionMenu: some View {
    Menu {
      Button {
        pastePlainTextAction(record)
      } label: {
        Label("纯文本粘贴", systemImage: "textformat")
      }

      Button {
        copyPlainTextAction(record)
      } label: {
        Label("复制纯文本", systemImage: "doc.plaintext")
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
        Label(record.note.isEmpty ? "添加备注" : "编辑备注", systemImage: "note.text")
      }

      Button(action: togglePinned) {
        Label(record.isPinned ? "取消置顶" : "置顶", systemImage: record.isPinned ? "pin.slash" : "pin")
      }

      if record.isPinned {
        Button(action: editPinShortcut) {
          Label("设置快捷键", systemImage: "keyboard")
        }
      }

      Button(role: .destructive, action: deleteAction) {
        Label("删除", systemImage: "trash")
      }
    } label: {
      Image(systemName: "ellipsis")
        .font(.system(size: 13, weight: .semibold))
        .frame(width: 26, height: 26)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
    .accessibilityLabel("更多操作")
  }

  private var sourceTitle: String {
    record.sourceAppName ?? "Lite Paste"
  }

  private var selectionStroke: some View {
    RoundedRectangle(cornerRadius: ClipboardPanelMetrics.cardCornerRadius)
      .stroke(
        isSelected ? record.kind.accentColor.opacity(0.95) : Color.primary.opacity(0.08),
        lineWidth: isSelected ? 2 : 1
      )
  }

  private var shadowColor: Color {
    isSelected ? record.kind.accentColor.opacity(0.22) : Color.black.opacity(0.08)
  }
}
