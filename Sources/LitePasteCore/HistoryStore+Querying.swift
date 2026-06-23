import Foundation

extension HistoryStore {
  public func filteredRecords(query: String, filter: ClipboardFilter) -> [ClipboardRecord] {
    filteredRecords(ClipboardHistoryQuery(text: query, filter: filter))
  }

  public func filteredRecords(_ query: ClipboardHistoryQuery) -> [ClipboardRecord] {
    filteredRecords(query, limit: nil)
  }

  public func filteredRecords(
    _ query: ClipboardHistoryQuery,
    limit: Int?,
    offset: Int = 0
  ) -> [ClipboardRecord] {
    if let queryRepository = repository as? any ClipboardHistoryQueryingRepository,
       let records = try? queryRepository.execute(query, limit: limit, offset: offset) {
      return records
    }

    return ClipboardHistoryPagination.slice(
      queryEngine.execute(query, records: records),
      limit: limit,
      offset: offset
    )
  }

  public func filteredRecordCount(_ query: ClipboardHistoryQuery) -> Int {
    if let queryRepository = repository as? any ClipboardHistoryQueryingRepository,
       let count = try? queryRepository.count(query) {
      return count
    }

    return queryEngine.execute(query, records: records).count
  }

  public func allRecordCount() -> Int {
    filteredRecordCount(ClipboardHistoryQuery(filter: .all))
  }

  public func unpinnedRecordCount() -> Int {
    max(
      allRecordCount() - filteredRecordCount(ClipboardHistoryQuery(filter: .pinned)),
      0
    )
  }

  public func filteredPage(
    _ query: ClipboardHistoryQuery,
    limit: Int,
    offset: Int = 0
  ) -> ClipboardHistoryPage {
    let pageRequest = ClipboardHistoryPageRequest(limit: limit, offset: offset)
    return ClipboardHistoryPage(
      records: filteredRecords(query, limit: pageRequest.limit, offset: pageRequest.offset),
      totalCount: filteredRecordCount(query),
      limit: pageRequest.limit,
      offset: pageRequest.offset
    )
  }

  public func filteredPageAsync(
    _ query: ClipboardHistoryQuery,
    limit: Int,
    offset: Int = 0
  ) async -> ClipboardHistoryPage {
    let pageRequest = ClipboardHistoryPageRequest(limit: limit, offset: offset)

    if let queryRepository = repository as? any ClipboardHistoryQueryingRepository {
      do {
        return try await Task.detached(priority: .userInitiated) {
          let records = try queryRepository.execute(
            query,
            limit: pageRequest.limit,
            offset: pageRequest.offset
          )
          let totalCount = try queryRepository.count(query)
          return ClipboardHistoryPage(
            records: records,
            totalCount: totalCount,
            limit: pageRequest.limit,
            offset: pageRequest.offset
          )
        }.value
      } catch {
        notifyHistoryPersistenceFailed(operation: "查询历史", error: error)
      }
    }

    return filteredPage(query, limit: pageRequest.limit, offset: pageRequest.offset)
  }

  public func record(id: ClipboardRecord.ID) -> ClipboardRecord? {
    if let record = records.first(where: { $0.id == id }) {
      return record
    }

    if let lookupRepository = repository as? any ClipboardHistoryLookupRepository,
       let record = try? lookupRepository.record(id: id) {
      return record
    }

    return nil
  }

}

private struct ClipboardHistoryPageRequest: Sendable {
  let limit: Int
  let offset: Int

  init(limit: Int, offset: Int) {
    self.limit = max(limit, 0)
    self.offset = max(offset, 0)
  }
}
