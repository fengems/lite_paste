import Foundation

public struct ClipboardHistoryQuery: Equatable, Sendable {
  public var text: String
  public var filter: ClipboardFilter
  public var sort: ClipboardHistorySort

  public init(
    text: String = "",
    filter: ClipboardFilter = .all,
    sort: ClipboardHistorySort = .pinnedThenRecent
  ) {
    self.text = text
    self.filter = filter
    self.sort = sort
  }
}

public enum ClipboardHistorySort: Equatable, Sendable {
  case pinnedThenRecent
  case recent
  case mostUsed
}

public struct ClipboardHistoryQueryEngine: Sendable {
  public init() {}

  public func execute(_ query: ClipboardHistoryQuery, records: [ClipboardRecord]) -> [ClipboardRecord] {
    let normalizedQuery = query.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    return records
      .filter { record in
        query.filter.matches(record) && matchesText(record, normalizedQuery: normalizedQuery)
      }
      .sorted { lhs, rhs in
        compare(lhs, rhs, sort: query.sort)
      }
  }

  private func matchesText(_ record: ClipboardRecord, normalizedQuery: String) -> Bool {
    guard !normalizedQuery.isEmpty else {
      return true
    }

    return searchableText(for: record).contains(normalizedQuery)
  }

  private func searchableText(for record: ClipboardRecord) -> String {
    [
      record.title,
      record.searchText,
      record.note,
      record.sourceAppName ?? "",
      record.sourceAppBundleId ?? "",
      record.kind.displayName
    ]
      .joined(separator: "\n")
      .lowercased()
  }

  private func compare(_ lhs: ClipboardRecord, _ rhs: ClipboardRecord, sort: ClipboardHistorySort) -> Bool {
    switch sort {
    case .pinnedThenRecent:
      if lhs.isPinned != rhs.isPinned {
        return lhs.isPinned && !rhs.isPinned
      }

      return lhs.lastCopiedAt > rhs.lastCopiedAt

    case .recent:
      return lhs.lastCopiedAt > rhs.lastCopiedAt

    case .mostUsed:
      if lhs.copyCount != rhs.copyCount {
        return lhs.copyCount > rhs.copyCount
      }

      return lhs.lastCopiedAt > rhs.lastCopiedAt
    }
  }
}

