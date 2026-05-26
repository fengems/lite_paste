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
  let editPinShortcut: () -> Void
  let toggleFavorite: () -> Void
  let togglePinned: () -> Void
  let deleteAction: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      header
      preview
    }
    .padding(10)
    .frame(maxWidth: .infinity, minHeight: ClipboardPanelMetrics.cardHeight, maxHeight: ClipboardPanelMetrics.cardHeight)
    .background(cardBackground)
    .overlay(selectionStroke)
    .shadow(color: shadowColor, radius: isSelected ? 14 : 4, y: isSelected ? 6 : 2)
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

      Text(relativeTimeText)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)

      Spacer(minLength: 0)

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

  private var relativeTimeText: String {
    let elapsedSeconds = max(0, Date().timeIntervalSince(record.lastCopiedAt))
    if elapsedSeconds < 60 {
      return "刚刚"
    }
    let elapsedMinutes = Int(elapsedSeconds / 60)
    if elapsedMinutes < 60 {
      return "\(elapsedMinutes) 分钟前"
    }
    let elapsedHours = Int(elapsedSeconds / 3600)
    if elapsedHours < 24 {
      return "\(elapsedHours) 小时前"
    }
    let elapsedDays = Int(elapsedSeconds / 86_400)
    return "\(elapsedDays) 天前"
  }

  private var selectionStroke: some View {
    RoundedRectangle(cornerRadius: ClipboardPanelMetrics.cardCornerRadius)
      .stroke(
        isSelected ? record.kind.accentColor.opacity(0.98) : Color.primary.opacity(0.08),
        lineWidth: isSelected ? 2.5 : 1
      )
  }

  private var cardBackground: some View {
    RoundedRectangle(cornerRadius: ClipboardPanelMetrics.cardCornerRadius)
      .fill(.regularMaterial)
      .overlay {
        RoundedRectangle(cornerRadius: ClipboardPanelMetrics.cardCornerRadius)
          .fill(isSelected ? record.kind.accentColor.opacity(0.11) : Color.clear)
      }
  }

  private var shadowColor: Color {
    isSelected ? record.kind.accentColor.opacity(0.30) : Color.black.opacity(0.08)
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
