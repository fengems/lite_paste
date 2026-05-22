import AppKit
import LitePasteCore
import SwiftUI

struct ClipboardPanelView: View {
  @ObservedObject var store: HistoryStore
  let copyAction: (ClipboardRecord) -> Void
  let pasteAction: (ClipboardRecord) -> Void

  @State private var itemActions = ClipboardItemActions()
  @StateObject private var settingsStore = AppSettingsStore()
  @State private var query = ""
  @State private var filter: ClipboardFilter = .all
  @State private var sort: ClipboardHistorySort = .pinnedThenRecent
  @State private var viewMode: PanelViewMode = .card

  private var records: [ClipboardRecord] {
    store.filteredRecords(
      ClipboardHistoryQuery(
        text: query,
        filter: filter,
        sort: sort
      )
    )
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

      Picker("", selection: $viewMode) {
        Image(systemName: "rectangle.grid.2x2").tag(PanelViewMode.card)
        Image(systemName: "list.bullet").tag(PanelViewMode.list)
      }
      .pickerStyle(.segmented)
      .frame(width: 92)

      IconButton(
        systemName: "trash.slash",
        accessibilityLabel: "清空未置顶",
        action: {
          store.clearUnpinned()
        }
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
      HStack(alignment: .top, spacing: 12) {
        ForEach(records) { record in
          ClipboardCard(
            record: record,
            primaryAction: primaryAction,
            copyAction: copyAction,
            pasteAction: pasteAction,
            externalAction: itemActions.primaryExternalAction(for: record),
            performExternalAction: {
              itemActions.perform($0, for: record)
            }
          ) {
            store.toggleFavorite(record.id)
          } togglePinned: {
            store.togglePinned(record.id)
          } deleteAction: {
            store.delete(record.id)
          }
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
            primaryAction: primaryAction,
            copyAction: copyAction,
            pasteAction: pasteAction,
            externalAction: itemActions.primaryExternalAction(for: record),
            performExternalAction: {
              itemActions.perform($0, for: record)
            }
          ) {
            store.toggleFavorite(record.id)
          } togglePinned: {
            store.togglePinned(record.id)
          } deleteAction: {
            store.delete(record.id)
          }
        }
      }
      .padding(.vertical, 4)
    }
  }

  private func primaryAction(_ record: ClipboardRecord) {
    switch settingsStore.settings.autoPasteMode {
    case .copyOnly:
      copyAction(record)
    case .paste:
      pasteAction(record)
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
}

private enum PanelViewMode {
  case card
  case list
}
