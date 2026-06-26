import Foundation
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
  let openSettingsAction: () -> Void
  let closeAction: () -> Void

  @ObservedObject private var settingsStore = AppSettingsStore.shared
  @State private var recordActions = ClipboardRecordActions()
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
    ClipboardPanelSurface {
      panelContent
    }
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
    ClipboardPanelToolbar(
      query: $query,
      filter: $filter,
      viewMode: $viewMode,
      searchFieldFocused: $searchFieldFocused,
      topObstruction: presentationState.topObstruction,
      actionMessage: presentationState.actionMessage,
      openSettingsAction: openSettingsAction,
      clearUnpinnedAction: confirmClearUnpinned,
      clearAllAction: confirmClearAll,
      closeAction: closeAction,
      viewModeDidChange: persistViewMode
    )
  }

  @ViewBuilder
  private var contentArea: some View {
    ClipboardPanelContentArea(
      records: records,
      currentPage: currentPage,
      viewMode: viewMode,
      panelPosition: settingsStore.settings.panelPosition,
      selectedRecordID: selectedRecordID,
      openRevision: presentationState.openRevision,
      emptyState: emptyState,
      loadMoreRecords: loadMoreRecords,
      cardContent: { card(for: $0) },
      rowContent: { row(for: $0) }
    )
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
      externalAction: recordActions.primaryExternalAction(for: record),
      performExternalAction: { handleExternalActionResult(recordActions.perform($0, for: record)) },
      editNote: { editNote(record) },
      toggleFavorite: { store.toggleFavorite(record.id) },
      togglePinned: { store.togglePinned(record.id) },
      deleteAction: { confirmDelete(record) },
      visibleQuickActions: settingsStore.settings.visibleQuickActions
    )
    .equatable()
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
      externalAction: recordActions.primaryExternalAction(for: record),
      performExternalAction: { handleExternalActionResult(recordActions.perform($0, for: record)) },
      editNote: { editNote(record) },
      toggleFavorite: { store.toggleFavorite(record.id) },
      togglePinned: { store.togglePinned(record.id) },
      deleteAction: { confirmDelete(record) },
      visibleQuickActions: settingsStore.settings.visibleQuickActions
    )
    .equatable()
  }

  private var emptyState: ClipboardPanelEmptyState {
    ClipboardPanelEmptyState.resolve(
      allRecordCount: store.allRecordCount(),
      isMonitoringPaused: settingsStore.settings.isMonitoringPaused,
      query: query,
      filter: filter
    )
  }

  private var keyboardBridge: some View {
    PanelKeyboardBridge { event in
      keyboardActions.handle(event)
    }
    .frame(width: 0, height: 0)
  }

  private var keyboardActions: ClipboardPanelKeyboardActions {
    ClipboardPanelKeyboardActions(
      close: closeAction,
      copySelected: copySelected,
      deleteSelected: deleteSelected,
      focusSearch: focusSearchField,
      navigate: navigateSelection,
      pasteNumber: pasteRecordForCommandNumber,
      pasteSelected: pasteSelected,
      selectRowBoundary: selectRowBoundary
    )
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
    if ClipboardPanelConfirmations.confirmClearUnpinned(count: count) {
      store.clearUnpinned()
    }
  }

  private func confirmClearAll() {
    let count = store.allRecordCount()
    if ClipboardPanelConfirmations.confirmClearAll(count: count) {
      store.clearAll()
    }
  }

  private func confirmDelete(_ record: ClipboardRecord) {
    if ClipboardPanelConfirmations.confirmDelete(recordTitle: record.title) {
      store.delete(record.id)
      normalizeSelection()
    }
  }

  private func editNote(_ record: ClipboardRecord) {
    guard let note = NoteEditor.edit(record: record) else {
      return
    }
    store.updateNote(
      record.id,
      note: note,
      autoFavorite: settingsStore.settings.autoFavoriteAfterNote
    )
  }

  private func handleExternalActionResult(_ result: ClipboardExternalActionResult) {
    switch result {
    case let .completed(message):
      presentationState.showActionMessage(message)
    case let .failed(title, message):
      UserAlerts.showMessage(title: title, message: message, style: .warning)
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

  private func selectHorizontal(direction: Int) -> Bool {
    applySelection(
      ClipboardPanelSelection.selectHorizontal(
        direction: direction,
        records: records,
        selectedRecordID: selectedRecordID,
        viewMode: viewMode,
        cardGridColumnCount: cardGridColumnCount,
        hasMore: currentPage.hasMore
      )
    )
    return true
  }

  private func selectVertical(direction: Int) -> Bool {
    applySelection(
      ClipboardPanelSelection.selectVertical(
        direction: direction,
        records: records,
        selectedRecordID: selectedRecordID,
        viewMode: viewMode,
        cardGridColumnCount: cardGridColumnCount,
        hasMore: currentPage.hasMore
      )
    )
    return true
  }

  private func navigateSelection(_ key: PanelNavigationKey) -> Bool {
    switch key {
    case .left:
      return selectHorizontal(direction: -1)
    case .right:
      return selectHorizontal(direction: 1)
    case .up:
      return selectVertical(direction: -1)
    case .down:
      return selectVertical(direction: 1)
    case .home:
      return selectRowBoundary(.leading)
    case .end:
      return selectRowBoundary(.trailing)
    }
  }

  private func selectRowBoundary(_ boundary: PanelRowBoundary) -> Bool {
    applySelection(
      ClipboardPanelSelection.selectRowBoundary(
        boundary,
        records: records,
        selectedRecordID: selectedRecordID,
        viewMode: viewMode,
        cardGridColumnCount: cardGridColumnCount
      )
    )
    return true
  }

  private func applySelection(_ result: ClipboardPanelSelection.Result) {
    if result.shouldLoadMore {
      loadMoreRecords()
    }
    selectedRecordID = result.selectedRecordID
  }

  private func pasteRecordForCommandNumber(_ number: Int) -> Bool {
    guard let record = recordForCommandNumber(number) else {
      return true
    }

    selectedRecordID = record.id
    primaryPasteAction(record)
    return true
  }

  private func recordForCommandNumber(_ number: Int) -> ClipboardRecord? {
    ClipboardPanelSelection.recordForCommandNumber(
      number,
      records: records,
      selectedRecordID: selectedRecordID,
      viewMode: viewMode,
      cardGridColumnCount: cardGridColumnCount
    )
  }

  private func normalizeSelection() {
    selectedRecordID = ClipboardPanelSelection.normalizedSelectionID(
      in: records,
      selectedRecordID: selectedRecordID
    )
  }

  private var selectedRecord: ClipboardRecord? {
    ClipboardPanelSelection.selectedRecord(in: records, selectedRecordID: selectedRecordID)
  }

  private var cardGridColumnCount: Int {
    ClipboardPanelLayout.cardGridColumnCount(for: settingsStore.settings.panelPosition)
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

  private func persistViewMode() {
    guard settingsStore.settings.viewMode != viewMode else {
      return
    }
    settingsStore.update { $0.viewMode = viewMode }
  }

}
