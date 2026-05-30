import LitePasteCore
import SwiftUI

struct ClipboardRow: View {
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

  var body: some View {
    HStack(spacing: 9) {
      accentStrip
      SourceAppIcon(record: record)
      titleBlock
      Spacer(minLength: 8)
      quickActions
    }
    .padding(.trailing, 8)
    .padding(.vertical, 6)
    .background(rowBackground)
    .clipShape(RoundedRectangle(cornerRadius: ClipboardPanelMetrics.compactCornerRadius, style: .continuous))
    .overlay(selectionStroke)
    .shadow(color: isSelected ? record.kind.accentColor.opacity(0.22) : Color.black.opacity(0.08), radius: isSelected ? 12 : 5, y: 3)
    .contentShape(RoundedRectangle(cornerRadius: ClipboardPanelMetrics.compactCornerRadius))
    .onTapGesture {
      primaryAction(record)
    }
  }

  private var accentStrip: some View {
    RoundedRectangle(cornerRadius: 2)
      .fill(record.kind.accentColor)
      .frame(width: ClipboardPanelMetrics.accentStripWidth, height: 34)
      .shadow(color: record.kind.accentColor.opacity(0.28), radius: 8, y: 2)
  }

  private var titleBlock: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(record.title)
        .font(.system(size: 13, weight: .semibold))
        .lineLimit(1)

      HStack(spacing: 6) {
        Text(record.kind.displayName)
          .foregroundStyle(record.kind.accentColor)
        if let source = record.sourceAppName {
          Text(source)
        }
        if !record.note.isEmpty {
          Label("备注", systemImage: "note.text")
        }
        Text(record.panelRelativeTimeText)
      }
      .font(.system(size: 11, weight: .medium))
      .foregroundStyle(.secondary)
      .lineLimit(1)
    }
  }

  private var quickActions: some View {
    HStack(spacing: 5) {
      IconButton(
        systemName: record.isFavorite ? "star.fill" : "star",
        accessibilityLabel: "收藏",
        isActive: record.isFavorite,
        tint: .yellow,
        showsInactiveBackground: false,
        action: toggleFavorite
      )
      IconButton(
        systemName: record.isPinned ? "pin.fill" : "pin",
        accessibilityLabel: "置顶",
        isActive: record.isPinned,
        tint: .blue,
        showsInactiveBackground: false,
        action: togglePinned
      )
      actionMenu
    }
  }

  private var actionMenu: some View {
    Menu {
      Button {
        pasteAction(record)
      } label: {
        Label("粘贴", systemImage: "arrow.turn.down.left")
      }

      Button {
        copyAction(record)
      } label: {
        Label("复制", systemImage: "doc.on.doc")
      }

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

      Button(action: editNote) {
        Label(record.note.isEmpty ? "添加备注" : "编辑备注", systemImage: "note.text")
      }

      Button(role: .destructive, action: deleteAction) {
        Label("删除", systemImage: "trash")
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
    .accessibilityLabel("更多操作")
    .panelTooltip("更多操作")
  }

  private var selectionStroke: some View {
    RoundedRectangle(cornerRadius: ClipboardPanelMetrics.compactCornerRadius)
      .stroke(isSelected ? record.kind.accentColor.opacity(0.98) : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
  }

  private var rowBackground: some View {
    RoundedRectangle(cornerRadius: ClipboardPanelMetrics.compactCornerRadius)
      .fill(.regularMaterial)
      .overlay {
        RoundedRectangle(cornerRadius: ClipboardPanelMetrics.compactCornerRadius)
          .fill(record.kind.accentColor.opacity(isSelected ? 0.11 : 0.035))
      }
  }
}
