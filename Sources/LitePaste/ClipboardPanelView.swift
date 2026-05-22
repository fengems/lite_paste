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

  @State private var itemActions = ClipboardItemActions()
  @ObservedObject private var settingsStore = AppSettingsStore.shared
  @State private var query = ""
  @State private var filter: ClipboardFilter = .all
  @State private var sort: ClipboardHistorySort = .pinnedThenRecent
  @State private var viewMode: ClipboardPanelViewMode = AppSettingsStore.shared.settings.viewMode
  @State private var selectedRecordID: ClipboardRecord.ID?
  @State private var visibleRecordLimit = Self.initialVisibleRecordLimit
  @FocusState private var searchFieldFocused: Bool

  private var queryRequest: ClipboardHistoryQuery {
    ClipboardHistoryQuery(
      text: query,
      filter: filter,
      sort: sort
    )
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

      VStack(spacing: 16) {
        header
        filters

        if records.isEmpty {
          EmptyHistoryView()
        } else {
          content
        }
      }
      .padding(20)
    }
    .frame(minWidth: 720, minHeight: 460)
    .background(
      PanelKeyboardBridge { event in
        handleKeyDown(event)
      }
      .frame(width: 0, height: 0)
    )
    .onAppear {
      normalizeSelection()
    }
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
  }

  private var header: some View {
    HStack(spacing: 12) {
      Image(systemName: "doc.on.clipboard")
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(.primary)

      TextField("搜索", text: $query)
        .textFieldStyle(.plain)
        .font(.system(size: 16))
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .focused($searchFieldFocused)

      Picker("", selection: $viewMode) {
        Image(systemName: "rectangle.grid.2x2").tag(ClipboardPanelViewMode.card)
        Image(systemName: "list.bullet").tag(ClipboardPanelViewMode.list)
      }
      .pickerStyle(.segmented)
      .frame(width: 92)
      .onChange(of: viewMode) {
        persistViewMode()
      }

      IconButton(
        systemName: "trash.slash",
        accessibilityLabel: "清空未置顶",
        action: confirmClearUnpinned
      )

      IconButton(
        systemName: "trash",
        accessibilityLabel: "清空全部",
        action: confirmClearAll
      )
    }
  }

  private var filters: some View {
    HStack(spacing: 8) {
      ForEach(ClipboardFilter.allCases) { option in
        Button {
          filter = option
        } label: {
          Text(option.displayName)
            .font(.system(size: 13, weight: filter == option ? .semibold : .regular))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(filter == option ? .regularMaterial : .thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
      }

      Spacer()

      Picker("", selection: $sort) {
        Label("置顶", systemImage: "pin").tag(ClipboardHistorySort.pinnedThenRecent)
        Label("最近", systemImage: "clock").tag(ClipboardHistorySort.recent)
        Label("常用", systemImage: "number").tag(ClipboardHistorySort.mostUsed)
      }
      .pickerStyle(.segmented)
      .frame(width: 180)
    }
  }

  @ViewBuilder
  private var content: some View {
    switch viewMode {
    case .card:
      cardContent
    case .list:
      listContent
    }
  }

  private var cardContent: some View {
    ScrollView(.horizontal) {
      LazyHStack(alignment: .top, spacing: 12) {
        ForEach(records) { record in
          ClipboardCard(
            record: record,
            isSelected: selectedRecordID == record.id,
            primaryAction: primaryAction,
            copyAction: copyAction,
            copyPlainTextAction: copyPlainTextAction,
            pasteAction: pasteAction,
            pastePlainTextAction: pastePlainTextAction,
            externalAction: itemActions.primaryExternalAction(for: record),
            performExternalAction: {
              handleExternalActionResult(itemActions.perform($0, for: record))
            },
            editNote: {
              editNote(record)
            },
            editPinShortcut: {
              editPinShortcut(record)
            }
          ) {
            store.toggleFavorite(record.id)
          } togglePinned: {
            store.togglePinned(record.id)
          } deleteAction: {
            confirmDelete(record)
          }
        }

        if currentPage.hasMore {
          loadMoreButton
            .frame(width: 180, height: 220)
        }
      }
      .padding(.vertical, 4)
    }
  }

  private var listContent: some View {
    ScrollView {
      LazyVStack(spacing: 8) {
        ForEach(records) { record in
          ClipboardRow(
            record: record,
            isSelected: selectedRecordID == record.id,
            primaryAction: primaryAction,
            copyAction: copyAction,
            copyPlainTextAction: copyPlainTextAction,
            pasteAction: pasteAction,
            pastePlainTextAction: pastePlainTextAction,
            externalAction: itemActions.primaryExternalAction(for: record),
            performExternalAction: {
              handleExternalActionResult(itemActions.perform($0, for: record))
            },
            editNote: {
              editNote(record)
            },
            editPinShortcut: {
              editPinShortcut(record)
            }
          ) {
            store.toggleFavorite(record.id)
          } togglePinned: {
            store.togglePinned(record.id)
          } deleteAction: {
            confirmDelete(record)
          }
        }

        if currentPage.hasMore {
          loadMoreButton
        }
      }
      .padding(.vertical, 4)
    }
  }

  private var loadMoreButton: some View {
    Button {
      loadMoreRecords()
    } label: {
      Label("加载更多", systemImage: "chevron.down")
        .font(.system(size: 13, weight: .semibold))
        .frame(maxWidth: .infinity, minHeight: 44)
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 12)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
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

    let alert = NSAlert()
    alert.messageText = "清空未置顶历史？"
    alert.informativeText = "将删除 \(count) 条未置顶记录，置顶记录会保留。此操作无法撤销。"
    alert.addButton(withTitle: "清空")
    alert.addButton(withTitle: "取消")
    alert.alertStyle = .warning

    if alert.runModal() == .alertFirstButtonReturn {
      store.clearUnpinned()
    }
  }

  private func confirmClearAll() {
    let alert = NSAlert()
    alert.messageText = "清空全部历史？"
    alert.informativeText = "所有未导出的剪贴板历史都会被删除，此操作无法撤销。"
    alert.addButton(withTitle: "清空")
    alert.addButton(withTitle: "取消")
    alert.alertStyle = .warning

    if alert.runModal() == .alertFirstButtonReturn {
      store.clearAll()
    }
  }

  private func confirmDelete(_ record: ClipboardRecord) {
    let alert = NSAlert()
    alert.messageText = "删除这条历史？"
    alert.informativeText = "“\(record.title)”会从剪贴板历史中移除。此操作无法撤销。"
    alert.addButton(withTitle: "删除")
    alert.addButton(withTitle: "取消")
    alert.alertStyle = .warning

    if alert.runModal() == .alertFirstButtonReturn {
      store.delete(record.id)
      normalizeSelection()
    }
  }

  private func editNote(_ record: ClipboardRecord) {
    guard let note = NoteEditor.edit(record: record) else {
      return
    }

    store.updateNote(record.id, note: note)
  }

  private func handleExternalActionResult(_ result: ClipboardExternalActionResult) {
    switch result {
    case .completed:
      break
    case let .exportedImage(url):
      showAlert(
        title: "图片已导出",
        message: "已保存到“\(url.lastPathComponent)”。",
        style: .informational
      )
    case let .failed(title, message):
      showAlert(title: title, message: message, style: .warning)
    }
  }

  private func editPinShortcut(_ record: ClipboardRecord) {
    let result = PinShortcutEditor.edit(
      record: record,
      usedShortcuts: store.usedPinShortcuts(excluding: record.id)
    )

    if case let .save(shortcut) = result {
      store.updatePinShortcut(record.id, shortcut: shortcut)
    }
  }

  private func handleKeyDown(_ event: NSEvent) -> Bool {
    let significantModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
    let commandOnly = significantModifiers == .command

    if commandOnly, event.charactersIgnoringModifiers?.lowercased() == "c" {
      return copySelected()
    }

    if significantModifiers == [.command, .shift],
       event.charactersIgnoringModifiers?.lowercased() == "c" {
      return copySelected(asPlainText: true)
    }

    if commandOnly, event.keyCode == 51 {
      return deleteSelected()
    }

    if significantModifiers == [.command, .shift],
       [36, 76].contains(event.keyCode) {
      return pasteSelected(asPlainText: true)
    }

    guard significantModifiers.isEmpty else {
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
    case 123, 126:
      selectRelative(-1)
      return true
    case 124, 125:
      selectRelative(1)
      return true
    default:
      return false
    }
  }

  private func copySelected(asPlainText: Bool = false) -> Bool {
    guard let record = selectedRecord else {
      return false
    }

    if asPlainText {
      copyPlainTextAction(record)
    } else {
      copyAction(record)
    }
    return true
  }

  private func pasteSelected(asPlainText: Bool = false) -> Bool {
    guard let record = selectedRecord else {
      return false
    }

    if asPlainText {
      pastePlainTextAction(record)
    } else {
      primaryAction(record)
    }
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

    let expandedRecords = records
    let nextIndex = min(max(currentIndex + offset, 0), expandedRecords.count - 1)
    selectedRecordID = expandedRecords[nextIndex].id
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
    normalizeSelection()
  }

  private var selectedRecord: ClipboardRecord? {
    records.first { $0.id == selectedRecordID }
  }

  private func resetVisibleRecords() {
    visibleRecordLimit = Self.initialVisibleRecordLimit
    normalizeSelection()
  }

  private func loadMoreRecords() {
    visibleRecordLimit += Self.recordPageSize
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
