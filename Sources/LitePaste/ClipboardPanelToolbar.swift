import LitePasteCore
import SwiftUI

struct ClipboardPanelToolbar: View {
  @Binding var query: String
  @Binding var filter: ClipboardFilter
  @Binding var viewMode: ClipboardPanelViewMode

  let searchFieldFocused: FocusState<Bool>.Binding
  let topObstruction: PanelTopObstruction?
  let actionMessage: String?
  let openSettingsAction: () -> Void
  let clearUnpinnedAction: () -> Void
  let clearAllAction: () -> Void
  let closeAction: () -> Void
  let viewModeDidChange: () -> Void

  var body: some View {
    if let topObstruction {
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

      if let actionMessage {
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

        if let actionMessage {
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

      if let actionMessage {
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
    ClipboardPanelViewModePicker(viewMode: $viewMode, viewModeDidChange: viewModeDidChange)
  }

  private var headerActions: some View {
    ClipboardPanelHeaderActions(
      openSettingsAction: openSettingsAction,
      clearUnpinnedAction: clearUnpinnedAction,
      clearAllAction: clearAllAction,
      closeAction: closeAction
    )
  }

  private var searchBox: some View {
    ClipboardPanelSearchBox(query: $query, searchFieldFocused: searchFieldFocused)
  }

  private var toolbarDivider: some View {
    Rectangle()
      .fill(Color.white.opacity(0.10))
      .frame(width: 1, height: 24)
      .padding(.horizontal, 8)
  }
}
