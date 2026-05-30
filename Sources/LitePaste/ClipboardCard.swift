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
    .shadow(color: isSelected ? record.kind.accentColor.opacity(0.22) : Color.black.opacity(0.10), radius: isSelected ? 13 : 6, y: 3)
    .contentShape(RoundedRectangle(cornerRadius: ClipboardPanelMetrics.cardCornerRadius))
    .onTapGesture {
      primaryAction(record)
    }
  }

  private var header: some View {
    HStack(spacing: 8) {
      SourceAppIcon(record: record, size: 30, cornerRadius: 8, symbolSize: 14)

      VStack(alignment: .leading, spacing: 2) {
        Text(record.kind.displayName)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.primary)
          .lineLimit(1)

        Text(cardMetadata)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 0)

      IconButton(
        systemName: record.isPinned ? "pin.fill" : "pin",
        accessibilityLabel: "置顶",
        isActive: record.isPinned,
        tint: .blue,
        showsInactiveBackground: false,
        action: togglePinned
      )

      IconButton(
        systemName: record.isFavorite ? "star.fill" : "star",
        accessibilityLabel: "收藏",
        isActive: record.isFavorite,
        tint: .yellow,
        showsInactiveBackground: false,
        action: toggleFavorite
      )

      actionMenu
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

      Divider()

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

  private var cardMetadata: String {
    [record.sourceAppName, record.panelRelativeTimeText]
      .compactMap { $0 }
      .joined(separator: "  •  ")
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
        cardShape.fill(record.kind.accentColor.opacity(isSelected ? 0.11 : 0.035))
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
      .shadow(color: record.kind.accentColor.opacity(0.28), radius: 8, y: 2)
  }
}
