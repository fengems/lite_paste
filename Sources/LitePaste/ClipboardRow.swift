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
  let visibleQuickActions: Set<ClipboardQuickAction>
  @State private var isHovering = false

  var body: some View {
    ZStack(alignment: .leading) {
      rowBackground
      selectionInteriorGlow

      HStack(spacing: 9) {
        accentStrip
        SourceAppIcon(record: record)
        titleBlock
        Spacer(minLength: 8)
        quickActions
      }
      .padding(.trailing, 8)
      .padding(.vertical, 6)
    }
    .clipShape(rowShape)
    .overlay(selectionStroke)
    .shadow(color: rowShadowColor, radius: rowShadowRadius, y: 3)
    .contentShape(RoundedRectangle(cornerRadius: ClipboardPanelMetrics.compactCornerRadius))
    .onHover { hovering in
      withAnimation(.easeOut(duration: 0.12)) {
        isHovering = hovering
      }
    }
    .onTapGesture {
      primaryAction(record)
    }
  }

  private var accentStrip: some View {
    RoundedRectangle(cornerRadius: 2)
      .fill(record.kind.accentColor.opacity(isSelected ? 1 : (isHovering ? 0.92 : 0.78)))
      .frame(width: ClipboardPanelMetrics.accentStripWidth, height: 34)
      .shadow(
        color: record.kind.accentColor.opacity(isSelected ? 0.56 : (isHovering ? 0.40 : 0.28)),
        radius: isSelected ? 11 : 8,
        y: 2
      )
  }

  private var titleBlock: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(record.title)
        .font(.system(size: 13, weight: .semibold))
        .lineLimit(1)

      HStack(spacing: 6) {
        Text(record.kind.localizedDisplayName)
          .foregroundStyle(record.kind.accentColor)
        if let source = record.sourceAppName {
          Text(source)
        }
        if !record.note.isEmpty {
          Label(AppText.value("备注", "Note"), systemImage: "note.text")
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
      ClipboardQuickActionButtons(context: actionContext, visibleQuickActions: visibleQuickActions)

      actionMenu
    }
  }

  private var actionMenu: some View {
    Menu {
      ClipboardItemActionMenuItems(context: actionContext)
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

  private var actionContext: ClipboardItemActionContext {
    ClipboardItemActionContext(
      record: record,
      externalAction: externalAction,
      copyAction: copyAction,
      copyPlainTextAction: copyPlainTextAction,
      pasteAction: pasteAction,
      pastePlainTextAction: pastePlainTextAction,
      performExternalAction: performExternalAction,
      editNote: editNote,
      toggleFavorite: toggleFavorite,
      togglePinned: togglePinned,
      deleteAction: deleteAction
    )
  }

  private var selectionStroke: some View {
    ZStack {
      rowShape
        .strokeBorder(Color.white.opacity(isSelected ? 0.18 : 0.08), lineWidth: 1)

      rowShape
        .strokeBorder(
          record.kind.accentColor.opacity(isSelected ? 0.96 : (isHovering ? 0.38 : 0)),
          lineWidth: isSelected ? 2.25 : 1
        )
    }
    .allowsHitTesting(false)
  }

  private var rowBackground: some View {
    rowShape
      .fill(.regularMaterial)
      .overlay {
        rowShape.fill(record.kind.accentColor.opacity(selectionTintOpacity))
      }
  }

  private var selectionInteriorGlow: some View {
    rowShape
      .strokeBorder(
        record.kind.accentColor.opacity(isSelected ? 0.22 : (isHovering ? 0.08 : 0)),
        lineWidth: isSelected ? 6 : 3
      )
      .blur(radius: isSelected ? 3 : 1.5)
      .opacity(isSelected || isHovering ? 1 : 0)
      .allowsHitTesting(false)
  }

  private var rowShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: ClipboardPanelMetrics.compactCornerRadius, style: .continuous)
  }

  private var selectionTintOpacity: Double {
    if isSelected {
      return 0.17
    }
    return isHovering ? 0.075 : 0.055
  }

  private var rowShadowColor: Color {
    if isSelected {
      return record.kind.accentColor.opacity(0.32)
    }
    return isHovering ? record.kind.accentColor.opacity(0.12) : Color.black.opacity(0.08)
  }

  private var rowShadowRadius: CGFloat {
    isSelected ? 13 : (isHovering ? 8 : 5)
  }
}

extension ClipboardRow: Equatable {
  // 与 ClipboardCard 同理，仅比较驱动渲染的字段，忽略闭包。
  nonisolated static func == (lhs: ClipboardRow, rhs: ClipboardRow) -> Bool {
    lhs.record.id == rhs.record.id
      && lhs.isSelected == rhs.isSelected
      && lhs.visibleQuickActions == rhs.visibleQuickActions
      && lhs.externalAction == rhs.externalAction
  }
}
