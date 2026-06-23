import Foundation
import LitePasteCore

@MainActor
func checkHistoryStorePagedQueries() {
  do {
    try withTemporaryDirectory(prefix: "LitePasteHistoryStorePageChecks") { directory in
      let url = directory.appending(path: "history.sqlite3")

      var records: [ClipboardRecord] = []
      for index in 0..<5 {
        let id = UUID(uuidString: "00000000-0000-0000-0000-00000000020\(index)")!
        let timestamp = Date(timeIntervalSince1970: TimeInterval(index))
        records.append(
          ClipboardRecord(
            id: id,
            kind: index == 4 ? .image : .text,
            title: "record \(index)",
            searchText: "page \(index)",
            createdAt: timestamp,
            lastCopiedAt: timestamp,
            copyCount: index + 1,
            contentHash: "page-\(index)"
          )
        )
      }
      let repository = SQLiteClipboardHistoryRepository(url: url)
      try repository.save(records)
      let store = HistoryStore(repository: repository)
      let query = ClipboardHistoryQuery(sort: .recent)

      let firstPage = store.filteredPage(query, limit: 2)
      expect(
        firstPage.records.map(\.id) == [records[4].id, records[3].id],
        "HistoryStore page should load first SQLite page")
      expect(firstPage.totalCount == 5, "HistoryStore page should expose total SQLite count")
      expect(firstPage.hasMore, "HistoryStore page should expose hasMore for partial pages")

      let hiddenRecordID = records[2].id
      let queryBackedStore = HistoryStore(records: [], repository: repository)
      expect(
        queryBackedStore.record(id: hiddenRecordID)?.id == hiddenRecordID,
        "HistoryStore should look up records from the repository when they are not in memory"
      )

      let secondPage = store.filteredPage(query, limit: 2, offset: 2)
      expect(
        secondPage.records.map(\.id) == [records[2].id, records[1].id],
        "HistoryStore page should apply SQLite offsets")

      let fallbackStore = HistoryStore(
        records: records, repository: InMemoryClipboardHistoryRepository())
      let fallbackPage = fallbackStore.filteredPage(query, limit: 2, offset: 3)
      let fallbackPageIDs = fallbackPage.records.map { $0.id }
      expect(
        fallbackPageIDs == [records[1].id, records[0].id],
        "HistoryStore page should fall back to in-memory paging")
      expect(fallbackPage.totalCount == 5, "HistoryStore fallback page should expose total count")
    }
  } catch {
    fatalError("HistoryStore paged query check failed: \(error)")
  }
}

@MainActor
func checkHistoryStorePartialInitialLoad() {
  do {
    try withTemporaryDirectory(prefix: "LitePasteHistoryStorePartialLoadChecks") { directory in
      let url = directory.appending(path: "history.sqlite3")

      let records = (0..<5).map { index in
        ClipboardRecord(
          id: UUID(uuidString: "00000000-0000-0000-0000-00000000030\(index)")!,
          kind: .text,
          title: "partial \(index)",
          searchText: "partial \(index)",
          createdAt: Date(timeIntervalSince1970: TimeInterval(index)),
          lastCopiedAt: Date(timeIntervalSince1970: TimeInterval(index)),
          contentHash: "partial-\(index)",
          plainText: "partial \(index)"
        )
      }
      let repository = SQLiteClipboardHistoryRepository(url: url)
      try repository.save(records)

      let store = HistoryStore(repository: repository, initialLoadLimit: 2)
      expect(
        store.records.map(\.id) == [records[0].id, records[1].id],
        "HistoryStore should initially load only the first page")
      expect(
        store.filteredRecordCount(ClipboardHistoryQuery()) == 5,
        "HistoryStore partial initial load should keep repository-backed total counts"
      )
      expect(
        store.allRecordCount() == 5,
        "HistoryStore should expose full record count beyond the partial initial page"
      )

      let maxRepository = SQLiteClipboardHistoryRepository(
        url: directory.appending(path: "max-history.sqlite3")
      )
      try maxRepository.save(records)
      let maxStore = HistoryStore(
        repository: maxRepository, maxHistoryCount: 2, initialLoadLimit: 2)
      let initiallyTrimmedRecords = try maxRepository.load()
      expect(
        maxStore.records.map(\.id) == [records[4].id, records[3].id],
        "HistoryStore should keep the first page after initial max-count trimming"
      )
      expect(
        initiallyTrimmedRecords.map(\.id) == [records[4].id, records[3].id],
        "HistoryStore should enforce max history count during partial initial load"
      )

      let hidden = records[4]
      store.markUsed(hidden.id, now: Date(timeIntervalSince1970: 10))
      let hiddenRecord = try repository.record(id: hidden.id)
      expect(
        hiddenRecord?.lastUsedAt == Date(timeIntervalSince1970: 10),
        "HistoryStore partial initial load should update hidden repository records"
      )
      expect(
        hiddenRecord?.lastCopiedAt == Date(timeIntervalSince1970: 10),
        "HistoryStore partial initial load should refresh hidden repository copied time"
      )

      store.updateMaxHistoryCount(2)
      let trimmed = try repository.load()
      expect(
        trimmed.map(\.id) == [hidden.id, records[3].id],
        "HistoryStore should keep recently used records when trimming")

      let clearRepository = SQLiteClipboardHistoryRepository(
        url: directory.appending(path: "clear-history.sqlite3")
      )
      try clearRepository.save(records)
      let clearStore = HistoryStore(repository: clearRepository, initialLoadLimit: 2)
      clearStore.clearAll()
      let clearedRecords = try clearRepository.load()
      expect(
        clearedRecords.isEmpty,
        "HistoryStore should clear full repository after partial initial load")

      var countRecords = records
      countRecords[0].isPinned = true
      let countRepository = SQLiteClipboardHistoryRepository(
        url: directory.appending(path: "unpinned-count-history.sqlite3")
      )
      try countRepository.save(countRecords)
      let countStore = HistoryStore(repository: countRepository, initialLoadLimit: 2)
      expect(
        countStore.unpinnedRecordCount() == 4,
        "HistoryStore should count unpinned records beyond the partial initial page"
      )
    }
  } catch {
    fatalError("HistoryStore partial initial load check failed: \(error)")
  }
}
