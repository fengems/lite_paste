import AppKit
import LitePasteCore
import SwiftUI

struct ClipboardPanelView: View {
  private static let initialVisibleRecordLimit = 80
  private static let recordPageSize = 80

  @ObservedObject var store: HistoryStore
  @ObservedObject var presentationState: PanelPresentationState
  let copyAction: (ClipboardRecord) -> Void
  let copyPlainTextAction: (ClipboardRecord) -> Void
  let pasteAction: (ClipboardRecord) -> Void
  let pastePlainTextAction: (ClipboardRecord) -> Void
  let primaryCopyAction: (ClipboardRecord) -> Void
  let primaryPasteAction: (ClipboardRecord) -> Void
  let closeAction: () -> Void

  @ObservedObject private var settingsStore = AppSettingsStore.shared
  @State private var itemActions = ClipboardItemActions()
  @State private var query = ""
  @State private var filter: ClipboardFilter = .all
  @State private var sort: ClipboardHistorySort = .pinnedThenRecent
  @State private var viewMode: ClipboardPanelViewMode = AppSettingsStore.shared.settings.viewMode
  @State private var selectedRecordID: ClipboardRecord.ID?
  @State private var visibleRecordLimit = Self.initialVisibleRecordLimit
  @FocusState private var searchFieldFocused: Bool

  private var queryRequest: ClipboardHistoryQuery {
    ClipboardHistoryQuery(text: query, filter: filter, sort: sort)
  }

  private var currentPage: ClipboardHistoryPage {
    store.filteredPage(queryRequest, limit: visibleRecordLimit)
  }

  private var records: [ClipboardRecord] {
    currentPage.records
  }

  var body: some View {
    ZStack {
      VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
        .ignoresSafeArea()
      panelContent
    }
    .frame(minWidth: 420, minHeight: ClipboardPanelMetrics.edgePanelThickness)
    .background(keyboardBridge)
    .onAppear(perform: prepareForOpen)
    .onChange(of: presentationState.openRevision) {
      prepareForOpen()
    }
    .onChange(of: query) {
      resetVisibleRecords()
    }
    .onChange(of: filter) {
      resetVisibleRecords()
    }
    .onChange(of: sort) {
      resetVisibleRecords()
    }
    .onChange(of: records.map(\.id)) {
      normalizeSelection()
    }
    .animation(.easeOut(duration: 0.18), value: presentationState.actionMessage)
  }

  private var panelContent: some View {
    VStack(spacing: ClipboardPanelMetrics.panelContentSpacing) {
      topToolbar
      contentArea
    }
    .padding(.horizontal, ClipboardPanelMetrics.drawerHorizontalPadding)
    .padding(.vertical, ClipboardPanelMetrics.drawerVerticalPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .clipShape(RoundedRectangle(cornerRadius: ClipboardPanelMetrics.cornerRadius))
    .overlay(
      RoundedRectangle(cornerRadius: ClipboardPanelMetrics.cornerRadius)
        .stroke(Color.white.opacity(0.16), lineWidth: 1)
    )
  }

  private var topToolbar: some View {
    ViewThatFits(in: .horizontal) {
      toolbarLine
      compactToolbar
    }
  }

  private var toolbarLine: some View {
    HStack(spacing: 8) {
      searchBox
        .frame(minWidth: 180, idealWidth: 240, maxWidth: 300)

      filterScroller

      Text(resultSummary)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .fixedSize()

      if let actionMessage = presentationState.actionMessage {
        PanelStatusBadge(message: actionMessage)
      }

      viewModePicker
      sortPicker
      headerActions
    }
  }

  private var compactToolbar: some View {
    VStack(spacing: 7) {
      HStack(spacing: 8) {
        searchBox

        if let actionMessage = presentationState.actionMessage {
          PanelStatusBadge(message: actionMessage)
        }

        viewModePicker
        headerActions
      }

      HStack(spacing: 8) {
        filterScroller
        sortPicker

        Text(resultSummary)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .fixedSize()
      }
    }
  }

  private var filterScroller: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        ForEach(ClipboardFilter.allCases) { option in
          ClipboardFilterChip(filter: option, isSelected: filter == option) {
            filter = option
          }
        }
      }
    }
    .frame(minWidth: 180, maxWidth: .infinity)
  }

  private var viewModePicker: some View {
    Picker("", selection: $viewMode) {
      Image(systemName: "rectangle.grid.2x2").tag(ClipboardPanelViewMode.card)
      Image(systemName: "list.bullet").tag(ClipboardPanelViewMode.list)
    }
    .pickerStyle(.segmented)
    .frame(width: 82)
    .onChange(of: viewMode) {
      persistViewMode()
    }
  }

  private var sortPicker: some View {
    Picker("", selection: $sort) {
      Label("最近", systemImage: "clock").tag(ClipboardHistorySort.recent)
      Label("常用", systemImage: "number").tag(ClipboardHistorySort.mostUsed)
      Label("置顶", systemImage: "pin").tag(ClipboardHistorySort.pinnedThenRecent)
    }
    .pickerStyle(.segmented)
    .frame(width: 166)
  }

  private var headerActions: some View {
    HStack(spacing: 6) {
      IconButton(systemName: "trash.slash", accessibilityLabel: "清空未置顶", action: confirmClearUnpinned)
      IconButton(systemName: "trash", accessibilityLabel: "清空全部", action: confirmClearAll)
      IconButton(systemName: "xmark", accessibilityLabel: "关闭", action: closeAction)
    }
  }

  private var searchBox: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)

      TextField("搜索剪贴板", text: $query)
        .textFieldStyle(.plain)
        .font(.system(size: 13))
        .focused($searchFieldFocused)

      if !query.isEmpty {
        Button {
          query = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("清空搜索")
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .frame(maxWidth: .infinity, minHeight: 32)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
  }

  @ViewBuilder
  private var contentArea: some View {
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
        cardContent
      case .list:
        listContent
      }
    }
  }

  private var cardContent: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVGrid(columns: cardGridColumns, alignment: .leading, spacing: 10) {
          ForEach(records) { record in
            card(for: record)
              .id(record.id)
          }

          if currentPage.hasMore {
            loadMoreButton
              .frame(maxWidth: .infinity, minHeight: ClipboardPanelMetrics.cardHeight)
          }
        }
        .padding(.top, ClipboardPanelMetrics.cardContentTopPadding)
        .padding(.bottom, ClipboardPanelMetrics.cardContentBottomPadding)
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
      .onChange(of: presentationState.openRevision) {
        scrollToSelectedRecord(selectedRecordID, proxy: proxy, anchor: .top)
      }
    }
  }

  private var cardContentMinimumHeight: CGFloat {
    cardContentUsesSingleRowHeight ? ClipboardPanelMetrics.cardContentHeight : 0
  }

  private var cardContentMaximumHeight: CGFloat? {
    cardContentUsesSingleRowHeight ? ClipboardPanelMetrics.cardContentHeight : .infinity
  }

  private var cardContentUsesSingleRowHeight: Bool {
    switch settingsStore.settings.panelPosition {
    case .edgeBottom, .edgeTop, .bottomDrawer, .statusItem:
      true
    case .edgeLeft, .edgeRight, .cursor, .mouseScreenCenter:
      false
    }
  }

  private var cardGridColumns: [GridItem] {
    Array(
      repeating: GridItem(.flexible(), spacing: 10),
      count: cardGridColumnCount
    )
  }

  private var cardGridColumnCount: Int {
    switch settingsStore.settings.panelPosition {
    case .edgeLeft, .edgeRight:
      return 2
    case .edgeBottom, .edgeTop, .bottomDrawer, .statusItem:
      return 6
    case .cursor, .mouseScreenCenter:
      return 3
    }
  }

  private var listContent: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 6) {
          ForEach(records) { record in
            row(for: record)
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
      .onChange(of: presentationState.openRevision) {
        scrollToSelectedRecord(selectedRecordID, proxy: proxy, anchor: .top)
      }
    }
  }

  private var loadMoreButton: some View {
    Button(action: loadMoreRecords) {
      VStack(spacing: 8) {
        Image(systemName: "chevron.down.circle")
          .font(.system(size: 22, weight: .semibold))
        Text("加载更多")
          .font(.system(size: 12, weight: .semibold))
      }
      .frame(maxWidth: .infinity, minHeight: 44)
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 12)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
  }

  private func card(for record: ClipboardRecord) -> some View {
    ClipboardCard(
      record: record,
      isSelected: selectedRecordID == record.id,
      primaryAction: primaryAction,
      copyAction: copyAction,
      copyPlainTextAction: copyPlainTextAction,
      pasteAction: pasteAction,
      pastePlainTextAction: pastePlainTextAction,
      externalAction: itemActions.primaryExternalAction(for: record),
      performExternalAction: { handleExternalActionResult(itemActions.perform($0, for: record)) },
      editNote: { editNote(record) },
      editPinShortcut: { editPinShortcut(record) },
      toggleFavorite: { store.toggleFavorite(record.id) },
      togglePinned: { store.togglePinned(record.id) },
      deleteAction: { confirmDelete(record) }
    )
  }

  private func row(for record: ClipboardRecord) -> some View {
    ClipboardRow(
      record: record,
      isSelected: selectedRecordID == record.id,
      primaryAction: primaryAction,
      copyAction: copyAction,
      copyPlainTextAction: copyPlainTextAction,
      pasteAction: pasteAction,
      pastePlainTextAction: pastePlainTextAction,
      externalAction: itemActions.primaryExternalAction(for: record),
      performExternalAction: { handleExternalActionResult(itemActions.perform($0, for: record)) },
      editNote: { editNote(record) },
      editPinShortcut: { editPinShortcut(record) },
      toggleFavorite: { store.toggleFavorite(record.id) },
      togglePinned: { store.togglePinned(record.id) },
      deleteAction: { confirmDelete(record) }
    )
  }

  private var resultSummary: String {
    guard currentPage.totalCount > 0 else {
      return "0 条"
    }
    return currentPage.hasMore ? "显示 \(records.count) / \(currentPage.totalCount) 条" : "\(currentPage.totalCount) 条"
  }

  private var emptyState: (systemName: String, title: String, message: String?) {
    if store.allRecordCount() == 0 {
      if settingsStore.settings.privacyMode {
        return ("lock.shield", "私密模式已开启", "新的剪贴板内容暂不会保存到历史。")
      }
      if settingsStore.settings.enabledTypes.isEmpty {
        return ("line.3.horizontal.decrease.circle", "没有启用记录类型", "在设置中启用至少一种剪贴板类型后才会保存历史。")
      }
      return ("doc.on.clipboard", "暂无剪贴板历史", "复制文本、图片、文件或链接后会显示在这里。")
    }

    if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return ("magnifyingglass", "没有匹配结果", "试试其他关键词，或切换筛选类型。")
    }

    if filter != .all {
      if filterDisabledBySettings {
        return (filter.iconName, "\(filter.displayName)记录已关闭", "在设置中启用该类型后，新内容会继续进入历史。")
      }
      return (filter.iconName, "没有\(filter.displayName)记录", "切换到全部，或复制对应类型的内容。")
    }

    return ("tray", "没有可显示的记录", nil)
  }

  private var filterDisabledBySettings: Bool {
    let enabledTypes = settingsStore.settings.enabledTypes
    switch filter {
    case .all, .favorites, .pinned:
      return false
    case .text:
      return enabledTypes.intersection([.text, .richText, .html]).isEmpty
    case .images:
      return !enabledTypes.contains(.image)
    case .files:
      return !enabledTypes.contains(.files)
    case .links:
      return enabledTypes.intersection([.url, .email]).isEmpty
    case .colors:
      return !enabledTypes.contains(.color)
    }
  }

  private var keyboardBridge: some View {
    PanelKeyboardBridge { event in
      handleKeyDown(event)
    }
    .frame(width: 0, height: 0)
  }

  private func primaryAction(_ record: ClipboardRecord) {
    selectedRecordID = record.id
    switch settingsStore.settings.autoPasteMode {
    case .copyOnly:
      primaryCopyAction(record)
    case .paste:
      primaryPasteAction(record)
    }
  }

  private func confirmClearUnpinned() {
    let count = store.unpinnedRecordCount()
    guard count > 0 else {
      return
    }
    if confirm(title: "清空未置顶历史？", message: "将删除 \(count) 条未置顶记录，置顶记录会保留。此操作无法撤销。") {
      store.clearUnpinned()
    }
  }

  private func confirmClearAll() {
    let count = store.allRecordCount()
    guard count > 0 else {
      return
    }
    if confirm(title: "清空全部历史？", message: "将删除全部 \(count) 条剪贴板历史，包含置顶记录。此操作无法撤销。") {
      store.clearAll()
    }
  }

  private func confirmDelete(_ record: ClipboardRecord) {
    if confirm(title: "删除这条历史？", message: "“\(record.title)”会从剪贴板历史中移除。此操作无法撤销。") {
      store.delete(record.id)
      normalizeSelection()
    }
  }

  private func confirm(title: String, message: String) -> Bool {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: "确认")
    alert.addButton(withTitle: "取消")
    alert.alertStyle = .warning
    return alert.runModal() == .alertFirstButtonReturn
  }

  private func editNote(_ record: ClipboardRecord) {
    guard let note = NoteEditor.edit(record: record) else {
      return
    }
    store.updateNote(record.id, note: note)
  }

  private func handleExternalActionResult(_ result: ClipboardExternalActionResult) {
    switch result {
    case let .completed(message):
      presentationState.showActionMessage(message)
    case let .failed(title, message):
      showAlert(title: title, message: message, style: .warning)
    }
  }

  private func editPinShortcut(_ record: ClipboardRecord) {
    let result = PinShortcutEditor.edit(record: record, usedShortcuts: store.usedPinShortcuts(excluding: record.id))
    if case let .save(shortcut) = result {
      store.updatePinShortcut(record.id, shortcut: shortcut)
    }
  }

  private func handleKeyDown(_ event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
    let commandOnly = modifiers == .command

    if commandOnly, event.charactersIgnoringModifiers?.lowercased() == "c" {
      return copySelected()
    }
    if modifiers == [.command, .shift], event.charactersIgnoringModifiers?.lowercased() == "c" {
      return copySelected(asPlainText: true)
    }
    if commandOnly, event.keyCode == 51 {
      return deleteSelected()
    }
    if modifiers == [.command, .shift], [36, 76].contains(event.keyCode) {
      return pasteSelected(asPlainText: true)
    }
    guard modifiers.isEmpty else {
      return false
    }

    switch event.keyCode {
    case 53:
      closeAction()
      return true
    case 36, 76:
      return pasteSelected()
    case 117:
      return deleteSelected()
    case 123:
      selectRelative(-1)
      return true
    case 124:
      selectRelative(1)
      return true
    case 126:
      selectRelative(verticalSelectionOffset(direction: -1))
      return true
    case 125:
      selectRelative(verticalSelectionOffset(direction: 1))
      return true
    default:
      return false
    }
  }

  private func copySelected(asPlainText: Bool = false) -> Bool {
    guard let record = selectedRecord else {
      return false
    }
    asPlainText ? copyPlainTextAction(record) : copyAction(record)
    return true
  }

  private func pasteSelected(asPlainText: Bool = false) -> Bool {
    guard let record = selectedRecord else {
      return false
    }
    asPlainText ? pastePlainTextAction(record) : pasteAction(record)
    return true
  }

  private func deleteSelected() -> Bool {
    guard let record = selectedRecord else {
      return false
    }
    confirmDelete(record)
    return true
  }

  private func selectRelative(_ offset: Int) {
    guard !records.isEmpty else {
      selectedRecordID = nil
      return
    }
    let currentIndex = records.firstIndex { $0.id == selectedRecordID } ?? 0
    if offset > 0, currentIndex == records.count - 1, currentPage.hasMore {
      loadMoreRecords()
    }
    let nextIndex = min(max(currentIndex + offset, 0), records.count - 1)
    selectedRecordID = records[nextIndex].id
  }

  private func verticalSelectionOffset(direction: Int) -> Int {
    guard viewMode == .card else {
      return direction
    }
    return direction * cardGridColumnCount
  }

  private func normalizeSelection() {
    guard !records.isEmpty else {
      selectedRecordID = nil
      return
    }
    if let selectedRecordID, records.contains(where: { $0.id == selectedRecordID }) {
      return
    }
    selectedRecordID = records[0].id
  }

  private var selectedRecord: ClipboardRecord? {
    records.first { $0.id == selectedRecordID }
  }

  private func prepareForOpen() {
    viewMode = settingsStore.settings.viewMode
    visibleRecordLimit = Self.initialVisibleRecordLimit
    if settingsStore.settings.clearSearchOnOpen {
      query = ""
    }
    searchFieldFocused = false
    if settingsStore.settings.focusSearchOnOpen {
      DispatchQueue.main.async {
        searchFieldFocused = true
      }
    }
    selectFirstRecord()
  }

  private func resetVisibleRecords() {
    visibleRecordLimit = Self.initialVisibleRecordLimit
    normalizeSelection()
  }

  private func selectFirstRecord() {
    selectedRecordID = records.first?.id
  }

  private func loadMoreRecords() {
    visibleRecordLimit += Self.recordPageSize
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

  private func persistViewMode() {
    guard settingsStore.settings.viewMode != viewMode else {
      return
    }
    settingsStore.update { $0.viewMode = viewMode }
  }

  private func showAlert(title: String, message: String, style: NSAlert.Style) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: "好")
    alert.alertStyle = style
    alert.runModal()
  }
}
