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
