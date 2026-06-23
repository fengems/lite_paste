import Foundation
import LitePasteCore

@MainActor
func checkHistoryStore() {
  let store = HistoryStore(records: [], repository: InMemoryClipboardHistoryRepository())
  let hello = ClipboardPayload(
    kind: .text,
    title: "hello",
    searchText: "hello",
    plainText: "hello",
    pasteboardTypes: ["public.utf8-plain-text"]
  )
  let world = ClipboardPayload(
    kind: .text,
    title: "world",
    searchText: "world",
    plainText: "world",
    pasteboardTypes: ["public.utf8-plain-text"]
  )

  let first = store.ingest(hello, sourceAppBundleId: nil, sourceAppName: nil)
  let second = store.ingest(world, sourceAppBundleId: nil, sourceAppName: nil)
  let duplicate = store.ingest(hello, sourceAppBundleId: nil, sourceAppName: nil)

  expect(store.records.count == 2, "HistoryStore should deduplicate records")
  expect(duplicate.id == first.id, "Duplicate content should keep the same record id")
  expect(store.records.first?.id == first.id, "Duplicate content should move to top")
  expect(store.records.first?.copyCount == 2, "Duplicate content should increment copy count")

  store.togglePinned(second.id)
  expect(store.records.first?.id == second.id, "Pinning a record should move it to the front")
  store.togglePinned(second.id)
  expect(
    store.records.first(where: { $0.id == second.id })?.isPinned == false,
    "Unpinning a record should clear its pinned state"
  )

  store.toggleFavorite(first.id)
  store.updateNote(first.id, note: "  saved memo  ")
  expect(
    store.filteredRecords(query: "hello", filter: .favorites).count == 1,
    "Favorite filter should include favorited matching records"
  )
  expect(
    store.filteredRecords(query: "saved memo", filter: .all).count == 1,
    "Notes should be searchable after update"
  )
  store.appendSearchText(first.id, text: "  识别\n文字  recognized text  ")
  expect(
    store.filteredRecords(query: "recognized", filter: .all).count == 1,
    "Appended search text should be searchable"
  )
  expect(
    store.filteredRecords(query: "hello", filter: .all).count == 1,
    "Appending search text should preserve existing search keywords"
  )
  store.updateOCRText(first.id, text: "  cached\nimage text  ")
  expect(
    store.records.first(where: { $0.id == first.id })?.ocrText == "cached image text",
    "HistoryStore should cache normalized OCR text"
  )
  expect(
    store.filteredRecords(query: "cached", filter: .all).count == 1,
    "OCR text should be searchable after update"
  )

  store.togglePinned(first.id)
  expect(
    store.records.first?.isPinned == true,
    "Pinning a record should keep it before regular history"
  )

  store.markUsed(first.id, now: Date(timeIntervalSince1970: 42))
  let usedFirst = store.records.first { $0.id == first.id }
  expect(usedFirst?.lastUsedAt == Date(timeIntervalSince1970: 42), "Marking a record used should update last used time")
  expect(usedFirst?.lastCopiedAt == Date(timeIntervalSince1970: 42), "Marking a record used should refresh copied time")
  expect(usedFirst?.copyCount == 3, "Marking a record used should increment copy count for most-used sorting")

  store.markUsed(second.id, now: Date(timeIntervalSince1970: 43))
  expect(store.records.first?.id == first.id, "Pinned records should stay before recently used regular records")
  expect(
    store.filteredRecords(ClipboardHistoryQuery(sort: .recent)).first?.id == second.id,
    "Recently used records should sort first in recent queries"
  )

  store.togglePinned(first.id)
  expect(
    store.records.first(where: { $0.id == first.id })?.isPinned == false,
    "Unpinning records should clear their pinned state"
  )

  store.updateMaxHistoryCount(1)
  expect(store.records.count == 1, "HistoryStore should trim when max history count changes")

  let stableStore = HistoryStore(
    records: [],
    repository: InMemoryClipboardHistoryRepository(),
    moveDuplicatesToTop: false
  )
  let stableFirst = stableStore.ingest(hello, sourceAppBundleId: nil, sourceAppName: nil)
  _ = stableStore.ingest(world, sourceAppBundleId: nil, sourceAppName: nil)
  let stableDuplicate = stableStore.ingest(hello, sourceAppBundleId: nil, sourceAppName: nil)

  expect(stableDuplicate.id == stableFirst.id, "Duplicate content should still deduplicate when stable ordering is enabled")
  expect(stableStore.records.first?.title == "world", "Stable duplicate ordering should not move duplicate content to top")
  expect(stableStore.records.last?.copyCount == 2, "Stable duplicate ordering should still increment copy count")

  stableStore.updateMoveDuplicatesToTop(true)
  _ = stableStore.ingest(hello, sourceAppBundleId: nil, sourceAppName: nil)
  expect(stableStore.records.first?.id == stableFirst.id, "Duplicate ordering update should move duplicates to top")

  let normalizedStore = HistoryStore(
    records: [],
    repository: InMemoryClipboardHistoryRepository(),
    maxHistoryCount: 0,
    retentionDays: -10
  )
  _ = normalizedStore.ingest(hello, sourceAppBundleId: nil, sourceAppName: nil)
  _ = normalizedStore.ingest(world, sourceAppBundleId: nil, sourceAppName: nil)
  expect(normalizedStore.records.count == 1, "HistoryStore init should normalize max history count")

  let retentionStore = HistoryStore(
    records: [],
    repository: InMemoryClipboardHistoryRepository(),
    retentionDays: -10
  )
  let old = ClipboardPayload(
    kind: .text,
    title: "very old",
    searchText: "very old",
    plainText: "very old",
    pasteboardTypes: ["public.utf8-plain-text"]
  )
  let oldRecord = retentionStore.ingest(
    old,
    sourceAppBundleId: nil,
    sourceAppName: nil,
    now: Date(timeIntervalSince1970: 1)
  )
  retentionStore.updateRetentionDays(-1, now: Date(timeIntervalSince1970: 100 * 86_400))
  expect(
    retentionStore.records.contains(where: { $0.id == oldRecord.id }),
    "HistoryStore update should normalize negative retention days to forever"
  )
}
