import Foundation
import LitePasteCore

@MainActor
func runChecks() {
  checkContentHasher()
  checkPrivacyFilter()
  checkHistoryStore()
  checkJSONHistoryRepository()
  print("LitePasteCoreChecks passed")
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
  guard condition() else {
    fatalError(message)
  }
}

func checkContentHasher() {
  let first = ContentHasher.hash(kind: .text, text: "hello")
  let second = ContentHasher.hash(kind: .text, text: "  hello\n")
  expect(first == second, "ContentHasher should normalize outer whitespace")
}

func checkPrivacyFilter() {
  let privateFilter = PrivacyFilter(privacyMode: true)
  expect(
    !privateFilter.shouldRecord(
      sourceAppBundleId: "com.apple.TextEdit",
      pasteboardTypes: ["public.utf8-plain-text"]
    ),
    "Privacy mode should stop recording"
  )

  let ignoredAppFilter = PrivacyFilter(ignoredApps: ["com.example.Secret"])
  expect(
    !ignoredAppFilter.shouldRecord(
      sourceAppBundleId: "com.example.Secret",
      pasteboardTypes: ["public.utf8-plain-text"]
    ),
    "Ignored apps should stop recording"
  )

  let normalFilter = PrivacyFilter()
  expect(
    normalFilter.shouldRecord(
      sourceAppBundleId: "com.apple.TextEdit",
      pasteboardTypes: ["public.utf8-plain-text"]
    ),
    "Plain text should be recordable"
  )
}

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
  _ = store.ingest(world, sourceAppBundleId: nil, sourceAppName: nil)
  let duplicate = store.ingest(hello, sourceAppBundleId: nil, sourceAppName: nil)

  expect(store.records.count == 2, "HistoryStore should deduplicate records")
  expect(duplicate.id == first.id, "Duplicate content should keep the same record id")
  expect(store.records.first?.id == first.id, "Duplicate content should move to top")
  expect(store.records.first?.copyCount == 2, "Duplicate content should increment copy count")

  store.toggleFavorite(first.id)
  expect(
    store.filteredRecords(query: "hello", filter: .favorites).count == 1,
    "Favorite filter should include favorited matching records"
  )
}

func checkJSONHistoryRepository() {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "LitePasteCoreChecks-\(UUID().uuidString)", directoryHint: .isDirectory)
  let url = directory.appending(path: "history.json")

  do {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    let repository = JSONClipboardHistoryRepository(url: url)
    let record = ClipboardRecord(
      kind: .text,
      title: "persisted",
      searchText: "persisted",
      contentHash: "hash",
      plainText: "persisted"
    )

    try repository.save([record])
    let loaded = try repository.load()

    expect(loaded.count == 1, "JSON repository should load saved records")
    expect(loaded.first?.title == "persisted", "JSON repository should preserve record fields")
  } catch {
    fatalError("JSON repository check failed: \(error)")
  }
}

Task { @MainActor in
  runChecks()
  exit(EXIT_SUCCESS)
}

RunLoop.main.run()
