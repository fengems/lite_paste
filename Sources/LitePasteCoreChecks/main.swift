import Foundation
import LitePasteCore

@MainActor
func runChecks() {
  checkContentHasher()
  checkAppSettingsBackwardCompatibility()
  checkPrivacyFilter()
  checkHistoryStore()
  checkHistoryRetention()
  checkHistoryQueryEngine()
  checkClipboardWriteTracker()
  checkJSONHistoryRepository()
  checkLocalBlobStorage()
  print("LitePasteCoreChecks passed")
}

func checkAppSettingsBackwardCompatibility() {
  let data = Data(#"{"hotkey":"command+shift+v","viewMode":"list"}"#.utf8)

  do {
    let settings = try JSONDecoder.litePaste.decode(AppSettings.self, from: data)
    expect(settings.viewMode == ClipboardPanelViewMode.list, "Settings should decode existing view mode string")
    expect(settings.clearSearchOnOpen, "Settings should default clearSearchOnOpen for old files")
    expect(settings.maxHistoryCount == 1_000, "Settings should default maxHistoryCount for old files")
    expect(settings.moveDuplicatesToTop, "Settings should default moveDuplicatesToTop for old files")

    let custom = AppSettings(
      ignoredPasteboardTypes: ["org.example.SecretType"],
      ignoredApps: ["com.example.SecretApp"],
      moveDuplicatesToTop: false
    )
    let encoded = try JSONEncoder.litePaste.encode(custom)
    let decoded = try JSONDecoder.litePaste.decode(AppSettings.self, from: encoded)

    expect(
      decoded.ignoredApps.contains("com.example.SecretApp"),
      "Settings should preserve ignored apps"
    )
    expect(
      decoded.ignoredPasteboardTypes.contains("org.example.SecretType"),
      "Settings should preserve ignored pasteboard types"
    )
    expect(
      !decoded.moveDuplicatesToTop,
      "Settings should preserve duplicate ordering behavior"
    )
  } catch {
    fatalError("Settings compatibility check failed: \(error)")
  }
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
func checkClipboardWriteTracker() {
  let tracker = ClipboardWriteTracker()
  tracker.markIgnoredChangeCount(42)

  expect(tracker.shouldIgnore(changeCount: 42), "ClipboardWriteTracker should ignore marked change count")
  expect(!tracker.shouldIgnore(changeCount: 42), "ClipboardWriteTracker should consume ignored change count once")
  expect(!tracker.shouldIgnore(changeCount: 43), "ClipboardWriteTracker should not ignore unmarked change count")
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
  store.updateNote(first.id, note: "  saved memo  ")
  store.updatePinShortcut(first.id, shortcut: "command+option+1")
  expect(
    store.filteredRecords(query: "hello", filter: .favorites).count == 1,
    "Favorite filter should include favorited matching records"
  )
  expect(
    store.filteredRecords(query: "saved memo", filter: .all).count == 1,
    "Notes should be searchable after update"
  )
  expect(
    store.records.first?.isPinned == true && store.records.first?.pinShortcut == "command+option+1",
    "Pin shortcut update should pin record and persist shortcut"
  )

  let secondShortcut = store.ingest(
    ClipboardPayload(
      kind: .text,
      title: "shortcut",
      searchText: "shortcut",
      plainText: "shortcut",
      pasteboardTypes: ["public.utf8-plain-text"]
    ),
    sourceAppBundleId: nil,
    sourceAppName: nil
  )
  store.updatePinShortcut(secondShortcut.id, shortcut: "command+option+1")
  expect(
    store.records.filter { $0.pinShortcut == "command+option+1" }.count == 1,
    "Pin shortcuts should be unique"
  )
  store.updatePinShortcut(UUID(), shortcut: "command+option+2")
  expect(
    store.records.allSatisfy { $0.pinShortcut != "command+option+2" },
    "Pin shortcut update should ignore missing records"
  )
  store.togglePinned(first.id)
  store.togglePinned(secondShortcut.id)
  expect(
    store.records.allSatisfy { !$0.isPinned && $0.pinShortcut == nil },
    "Unpinning records should clear pin shortcuts"
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
}

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

func checkHistoryQueryEngine() {
  let engine = ClipboardHistoryQueryEngine()
  let old = ClipboardRecord(
    kind: .text,
    title: "old",
    searchText: "alpha",
    note: "memo",
    sourceAppBundleId: "com.example.Old",
    sourceAppName: "OldApp",
    lastCopiedAt: Date(timeIntervalSince1970: 10),
    copyCount: 1,
    contentHash: "old"
  )
  let pinned = ClipboardRecord(
    kind: .image,
    title: "image",
    searchText: "screenshot",
    note: "",
    sourceAppBundleId: "com.example.Image",
    sourceAppName: "ImageApp",
    lastCopiedAt: Date(timeIntervalSince1970: 1),
    copyCount: 2,
    isPinned: true,
    contentHash: "image"
  )
  let popular = ClipboardRecord(
    kind: .files,
    title: "files",
    searchText: "report.pdf",
    note: "",
    sourceAppBundleId: "com.example.Files",
    sourceAppName: "Finder",
    lastCopiedAt: Date(timeIntervalSince1970: 20),
    copyCount: 9,
    contentHash: "files"
  )
  let records = [old, pinned, popular]

  let defaultResults = engine.execute(ClipboardHistoryQuery(), records: records)
  expect(defaultResults.first?.id == pinned.id, "Pinned records should sort before recent records")

  let noteResults = engine.execute(ClipboardHistoryQuery(text: "memo"), records: records)
  expect(noteResults.count == 1 && noteResults.first?.id == old.id, "Query should match notes")

  let fileResults = engine.execute(ClipboardHistoryQuery(filter: .files), records: records)
  expect(fileResults.count == 1 && fileResults.first?.id == popular.id, "Filter should match files")

  let popularResults = engine.execute(
    ClipboardHistoryQuery(sort: .mostUsed),
    records: records
  )
  expect(popularResults.first?.id == popular.id, "Most-used sort should sort by copy count")
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

func checkLocalBlobStorage() {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "LitePasteBlobChecks-\(UUID().uuidString)", directoryHint: .isDirectory)

  do {
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    let storage = LocalBlobStorage(directory: directory)
    let snapshot = try storage.snapshot(
      data: Data("blob".utf8),
      pasteboardType: "public.data",
      preferredExtension: "bin",
      displayOrder: 0
    )

    guard let path = snapshot.externalFilePath else {
      fatalError("Blob snapshot should include external file path")
    }

    expect(FileManager.default.fileExists(atPath: path), "Blob storage should write external file")
    storage.removeExternalFiles(in: [snapshot])
    expect(!FileManager.default.fileExists(atPath: path), "Blob storage should remove external file")
  } catch {
    fatalError("Local blob storage check failed: \(error)")
  }
}

Task { @MainActor in
  runChecks()
  exit(EXIT_SUCCESS)
}

RunLoop.main.run()
