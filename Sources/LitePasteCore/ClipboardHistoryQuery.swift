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

public struct ClipboardHistoryPage: Equatable, Sendable {
  public var records: [ClipboardRecord]
  public var totalCount: Int
  public var limit: Int
  public var offset: Int

  public init(records: [ClipboardRecord], totalCount: Int, limit: Int, offset: Int = 0) {
    self.records = records
    self.totalCount = totalCount
    self.limit = max(limit, 0)
    self.offset = max(offset, 0)
  }

  public var hasMore: Bool {
    offset + records.count < totalCount
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
    let searchTerms = query.text
      .split(whereSeparator: \.isWhitespace)
      .map(String.init)

    return records
      .filter { record in
        query.filter.matches(record) && matchesText(record, searchTerms: searchTerms)
      }
      .sorted { lhs, rhs in
        compare(lhs, rhs, sort: query.sort)
      }
  }

  private func matchesText(_ record: ClipboardRecord, searchTerms: [String]) -> Bool {
    guard !searchTerms.isEmpty else {
      return true
    }

    return searchTerms.allSatisfy { term in
      contains(term, in: record.title)
        || contains(term, in: record.searchText)
        || contains(term, in: record.note)
        || contains(term, in: record.sourceAppName)
        || contains(term, in: record.sourceAppBundleId)
        || contains(term, in: record.kind.displayName)
    }
  }

  private func contains(_ term: String, in value: String?) -> Bool {
    guard let value, !value.isEmpty else {
      return false
    }

    return value.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
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
