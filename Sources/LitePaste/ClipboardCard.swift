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
  @State private var isHovering = false

  var body: some View {
    ZStack(alignment: .leading) {
      cardBackground
      selectionInteriorGlow
      accentStrip

      VStack(alignment: .leading, spacing: contentInset) {
        header
        preview
      }
      .padding(.vertical, contentInset)
      .padding(.leading, ClipboardPanelMetrics.accentStripWidth + contentInset)
      .padding(.trailing, contentInset)
    }
    .frame(maxWidth: .infinity, minHeight: ClipboardPanelMetrics.cardHeight, maxHeight: ClipboardPanelMetrics.cardHeight)
    .clipShape(cardShape)
    .overlay(selectionStroke)
    .shadow(color: cardShadowColor, radius: cardShadowRadius, y: 3)
    .contentShape(RoundedRectangle(cornerRadius: ClipboardPanelMetrics.cardCornerRadius))
    .contextMenu {
      actionMenuItems
    }
    .onHover { hovering in
      withAnimation(.easeOut(duration: 0.12)) {
        isHovering = hovering
      }
    }
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

  @ViewBuilder
  private var quickActions: some View {
    if showsQuickActions && ClipboardQuickActionButtons.hasActions(in: visibleQuickActions) {
      HStack(spacing: 5) {
        ClipboardQuickActionButtons(context: actionContext, visibleQuickActions: visibleQuickActions)
      }
      .transition(.opacity)
    }
  }

  private var contentInset: CGFloat {
    10
  }

  private var showsQuickActions: Bool {
    isSelected || isHovering
  }

  private var selectionTintOpacity: Double {
    if isSelected {
      return 0.18
    }
    return isHovering ? 0.085 : 0.055
  }

  private var cardShadowColor: Color {
    if isSelected {
      return record.kind.accentColor.opacity(0.34)
    }
    return isHovering ? record.kind.accentColor.opacity(0.14) : Color.black.opacity(0.10)
  }

  private var cardShadowRadius: CGFloat {
    isSelected ? 15 : (isHovering ? 9 : 6)
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

  @ViewBuilder
  private var actionMenuItems: some View {
    ClipboardItemActionMenuItems(context: actionContext, showsSecondaryDivider: true)
  }

  private var cardMetadata: String {
    [record.sourceAppName, record.panelRelativeTimeText]
      .compactMap { $0 }
      .joined(separator: "  •  ")
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
      cardShape
        .strokeBorder(Color.white.opacity(isSelected ? 0.20 : 0.10), lineWidth: 1)

      cardShape
        .strokeBorder(
          record.kind.accentColor.opacity(isSelected ? 0.96 : (isHovering ? 0.44 : 0)),
          lineWidth: isSelected ? 2.5 : 1
        )
    }
    .allowsHitTesting(false)
  }

  private var cardShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: ClipboardPanelMetrics.cardCornerRadius)
  }

  @ViewBuilder
  private var cardBackground: some View {
    cardShape
      .fill(.regularMaterial)
      .overlay(
        cardShape.fill(record.kind.accentColor.opacity(selectionTintOpacity))
      )
      .overlay(
        cardShape
          .stroke(Color.white.opacity(0.08), lineWidth: 1)
      )
  }

  private var selectionInteriorGlow: some View {
    cardShape
      .strokeBorder(
        record.kind.accentColor.opacity(isSelected ? 0.26 : (isHovering ? 0.10 : 0)),
        lineWidth: isSelected ? 7 : 4
      )
      .blur(radius: isSelected ? 4 : 2)
      .opacity(isSelected || isHovering ? 1 : 0)
      .allowsHitTesting(false)
  }

  private var accentStrip: some View {
    RoundedRectangle(cornerRadius: 2, style: .continuous)
      .fill(record.kind.accentColor.opacity(isSelected ? 1 : (isHovering ? 0.92 : 0.78)))
      .frame(width: ClipboardPanelMetrics.accentStripWidth)
      .padding(.vertical, 0)
      .padding(.leading, 0)
      .shadow(
        color: record.kind.accentColor.opacity(isSelected ? 0.58 : (isHovering ? 0.42 : 0.30)),
        radius: isSelected ? 12 : 8,
        y: 2
      )
  }
}

extension ClipboardCard: Equatable {
  // 忽略闭包：它们捕获动作目标，不参与渲染像素；闭包语义变化总伴随
  // record 或 visibleQuickActions 变化，已被下方字段覆盖。
  nonisolated static func == (lhs: ClipboardCard, rhs: ClipboardCard) -> Bool {
    lhs.record.id == rhs.record.id
      && lhs.isSelected == rhs.isSelected
      && lhs.visibleQuickActions == rhs.visibleQuickActions
      && lhs.externalAction == rhs.externalAction
  }
}
