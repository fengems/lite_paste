import LitePasteCore
import SwiftUI

struct ClipboardCard: View {
  let record: ClipboardRecord
  let isSelected: Bool
  let primaryAction: (ClipboardRecord) -> Void
  let copyAction: (ClipboardRecord) -> Void
  let pasteAction: (ClipboardRecord) -> Void
  let externalAction: ClipboardExternalAction?
  let performExternalAction: (ClipboardExternalAction) -> Void
  let editNote: () -> Void
  let editPinShortcut: () -> Void
  let toggleFavorite: () -> Void
  let togglePinned: () -> Void
  let deleteAction: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label(record.kind.displayName, systemImage: iconName)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary)

        Spacer()

        actionButtons
      }

      preview
        .frame(maxWidth: .infinity, minHeight: 110, maxHeight: 110, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 8))

      HStack {
        if let source = record.sourceAppName {
          Text(source)
        }

        if !record.note.isEmpty {
          Label("备注", systemImage: "note.text")
        }

        if let pinShortcut = record.pinShortcut {
          Label(PinShortcutCatalog.displayName(for: pinShortcut), systemImage: "keyboard")
        }

        Spacer()

        Text(record.lastCopiedAt, style: .relative)
      }
      .font(.system(size: 12))
      .foregroundStyle(.secondary)
    }
    .padding(14)
    .frame(width: 240, height: 210)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(
          isSelected ? Color.accentColor.opacity(0.9) : .white.opacity(0.12),
          lineWidth: isSelected ? 2 : 1
        )
    )
    .shadow(color: isSelected ? Color.accentColor.opacity(0.22) : .clear, radius: 10)
    .onTapGesture {
      primaryAction(record)
    }
  }

  private var actionButtons: some View {
    HStack(spacing: 6) {
      IconButton(
        systemName: "arrow.turn.down.left",
        accessibilityLabel: "粘贴",
        action: {
          pasteAction(record)
        }
      )
      IconButton(
        systemName: "doc.on.doc",
        accessibilityLabel: "复制",
        action: {
          copyAction(record)
        }
      )
      if let externalAction {
        IconButton(
          systemName: externalAction.iconName,
          accessibilityLabel: externalAction.accessibilityLabel,
          action: {
            performExternalAction(externalAction)
          }
        )
      }
      IconButton(
        systemName: record.note.isEmpty ? "note.text.badge.plus" : "note.text",
        accessibilityLabel: "编辑备注",
        action: editNote
      )
      IconButton(
        systemName: record.isPinned ? "pin.fill" : "pin",
        accessibilityLabel: "置顶",
        action: togglePinned
      )
      if record.isPinned {
        IconButton(
          systemName: "keyboard",
          accessibilityLabel: "设置快捷键",
          action: editPinShortcut
        )
      }
      IconButton(
        systemName: record.isFavorite ? "star.fill" : "star",
        accessibilityLabel: "收藏",
        action: toggleFavorite
      )
      IconButton(
        systemName: "trash",
        accessibilityLabel: "删除",
        action: deleteAction
      )
    }
  }

  @ViewBuilder
  private var preview: some View {
    if record.kind == .image, let path = record.previewFilePath {
      ClipboardPreviewImage(path: path)
    } else {
      Text(record.title)
        .font(.system(size: 17, weight: .semibold))
        .lineLimit(5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
  }

  private var iconName: String {
    switch record.kind {
    case .text:
      "text.alignleft"
    case .richText, .html:
      "doc.richtext"
    case .image:
      "photo"
    case .files:
      "folder"
    case .url:
      "link"
    case .email:
      "envelope"
    case .color:
      "paintpalette"
    case .unknown:
      "questionmark.square"
    }
  }
}
