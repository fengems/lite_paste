import AppKit
import LitePasteCore
import SwiftUI

struct ClipboardPanelView: View {
  private static let initialVisibleRecordLimit = 80
  private static let recordPageSize = 80
  private static let searchRefreshDebounceNanoseconds: UInt64 = 120_000_000

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
  @State private var viewMode: ClipboardPanelViewMode = AppSettingsStore.shared.settings.viewMode
  @State private var selectedRecordID: ClipboardRecord.ID?
  @State private var visibleRecordLimit = Self.initialVisibleRecordLimit
  @State private var currentPage = ClipboardHistoryPage(
    records: [],
    totalCount: 0,
    limit: Self.initialVisibleRecordLimit
  )
  @State private var pageRefreshTask: Task<Void, Never>?
  @FocusState private var searchFieldFocused: Bool

  private var queryRequest: ClipboardHistoryQuery {
    ClipboardHistoryQuery(text: query, filter: filter)
  }

  private var records: [ClipboardRecord] {
    currentPage.records
  }

  var body: some View {
    panelSurface
    .frame(minWidth: 420, minHeight: ClipboardPanelMetrics.edgePanelThickness)
    .compositingGroup()
    .background(keyboardBridge)
    .onAppear(perform: prepareForOpen)
    .onReceive(store.$records) { _ in
      refreshCurrentPage()
    }
    .onReceive(NotificationCenter.default.publisher(for: .litePasteHistoryChanged)) { _ in
      refreshCurrentPage()
    }
    .onChange(of: presentationState.openRevision) {
      prepareForOpen()
    }
    .onChange(of: query) {
      resetVisibleRecords(debounce: true)
    }
    .onChange(of: filter) {
      resetVisibleRecords()
    }
    .onChange(of: records.map(\.id)) {
      normalizeSelection()
    }
    .onDisappear {
      pageRefreshTask?.cancel()
    }
    .animation(.easeOut(duration: 0.18), value: presentationState.actionMessage)
  }

  private var panelCornerShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: ClipboardPanelMetrics.cornerRadius, style: .continuous)
  }

  private var panelBorder: some View {
    panelCornerShape
      .stroke(
        LinearGradient(
          colors: [
            Color.cyan.opacity(0.75),
            Color.blue.opacity(0.55),
            Color.purple.opacity(0.48),
            Color.orange.opacity(0.70)
          ],
          startPoint: .bottomLeading,
          endPoint: .topTrailing
        ),
        lineWidth: 1.4
      )
  }

  private var panelSurface: some View {
    ZStack {
      VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
        .ignoresSafeArea()
      panelContent
    }
    .clipShape(panelCornerShape)
    .overlay(panelInnerGlow)
    .overlay(panelBorder)
    .shadow(color: Color.black.opacity(0.20), radius: 18, y: 8)
  }

  private var panelInnerGlow: some View {
    panelCornerShape
      .stroke(
        LinearGradient(
          colors: [
            Color.cyan.opacity(0.45),
            Color.blue.opacity(0.28),
            Color.purple.opacity(0.24),
            Color.orange.opacity(0.38)
          ],
          startPoint: .bottomLeading,
          endPoint: .topTrailing
        ),
        lineWidth: 5
      )
      .blur(radius: 7)
      .opacity(0.62)
      .clipShape(panelCornerShape)
      .allowsHitTesting(false)
  }

  private var panelContent: some View {
    VStack(spacing: ClipboardPanelMetrics.panelContentSpacing) {
      topToolbar
        .zIndex(10)
      contentArea
    }
    .padding(.horizontal, ClipboardPanelMetrics.drawerHorizontalPadding)
    .padding(.vertical, ClipboardPanelMetrics.drawerVerticalPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  @ViewBuilder
  private var topToolbar: some View {
    if let topObstruction = presentationState.topObstruction {
      notchAwareToolbar(for: topObstruction)
    } else {
      ViewThatFits(in: .horizontal) {
        toolbarLine
        compactToolbar
      }
    }
  }

  private var toolbarLine: some View {
    HStack(spacing: 8) {
      searchBox
        .frame(minWidth: 180, idealWidth: 240, maxWidth: 300)

      toolbarDivider
      filterGroup(for: ClipboardFilter.allCases)

      if let actionMessage = presentationState.actionMessage {
        PanelStatusBadge(message: actionMessage)
      }

      toolbarDivider
      viewModePicker
      toolbarDivider
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
        filterGroup(for: ClipboardFilter.allCases)

        Spacer(minLength: 0)
      }
    }
  }

  private func notchAwareToolbar(for obstruction: PanelTopObstruction) -> some View {
    GeometryReader { proxy in
      let layout = obstruction.padded(by: ClipboardPanelMetrics.notchAvoidanceMargin, in: proxy.size.width)

      HStack(spacing: 0) {
        notchLeftToolbar(width: layout.leadingWidth)
          .frame(width: layout.leadingWidth, alignment: .leading)

        Color.clear
          .frame(width: layout.gapWidth)
          .accessibilityHidden(true)

        notchRightToolbar
          .frame(width: layout.trailingWidth, alignment: .trailing)
      }
      .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
    }
    .frame(height: ClipboardPanelMetrics.toolbarControlHeight)
  }

  private func notchLeftToolbar(width: CGFloat) -> some View {
    HStack(spacing: 8) {
      searchBox
        .frame(width: notchSearchWidth(for: width))

      filterGroup(for: notchLeftFilters, minWidth: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var notchRightToolbar: some View {
    HStack(spacing: 8) {
      filterGroup(for: notchRightFilters, minWidth: 0, alignment: .trailing)

      if let actionMessage = presentationState.actionMessage {
        PanelStatusBadge(message: actionMessage)
      }

      viewModePicker
      headerActions
    }
    .frame(maxWidth: .infinity, alignment: .trailing)
  }

  private var notchLeftFilters: [ClipboardFilter] {
    Array(ClipboardFilter.allCases.prefix(4))
  }

  private var notchRightFilters: [ClipboardFilter] {
    Array(ClipboardFilter.allCases.dropFirst(4))
  }

  private func notchSearchWidth(for availableWidth: CGFloat) -> CGFloat {
    min(max(availableWidth * 0.42, 160), min(260, availableWidth))
  }

  private func filterGroup(
    for filters: [ClipboardFilter],
    minWidth: CGFloat = 180,
    alignment: Alignment = .leading
  ) -> some View {
    filterChips(for: filters)
      .frame(minWidth: minWidth, maxWidth: .infinity, alignment: alignment)
  }

  private func filterChips(for filters: [ClipboardFilter]) -> some View {
    HStack(spacing: 8) {
      ForEach(filters) { option in
        ClipboardFilterChip(filter: option, isSelected: filter == option) {
          filter = option
        }
      }
    }
  }

  private var viewModePicker: some View {
    HStack(spacing: 0) {
      viewModeButton(mode: .card, systemName: "rectangle.grid.2x2", label: "卡片视图")
      viewModeButton(mode: .list, systemName: "list.bullet", label: "列表视图")
    }
    .padding(4)
    .frame(width: 82, height: 32)
    .background(Color.primary.opacity(0.060), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(Color.white.opacity(0.08), lineWidth: 1)
    )
  }

  private func viewModeButton(mode: ClipboardPanelViewMode, systemName: String, label: String) -> some View {
    let isSelected = viewMode == mode

    return Button {
      guard viewMode != mode else {
        return
      }
      viewMode = mode
      persistViewMode()
    } label: {
      Image(systemName: systemName)
        .font(.system(size: 13, weight: .semibold))
        .frame(maxWidth: .infinity, minHeight: 24)
        .foregroundStyle(isSelected ? Color.white : Color.secondary)
        .background(
          isSelected ? Color.white.opacity(0.12) : Color.clear,
          in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(alignment: .bottom) {
          if isSelected {
            Capsule()
              .fill(Color.blue)
              .frame(width: 20, height: 2)
              .offset(y: 5)
          }
        }
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
    .panelTooltip(label)
  }

  private var headerActions: some View {
    HStack(spacing: 6) {
      deleteHistoryMenu
      IconButton(systemName: "xmark", accessibilityLabel: "关闭", action: closeAction)
    }
  }

  private var deleteHistoryMenu: some View {
    Menu {
      Button(action: confirmClearUnpinned) {
        Label("清空未置顶", systemImage: "trash.slash")
      }

      Button(role: .destructive, action: confirmClearAll) {
        Label("清空全部", systemImage: "trash")
      }
    } label: {
      Image(systemName: "trash")
        .font(.system(size: 13, weight: .semibold))
        .frame(width: 26, height: 26)
        .foregroundStyle(Color.secondary)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 7, style: .continuous)
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .accessibilityLabel("清空历史")
    .panelTooltip("清空历史")
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

      if query.isEmpty {
        Text("⌘F")
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 6)
          .frame(height: 18)
          .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
          .accessibilityHidden(true)
      } else {
        Button {
          query = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("清空搜索")
        .panelTooltip("清空搜索")
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .frame(maxWidth: .infinity, minHeight: 32)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(Color.white.opacity(0.10), lineWidth: 1)
    )
  }

  private var toolbarDivider: some View {
    Rectangle()
      .fill(Color.white.opacity(0.10))
      .frame(width: 1, height: 24)
      .padding(.horizontal, 8)
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
        LazyVGrid(columns: cardGridColumns, alignment: .leading, spacing: ClipboardPanelMetrics.cardGridSpacing) {
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
      .onChange(of: presentationState.openRevision) {
        scrollToSelectedRecord(selectedRecordID, proxy: proxy, anchor: .top)
      }
    }
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
    switch settingsStore.settings.panelPosition {
    case .edgeBottom, .edgeTop, .bottomDrawer, .statusItem:
      true
    case .edgeLeft, .edgeRight, .cursor, .mouseScreenCenter:
      false
    }
  }

  private var cardGridColumns: [GridItem] {
    Array(
      repeating: GridItem(.flexible(), spacing: ClipboardPanelMetrics.cardGridSpacing),
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
      toggleFavorite: { store.toggleFavorite(record.id) },
      togglePinned: { store.togglePinned(record.id) },
      deleteAction: { confirmDelete(record) }
    )
  }

  private var emptyState: (systemName: String, title: String, message: String?) {
    if store.allRecordCount() == 0 {
      if settingsStore.settings.isMonitoringPaused {
        return ("pause.circle", "已停止监听剪贴板", "关闭停止监听后，新的剪贴板内容会继续保存到历史。")
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

  private func handleKeyDown(_ event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
    let commandOnly = modifiers == .command

    if commandOnly, let index = commandNumberSelectionIndex(from: event) {
      selectRecord(at: index)
      return true
    }
    if commandOnly, event.charactersIgnoringModifiers?.lowercased() == "f" {
      focusSearchField()
      return true
    }
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

  private func focusSearchField() {
    searchFieldFocused = true
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

  private func selectRecord(at index: Int) {
    guard records.indices.contains(index) else {
      return
    }

    selectedRecordID = records[index].id
  }

  private func commandNumberSelectionIndex(from event: NSEvent) -> Int? {
    guard let characters = event.charactersIgnoringModifiers,
          characters.count == 1,
          let number = Int(characters),
          (1...6).contains(number) else {
      return nil
    }

    return number - 1
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
    resetVisibleRecords(debounce: false)
  }

  private func resetVisibleRecords(debounce: Bool) {
    visibleRecordLimit = Self.initialVisibleRecordLimit
    refreshCurrentPage(
      selectFirst: false,
      debounceNanoseconds: debounce ? Self.searchRefreshDebounceNanoseconds : 0
    )
  }

  private func selectFirstRecord() {
    refreshCurrentPage(selectFirst: true)
  }

  private func loadMoreRecords() {
    visibleRecordLimit += Self.recordPageSize
    refreshCurrentPage()
  }

  private func refreshCurrentPage() {
    refreshCurrentPage(selectFirst: false)
  }

  private func refreshCurrentPage(
    selectFirst: Bool,
    debounceNanoseconds: UInt64 = 0
  ) {
    let request = queryRequest
    let limit = visibleRecordLimit
    pageRefreshTask?.cancel()
    pageRefreshTask = Task { @MainActor in
      if debounceNanoseconds > 0 {
        do {
          try await Task.sleep(nanoseconds: debounceNanoseconds)
        } catch {
          return
        }
      }

      let page = await store.filteredPageAsync(request, limit: limit)
      guard !Task.isCancelled else {
        return
      }

      currentPage = page
      if selectFirst {
        selectedRecordID = page.records.first?.id
      } else {
        normalizeSelection()
      }
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
