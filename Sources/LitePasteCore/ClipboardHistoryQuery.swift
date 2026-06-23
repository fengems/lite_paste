import Foundation

public struct ClipboardHistoryQueryEngine: Sendable {
  public init() {}

  public func execute(_ query: ClipboardHistoryQuery, records: [ClipboardRecord]) -> [ClipboardRecord] {
    let searchTerms = query.text
      .split(whereSeparator: \.isWhitespace)
      .map(String.init)

    let filteredRecords = records
      .filter { record in
        query.filter.matches(record) && matchesText(record, searchTerms: searchTerms)
      }

    guard query.sort != .pinnedThenRecent else {
      return pinnedFirstPreservingOrder(filteredRecords)
    }

    return filteredRecords
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
        || contains(term, in: record.ocrText)
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

  private func pinnedFirstPreservingOrder(_ records: [ClipboardRecord]) -> [ClipboardRecord] {
    records.filter(\.isPinned) + records.filter { !$0.isPinned }
  }

  private func compare(_ lhs: ClipboardRecord, _ rhs: ClipboardRecord, sort: ClipboardHistorySort) -> Bool {
    switch sort {
    case .pinnedThenRecent:
      return false

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
