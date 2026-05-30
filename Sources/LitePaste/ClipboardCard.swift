import AppKit
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

      VStack(alignment: .leading, spacing: 9) {
        header
        preview
      }
      .padding(10)
    }
    .frame(maxWidth: .infinity, minHeight: ClipboardPanelMetrics.cardHeight, maxHeight: ClipboardPanelMetrics.cardHeight)
    .overlay(selectionStroke)
    .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    .contentShape(RoundedRectangle(cornerRadius: ClipboardPanelMetrics.cardCornerRadius))
    .onTapGesture {
      primaryAction(record)
    }
  }

  private var header: some View {
    HStack(spacing: 7) {
      SourceAppIcon(record: record)

      Text(contentSummary)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.primary)
        .lineLimit(1)

      Text(record.panelRelativeTimeText)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)

      Spacer(minLength: 0)

      IconButton(
        systemName: record.isPinned ? "pin.fill" : "pin",
        accessibilityLabel: "置顶",
        isActive: record.isPinned,
        tint: .purple,
        size: 22,
        iconSize: 11,
        cornerRadius: 6,
        action: togglePinned
      )

      IconButton(
        systemName: record.isFavorite ? "star.fill" : "star",
        accessibilityLabel: "收藏",
        isActive: record.isFavorite,
        tint: .yellow,
        size: 22,
        iconSize: 11,
        cornerRadius: 6,
        action: toggleFavorite
      )

      actionMenu
    }
  }

  private var preview: some View {
    ClipboardContentPreview(record: record, style: .card)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        .font(.system(size: 11, weight: .semibold))
        .frame(width: 22, height: 22)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
    .accessibilityLabel("更多操作")
  }

  private var contentSummary: String {
    switch record.kind {
    case .text:
      return "纯文本"
    case .files:
      return "\(max(record.contents.count, 1)) 个文件"
    case .image:
      return "图片"
    case .richText:
      return "富文本"
    case .html:
      return "HTML"
    case .url:
      return "链接"
    case .email:
      return "邮箱"
    case .color:
      return "颜色"
    case .unknown:
      return "未知"
    }
  }

  private var selectionStroke: some View {
    cardShape
      .strokeBorder(
        Color.primary.opacity(isSelected ? 0.18 : 0.08),
        lineWidth: 1
      )
  }

  private var cardShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: ClipboardPanelMetrics.cardCornerRadius)
  }

  @ViewBuilder
  private var cardBackground: some View {
    if isSelected {
      selectedCardBackground
    } else {
      cardShape.fill(.regularMaterial)
    }
  }

  @ViewBuilder
  private var selectedCardBackground: some View {
    if #available(macOS 26.0, *) {
      GlassEffectContainer(spacing: 0) {
        cardShape
          .fill(Color.white.opacity(0.001))
          .glassEffect(
            Glass.regular
              .tint(record.kind.accentColor.opacity(0.18))
              .interactive(),
            in: cardShape
          )
      }
    } else {
      ZStack {
        cardShape
          .fill(.thinMaterial)
          .opacity(0.72)

        cardShape
          .fill(record.kind.accentColor.opacity(0.08))
      }
    }
  }
}

private struct SourceAppIcon: View {
  let record: ClipboardRecord

  var body: some View {
    Group {
      if let image = appIcon {
        Image(nsImage: image)
          .resizable()
          .scaledToFit()
      } else {
        Image(systemName: record.kind.previewIconName)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(record.kind.accentColor)
      }
    }
    .frame(width: 20, height: 20)
    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 5))
    .accessibilityLabel(record.sourceAppName ?? "来源应用")
  }

  private var appIcon: NSImage? {
    guard let bundleId = record.sourceAppBundleId,
          let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
      return nil
    }
    return NSWorkspace.shared.icon(forFile: url.path)
  }
}
