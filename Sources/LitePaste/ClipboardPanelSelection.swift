import Foundation
import LitePasteCore

enum ClipboardPanelSelection {
  struct Result {
    let selectedRecordID: ClipboardRecord.ID?
    let shouldLoadMore: Bool
  }

  static func selectedRecord(
    in records: [ClipboardRecord],
    selectedRecordID: ClipboardRecord.ID?
  ) -> ClipboardRecord? {
    records.first { $0.id == selectedRecordID }
  }

  static func normalizedSelectionID(
    in records: [ClipboardRecord],
    selectedRecordID: ClipboardRecord.ID?
  ) -> ClipboardRecord.ID? {
    guard !records.isEmpty else {
      return nil
    }
    if let selectedRecordID, records.contains(where: { $0.id == selectedRecordID }) {
      return selectedRecordID
    }
    return records[0].id
  }

  static func selectRelative(
    offset: Int,
    records: [ClipboardRecord],
    selectedRecordID: ClipboardRecord.ID?,
    hasMore: Bool
  ) -> Result {
    guard !records.isEmpty else {
      return Result(selectedRecordID: nil, shouldLoadMore: false)
    }

    let currentIndex = selectedIndexOrFirst(in: records, selectedRecordID: selectedRecordID) ?? 0
    let shouldLoadMore = offset > 0 && currentIndex == records.count - 1 && hasMore
    let nextIndex = min(max(currentIndex + offset, 0), records.count - 1)
    return Result(selectedRecordID: records[nextIndex].id, shouldLoadMore: shouldLoadMore)
  }

  static func selectHorizontal(
    direction: Int,
    records: [ClipboardRecord],
    selectedRecordID: ClipboardRecord.ID?,
    viewMode: ClipboardPanelViewMode,
    cardGridColumnCount: Int,
    hasMore: Bool
  ) -> Result {
    guard viewMode == .card else {
      return selectRelative(
        offset: direction,
        records: records,
        selectedRecordID: selectedRecordID,
        hasMore: hasMore
      )
    }
    guard let currentIndex = selectedIndexOrFirst(in: records, selectedRecordID: selectedRecordID) else {
      return Result(selectedRecordID: nil, shouldLoadMore: false)
    }

    let row = CardGridRow(
      currentIndex: currentIndex,
      columnCount: cardGridColumnCount,
      recordCount: records.count
    )

    if direction < 0, currentIndex == row.startIndex {
      return Result(selectedRecordID: records[currentIndex].id, shouldLoadMore: false)
    }
    if direction > 0, currentIndex == row.endIndex {
      return Result(selectedRecordID: records[currentIndex].id, shouldLoadMore: false)
    }

    return Result(selectedRecordID: records[currentIndex + direction].id, shouldLoadMore: false)
  }

  static func selectVertical(
    direction: Int,
    records: [ClipboardRecord],
    selectedRecordID: ClipboardRecord.ID?,
    viewMode: ClipboardPanelViewMode,
    cardGridColumnCount: Int,
    hasMore: Bool
  ) -> Result {
    guard viewMode == .card else {
      return selectRelative(
        offset: direction,
        records: records,
        selectedRecordID: selectedRecordID,
        hasMore: hasMore
      )
    }
    guard let currentIndex = selectedIndexOrFirst(in: records, selectedRecordID: selectedRecordID) else {
      return Result(selectedRecordID: nil, shouldLoadMore: false)
    }

    let currentRow = CardGridRow(
      currentIndex: currentIndex,
      columnCount: cardGridColumnCount,
      recordCount: records.count
    )
    let targetRowStart = currentRow.startIndex + direction * cardGridColumnCount
    if targetRowStart < 0 {
      return Result(selectedRecordID: records[currentIndex].id, shouldLoadMore: false)
    }
    if targetRowStart >= records.count {
      return Result(selectedRecordID: records[currentIndex].id, shouldLoadMore: direction > 0 && hasMore)
    }

    let targetRow = CardGridRow(
      startIndex: targetRowStart,
      columnCount: cardGridColumnCount,
      recordCount: records.count
    )
    let targetIndex = min(targetRowStart + currentRow.columnIndex, targetRow.endIndex)
    return Result(selectedRecordID: records[targetIndex].id, shouldLoadMore: false)
  }

  static func selectRowBoundary(
    _ boundary: PanelRowBoundary,
    records: [ClipboardRecord],
    selectedRecordID: ClipboardRecord.ID?,
    viewMode: ClipboardPanelViewMode,
    cardGridColumnCount: Int
  ) -> Result {
    guard !records.isEmpty else {
      return Result(selectedRecordID: nil, shouldLoadMore: false)
    }

    guard viewMode == .card else {
      return Result(
        selectedRecordID: records[boundary == .leading ? 0 : records.count - 1].id,
        shouldLoadMore: false
      )
    }

    let currentIndex = selectedIndexOrFirst(in: records, selectedRecordID: selectedRecordID) ?? 0
    let row = CardGridRow(
      currentIndex: currentIndex,
      columnCount: cardGridColumnCount,
      recordCount: records.count
    )
    return Result(
      selectedRecordID: records[boundary == .leading ? row.startIndex : row.endIndex].id,
      shouldLoadMore: false
    )
  }

  static func recordForCommandNumber(
    _ number: Int,
    records: [ClipboardRecord],
    selectedRecordID: ClipboardRecord.ID?,
    viewMode: ClipboardPanelViewMode,
    cardGridColumnCount: Int
  ) -> ClipboardRecord? {
    guard (1...9).contains(number) else {
      return nil
    }

    switch viewMode {
    case .card:
      return cardRecord(
        numberInCurrentRow: number,
        records: records,
        selectedRecordID: selectedRecordID,
        cardGridColumnCount: cardGridColumnCount
      )
    case .list:
      let targetIndex = number - 1
      return records.indices.contains(targetIndex) ? records[targetIndex] : nil
    }
  }

  private static func cardRecord(
    numberInCurrentRow number: Int,
    records: [ClipboardRecord],
    selectedRecordID: ClipboardRecord.ID?,
    cardGridColumnCount: Int
  ) -> ClipboardRecord? {
    guard let currentIndex = selectedIndexOrFirst(in: records, selectedRecordID: selectedRecordID),
          number <= cardGridColumnCount else {
      return nil
    }

    let row = CardGridRow(
      currentIndex: currentIndex,
      columnCount: cardGridColumnCount,
      recordCount: records.count
    )
    let targetIndex = row.startIndex + number - 1
    guard targetIndex <= row.endIndex else {
      return nil
    }

    return records[targetIndex]
  }

  private static func selectedIndexOrFirst(
    in records: [ClipboardRecord],
    selectedRecordID: ClipboardRecord.ID?
  ) -> Int? {
    guard !records.isEmpty else {
      return nil
    }

    return records.firstIndex { $0.id == selectedRecordID } ?? 0
  }
}

private struct CardGridRow {
  let startIndex: Int
  let endIndex: Int
  let columnIndex: Int

  init(currentIndex: Int, columnCount: Int, recordCount: Int) {
    let startIndex = (currentIndex / columnCount) * columnCount
    self.init(
      startIndex: startIndex,
      columnIndex: currentIndex - startIndex,
      columnCount: columnCount,
      recordCount: recordCount
    )
  }

  init(startIndex: Int, columnCount: Int, recordCount: Int) {
    self.init(
      startIndex: startIndex,
      columnIndex: 0,
      columnCount: columnCount,
      recordCount: recordCount
    )
  }

  private init(startIndex: Int, columnIndex: Int, columnCount: Int, recordCount: Int) {
    precondition(columnCount > 0, "Card grid column count must be positive")
    self.startIndex = startIndex
    self.columnIndex = columnIndex
    self.endIndex = min(startIndex + columnCount, recordCount) - 1
  }
}
