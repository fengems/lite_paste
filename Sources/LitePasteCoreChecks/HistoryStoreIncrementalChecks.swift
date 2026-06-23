import Foundation
import LitePasteCore

final class IncrementalTrackingRepository: ClipboardHistoryIncrementalRepository, ClipboardHistoryLookupRepository, @unchecked Sendable {
  var records: [ClipboardRecord] = []
  private(set) var saveCount = 0
  private(set) var upsertCount = 0
  private(set) var deleteCount = 0
  private(set) var deleteAllCount = 0

  func load() throws -> [ClipboardRecord] {
    records
  }

  func save(_ records: [ClipboardRecord]) throws {
    saveCount += 1
    self.records = records
  }

  func record(id: ClipboardRecord.ID) throws -> ClipboardRecord? {
    records.first { $0.id == id }
  }

  func record(contentHash: String) throws -> ClipboardRecord? {
    records.first { $0.contentHash == contentHash }
  }

  func upsert(_ record: ClipboardRecord, position: Int?) throws {
    upsertCount += 1
    if let index = records.firstIndex(where: { $0.id == record.id }) {
      records[index] = record
    } else if let position {
      records.insert(record, at: min(max(position, 0), records.count))
    } else {
      records.append(record)
    }
  }

  func delete(id: ClipboardRecord.ID) throws {
    deleteCount += 1
    records.removeAll { $0.id == id }
  }

  func deleteAll() throws {
    deleteAllCount += 1
    records.removeAll()
  }
}

@MainActor
func checkHistoryStoreIncrementalPersistence() {
  let repository = IncrementalTrackingRepository()
  let store = HistoryStore(records: [], repository: repository)
  let payload = ClipboardPayload(
    kind: .text,
    title: "incremental",
    searchText: "incremental",
    plainText: "incremental",
    pasteboardTypes: ["public.utf8-plain-text"]
  )

  let record = store.ingest(payload, sourceAppBundleId: nil, sourceAppName: nil, now: Date(timeIntervalSince1970: 1))
  expect(repository.upsertCount == 1, "HistoryStore should upsert newly ingested records incrementally")
  expect(repository.saveCount == 0, "HistoryStore should not full-save newly ingested records with incremental repositories")

  store.toggleFavorite(record.id)
  store.updateNote(record.id, note: "note")
  store.markUsed(record.id, now: Date(timeIntervalSince1970: 2))
  expect(repository.upsertCount == 4, "HistoryStore should upsert record updates incrementally")
  expect(repository.saveCount == 0, "HistoryStore should not full-save record updates with incremental repositories")

  store.delete(record.id)
  expect(repository.deleteCount == 1, "HistoryStore should delete records incrementally")
  expect(repository.saveCount == 0, "HistoryStore should not full-save single deletes with incremental repositories")

  _ = store.ingest(payload, sourceAppBundleId: nil, sourceAppName: nil, now: Date(timeIntervalSince1970: 3))
  store.clearAll()
  expect(repository.deleteAllCount == 1, "HistoryStore should clear records incrementally")

  let existing = ClipboardRecord(
    kind: .text,
    title: "stored",
    searchText: "stored",
    createdAt: Date(timeIntervalSince1970: 4),
    lastCopiedAt: Date(timeIntervalSince1970: 4),
    contentHash: ContentHasher.hash(kind: .text, text: "stored"),
    plainText: "stored"
  )
  repository.records = [existing]
  let partialStore = HistoryStore(records: [], repository: repository)
  let duplicatePayload = ClipboardPayload(
    kind: .text,
    title: "stored",
    searchText: "stored",
    plainText: "stored",
    pasteboardTypes: ["public.utf8-plain-text"]
  )
  let duplicate = partialStore.ingest(
    duplicatePayload,
    sourceAppBundleId: nil,
    sourceAppName: nil,
    now: Date(timeIntervalSince1970: 5)
  )

  expect(duplicate.id == existing.id, "HistoryStore should find duplicate records from the repository")
  expect(partialStore.records.first?.id == existing.id, "HistoryStore should surface repository duplicates in memory")

  let hidden = ClipboardRecord(
    kind: .text,
    title: "hidden",
    searchText: "hidden",
    createdAt: Date(timeIntervalSince1970: 6),
    lastCopiedAt: Date(timeIntervalSince1970: 6),
    contentHash: ContentHasher.hash(kind: .text, text: "hidden"),
    plainText: "hidden"
  )
  repository.records.append(hidden)
  partialStore.markUsed(hidden.id, now: Date(timeIntervalSince1970: 7))
  let hiddenRecord = repository.records.first { $0.id == hidden.id }
  expect(hiddenRecord?.lastUsedAt == Date(timeIntervalSince1970: 7), "HistoryStore should update repository records that are not loaded in memory")
  expect(hiddenRecord?.lastCopiedAt == Date(timeIntervalSince1970: 7), "HistoryStore should refresh hidden repository record copied time when marked used")
  expect(hiddenRecord?.copyCount == 2, "HistoryStore should increment hidden repository record copy count when marked used")
}
