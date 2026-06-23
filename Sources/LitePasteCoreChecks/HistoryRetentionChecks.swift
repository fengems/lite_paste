import Foundation
import LitePasteCore

@MainActor
func checkHistoryRetention() {
  let now = Date(timeIntervalSince1970: 10 * 86_400)
  let old = ClipboardPayload(
    kind: .text,
    title: "old",
    searchText: "old",
    plainText: "old",
    pasteboardTypes: ["public.utf8-plain-text"]
  )
  let recent = ClipboardPayload(
    kind: .text,
    title: "recent",
    searchText: "recent",
    plainText: "recent",
    pasteboardTypes: ["public.utf8-plain-text"]
  )

  let store = HistoryStore(
    records: [],
    repository: InMemoryClipboardHistoryRepository(),
    retentionDays: 2
  )
  let oldRecord = store.ingest(old, sourceAppBundleId: nil, sourceAppName: nil, now: now.addingTimeInterval(-3 * 86_400))
  _ = store.ingest(recent, sourceAppBundleId: nil, sourceAppName: nil, now: now)
  store.updateRetentionDays(2, now: now)

  expect(!store.records.contains(where: { $0.id == oldRecord.id }), "Retention should remove expired unpinned records")
  expect(store.records.count == 1, "Retention should keep recent records")

  let pinnedStore = HistoryStore(
    records: [],
    repository: InMemoryClipboardHistoryRepository(),
    retentionDays: 2
  )
  let pinnedOld = pinnedStore.ingest(old, sourceAppBundleId: nil, sourceAppName: nil, now: now.addingTimeInterval(-3 * 86_400))
  pinnedStore.togglePinned(pinnedOld.id)
  pinnedStore.updateRetentionDays(2, now: now)

  expect(pinnedStore.records.contains(where: { $0.id == pinnedOld.id }), "Retention should keep pinned records")

  let foreverStore = HistoryStore(
    records: [],
    repository: InMemoryClipboardHistoryRepository(),
    retentionDays: 0
  )
  let foreverOld = foreverStore.ingest(old, sourceAppBundleId: nil, sourceAppName: nil, now: now.addingTimeInterval(-365 * 86_400))
  foreverStore.updateRetentionDays(0, now: now)

  expect(foreverStore.records.contains(where: { $0.id == foreverOld.id }), "Zero retention should keep records forever")
}
