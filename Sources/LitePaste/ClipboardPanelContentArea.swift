import LitePasteCore
import SwiftUI

struct ClipboardPanelEmptyState {
  let systemName: String
  let title: String
  let message: String?

  static func resolve(
    allRecordCount: Int,
    isMonitoringPaused: Bool,
    query: String,
    filter: ClipboardFilter
  ) -> ClipboardPanelEmptyState {
    if allRecordCount == 0 {
      if isMonitoringPaused {
        return ClipboardPanelEmptyState(
          systemName: "pause.circle",
          title: AppText.value("已停止监听剪贴板", "Clipboard Monitoring Paused"),
          message: AppText.value(
            "关闭停止监听后，新的剪贴板内容会继续保存到历史。",
            "Resume monitoring to save new clipboard content to history."
          )
        )
      }
      return ClipboardPanelEmptyState(
        systemName: "doc.on.clipboard",
        title: AppText.value("暂无剪贴板历史", "No Clipboard History"),
        message: AppText.value(
          "复制文本、图片、文件或链接后会显示在这里。",
          "Copy text, images, files, or links and they will appear here."
        )
      )
    }

    if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return ClipboardPanelEmptyState(
        systemName: "magnifyingglass",
        title: AppText.value("没有匹配结果", "No Matches"),
        message: AppText.value("试试其他关键词，或切换筛选类型。", "Try another keyword or switch filters.")
      )
    }

    if filter != .all {
      return ClipboardPanelEmptyState(
        systemName: filter.iconName,
        title: AppText.value("没有\(filter.localizedDisplayName)记录", "No \(filter.localizedDisplayName) Items"),
        message: AppText.value("切换到全部，或复制对应类型的内容。", "Switch to All or copy matching content.")
      )
    }

    return ClipboardPanelEmptyState(
      systemName: "tray",
      title: AppText.value("没有可显示的记录", "No Items To Show"),
      message: nil
    )
  }
}

enum ClipboardPanelLayout {
  static func cardGridColumnCount(for position: PanelPosition) -> Int {
    switch position {
    case .edgeLeft, .edgeRight:
      return 2
    case .edgeBottom, .edgeTop, .bottomDrawer, .statusItem:
      return 6
    case .cursor, .screenCenter, .mouseScreenCenter:
      return 3
    }
  }

  static func usesFixedEdgeCardHeight(for position: PanelPosition) -> Bool {
    switch position {
    case .edgeBottom, .edgeTop, .bottomDrawer, .statusItem:
      true
    case .edgeLeft, .edgeRight, .cursor, .screenCenter, .mouseScreenCenter:
      false
    }
  }
}

struct ClipboardPanelContentArea<CardContent: View, RowContent: View>: View {
  let records: [ClipboardRecord]
  let currentPage: ClipboardHistoryPage
  let viewMode: ClipboardPanelViewMode
  let panelPosition: PanelPosition
  let selectedRecordID: ClipboardRecord.ID?
  let openRevision: Int
  let emptyState: ClipboardPanelEmptyState
  let loadMoreRecords: () -> Void
  let cardContent: (ClipboardRecord) -> CardContent
  let rowContent: (ClipboardRecord) -> RowContent

  var body: some View {
    if records.isEmpty {
      EmptyHistoryView(
        systemName: emptyState.systemName,
        title: emptyState.title,
        message: emptyState.message
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    } else {
      switch viewMode {
      case .card:
        cardGrid
      case .list:
        list
      }
    }
  }

  private var cardGrid: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVGrid(columns: cardGridColumns, alignment: .leading, spacing: ClipboardPanelMetrics.cardGridSpacing) {
          ForEach(records) { record in
            cardContent(record)
              .id(record.id)
          }

          if currentPage.hasMore {
            loadMoreButton
              .frame(maxWidth: .infinity, minHeight: ClipboardPanelMetrics.cardHeight)
          }
        }
        .padding(.top, ClipboardPanelMetrics.cardContentTopPadding)
        .padding(.bottom, cardContentBottomPadding)
      }
      .scrollIndicators(.hidden)
      .frame(
        maxWidth: .infinity,
        minHeight: cardContentMinimumHeight,
        maxHeight: cardContentMaximumHeight,
        alignment: .topLeading
      )
      .onChange(of: selectedRecordID) { _, recordID in
        scrollToSelectedRecord(recordID, proxy: proxy, anchor: .center)
      }
      .onChange(of: openRevision) {
        scrollToFirstRecord(proxy: proxy)
      }
    }
  }

  private var list: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 6) {
          ForEach(records) { record in
            rowContent(record)
              .id(record.id)
          }

          if currentPage.hasMore {
            loadMoreButton
          }
        }
        .padding(.vertical, 1)
      }
      .scrollIndicators(.hidden)
      .onChange(of: selectedRecordID) { _, recordID in
        scrollToSelectedRecord(recordID, proxy: proxy, anchor: .center)
      }
      .onChange(of: openRevision) {
        scrollToFirstRecord(proxy: proxy)
      }
    }
  }

  private var loadMoreButton: some View {
    Button(action: loadMoreRecords) {
      VStack(spacing: 8) {
        Image(systemName: "chevron.down.circle")
          .font(.system(size: 22, weight: .semibold))
        Text(AppText.value("加载更多", "Load More"))
          .font(.system(size: 12, weight: .semibold))
      }
      .frame(maxWidth: .infinity, minHeight: 44)
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 12)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
  }

  private var cardGridColumns: [GridItem] {
    Array(
      repeating: GridItem(.flexible(), spacing: ClipboardPanelMetrics.cardGridSpacing),
      count: cardGridColumnCount
    )
  }

  private var cardGridColumnCount: Int {
    ClipboardPanelLayout.cardGridColumnCount(for: panelPosition)
  }

  private var cardContentMinimumHeight: CGFloat {
    cardContentUsesFixedEdgeHeight ? ClipboardPanelMetrics.edgeCardContentHeight : 0
  }

  private var cardContentMaximumHeight: CGFloat? {
    cardContentUsesFixedEdgeHeight ? ClipboardPanelMetrics.edgeCardContentHeight : .infinity
  }

  private var cardContentBottomPadding: CGFloat {
    cardContentUsesFixedEdgeHeight
      ? ClipboardPanelMetrics.edgeCardContentBottomPadding
      : ClipboardPanelMetrics.cardContentBottomPadding
  }

  private var cardContentUsesFixedEdgeHeight: Bool {
    ClipboardPanelLayout.usesFixedEdgeCardHeight(for: panelPosition)
  }

  private func scrollToFirstRecord(proxy: ScrollViewProxy) {
    guard let firstRecordID = records.first?.id else {
      return
    }
    withAnimation(.easeOut(duration: 0.16)) {
      proxy.scrollTo(firstRecordID, anchor: .top)
    }
  }

  private func scrollToSelectedRecord(
    _ recordID: ClipboardRecord.ID?,
    proxy: ScrollViewProxy,
    anchor: UnitPoint
  ) {
    guard let recordID else {
      return
    }
    withAnimation(.easeOut(duration: 0.16)) {
      proxy.scrollTo(recordID, anchor: anchor)
    }
  }
}
