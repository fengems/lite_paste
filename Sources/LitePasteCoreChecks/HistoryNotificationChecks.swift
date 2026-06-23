import Foundation
import LitePasteCore

@MainActor
func checkHistoryChangeNotifications() {
  let store = HistoryStore(records: [], repository: InMemoryClipboardHistoryRepository())
  let counter = NotificationCounter()
  let observer = NotificationCenter.default.addObserver(
    forName: .litePasteHistoryChanged,
    object: nil,
    queue: nil
  ) { _ in
    counter.count += 1
  }
  defer {
    NotificationCenter.default.removeObserver(observer)
  }

  let payload = ClipboardPayload(
    kind: .text,
    title: "notify",
    searchText: "notify",
    plainText: "notify",
    pasteboardTypes: ["public.utf8-plain-text"]
  )
  let record = store.ingest(payload, sourceAppBundleId: nil, sourceAppName: nil)
  store.markUsed(record.id)
  store.delete(record.id)

  expect(counter.count >= 3, "HistoryStore should post change notifications for status refreshes")
}

@MainActor
func checkHistoryPersistenceFailureNotifications() {
  let sink = NotificationMessageSink()
  let observer = NotificationCenter.default.addObserver(
    forName: .litePasteHistoryPersistenceFailed,
    object: nil,
    queue: nil
  ) { notification in
    if let message = notification.userInfo?[HistoryNotificationUserInfoKey.errorMessage] as? String {
      sink.messages.append(message)
    }
  }
  defer {
    NotificationCenter.default.removeObserver(observer)
  }

  let store = HistoryStore(records: [], repository: FailingClipboardHistoryRepository())
  let payload = ClipboardPayload(
    kind: .text,
    title: "fail",
    searchText: "fail",
    plainText: "fail",
    pasteboardTypes: ["public.utf8-plain-text"]
  )

  store.ingest(payload, sourceAppBundleId: nil, sourceAppName: nil)
  expect(
    sink.messages.contains("history write failed"),
    "HistoryStore should notify when history persistence fails"
  )
}

@MainActor
func checkHistoryFullLoadFailureNotifications() {
  let sink = NotificationMessageSink()
  let observer = NotificationCenter.default.addObserver(
    forName: .litePasteHistoryPersistenceFailed,
    object: nil,
    queue: nil
  ) { notification in
    if let message = notification.userInfo?[HistoryNotificationUserInfoKey.errorMessage] as? String {
      sink.messages.append(message)
    }
  }
  defer {
    NotificationCenter.default.removeObserver(observer)
  }

  let records = (0..<3).map { index in
    ClipboardRecord(
      kind: .text,
      title: "full load \(index)",
      searchText: "full load \(index)",
      createdAt: Date(timeIntervalSince1970: TimeInterval(index)),
      lastCopiedAt: Date(timeIntervalSince1970: TimeInterval(index)),
      contentHash: "full-load-\(index)",
      plainText: "full load \(index)"
    )
  }
  let store = HistoryStore(
    repository: FailingFullLoadQueryRepository(records: records),
    initialLoadLimit: 1
  )

  store.clearAll()

  expect(
    sink.messages.contains("full history load failed"),
    "HistoryStore should notify when full history loading fails"
  )
  expect(
    !store.records.isEmpty,
    "HistoryStore should not mutate partial history when full load fails"
  )
}

struct FailingClipboardHistoryRepository: ClipboardHistoryRepository {
  func load() throws -> [ClipboardRecord] {
    []
  }

  func save(_ records: [ClipboardRecord]) throws {
    throw NSError(
      domain: "LitePasteChecks",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: "history write failed"]
    )
  }
}

struct FailingFullLoadQueryRepository: ClipboardHistoryQueryingRepository {
  var records: [ClipboardRecord]

  func load() throws -> [ClipboardRecord] {
    throw NSError(
      domain: "LitePasteChecks",
      code: 2,
      userInfo: [NSLocalizedDescriptionKey: "full history load failed"]
    )
  }

  func save(_ records: [ClipboardRecord]) throws {}

  func execute(_ query: ClipboardHistoryQuery, limit: Int?, offset: Int) throws -> [ClipboardRecord] {
    let sorted = ClipboardHistoryQueryEngine().execute(query, records: records)
    let offset = max(offset, 0)
    guard offset < sorted.count else {
      return []
    }

    let sliced = Array(sorted.dropFirst(offset))
    if let limit {
      return Array(sliced.prefix(max(limit, 0)))
    }

    return sliced
  }

  func count(_ query: ClipboardHistoryQuery) throws -> Int {
    ClipboardHistoryQueryEngine().execute(query, records: records).count
  }
}
