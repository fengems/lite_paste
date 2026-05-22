import LitePasteCore
import SwiftUI

struct ClipboardRow: View {
  let record: ClipboardRecord
  let primaryAction: (ClipboardRecord) -> Void
  let copyAction: (ClipboardRecord) -> Void
  let pasteAction: (ClipboardRecord) -> Void
  let toggleFavorite: () -> Void
  let togglePinned: () -> Void
  let deleteAction: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: iconName)
        .font(.system(size: 16, weight: .semibold))
        .frame(width: 28, height: 28)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

      VStack(alignment: .leading, spacing: 4) {
        Text(record.title)
          .font(.system(size: 14, weight: .medium))
          .lineLimit(1)

        HStack(spacing: 8) {
          Text(record.kind.displayName)
          if let source = record.sourceAppName {
            Text(source)
          }
          Text(record.lastCopiedAt, style: .relative)
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
      }

      Spacer()

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
      IconButton(
        systemName: record.isPinned ? "pin.fill" : "pin",
        accessibilityLabel: "置顶",
        action: togglePinned
      )
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
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    .onTapGesture {
      primaryAction(record)
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
