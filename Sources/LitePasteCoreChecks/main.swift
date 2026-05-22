import Foundation
import LitePasteCore

@MainActor
func runChecks() {
  checkContentHasher()
  checkAppSettingsBackwardCompatibility()
  checkPrivacyFilter()
  checkClipboardTextPayloadBuilder()
  checkHistoryStore()
  checkHistoryRetention()
  checkHistoryQueryEngine()
  checkHistoryQueryPerformance()
  checkClipboardWriteTracker()
  checkPasteboardRestorePlanner()
  checkJSONHistoryRepository()
  checkRuntimeReload()
  checkImportExportValidation()
  checkImportExportRoundTrip()
  checkLocalBlobStorage()
  print("LitePasteCoreChecks passed")
}

func checkAppSettingsBackwardCompatibility() {
  let data = Data(#"{"hotkey":"command+shift+v","viewMode":"list"}"#.utf8)

  do {
    let settings = try JSONDecoder.litePaste.decode(AppSettings.self, from: data)
    expect(settings.viewMode == ClipboardPanelViewMode.list, "Settings should decode existing view mode string")
    expect(settings.panelPosition == .statusItem, "Settings should default panelPosition for old files")
    expect(PanelHotkeyCatalog.displayName(for: settings.hotkey) == "⌘⇧V", "Panel hotkey should have display name")
    expect(settings.clearSearchOnOpen, "Settings should default clearSearchOnOpen for old files")
    expect(settings.maxHistoryCount == 1_000, "Settings should default maxHistoryCount for old files")
    expect(!settings.restoreClipboardAfterPaste, "Settings should default restoreClipboardAfterPaste for old files")
    expect(settings.moveDuplicatesToTop, "Settings should default moveDuplicatesToTop for old files")
    expect(settings.focusSearchOnOpen, "Settings should default focusSearchOnOpen for old files")
    expect(
      settings.ignoredApps.contains("com.1password.1password"),
      "Settings should default ignoredApps for old files"
    )

    let custom = AppSettings(
      panelPosition: .mouseScreenCenter,
      ignoredPasteboardTypes: ["org.example.SecretType"],
      ignoredApps: ["com.example.SecretApp"],
      restoreClipboardAfterPaste: true,
      moveDuplicatesToTop: false,
      focusSearchOnOpen: false
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
      decoded.panelPosition == PanelPosition.mouseScreenCenter,
      "Settings should preserve panel position"
    )
    expect(
      decoded.restoreClipboardAfterPaste,
      "Settings should preserve clipboard restore behavior"
    )
    expect(
      !decoded.moveDuplicatesToTop,
      "Settings should preserve duplicate ordering behavior"
    )
    expect(
      !decoded.focusSearchOnOpen,
      "Settings should preserve search focus behavior"
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

  let defaultIgnoredAppFilter = PrivacyFilter()
  expect(
    !defaultIgnoredAppFilter.shouldRecord(
      sourceAppBundleId: "com.1password.1password",
      pasteboardTypes: ["public.utf8-plain-text"]
    ),
    "Default ignored password managers should stop recording"
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

func checkClipboardTextPayloadBuilder() {
  let builder = ClipboardTextPayloadBuilder()

  expect(
    builder.payload(from: " \n\t ", pasteboardTypes: ["public.utf8-plain-text"]) == nil,
    "Text payload builder should ignore blank text"
  )
  expect(builder.classify("https://example.com/docs") == .url, "Text payload builder should classify HTTPS URLs")
  expect(builder.classify("file:///tmp/report.pdf") == .url, "Text payload builder should classify file URLs")
  expect(builder.classify("raycast://extensions") == .url, "Text payload builder should classify custom URL schemes")
  expect(builder.classify("hello@example.com") == .email, "Text payload builder should classify email addresses")
  expect(builder.classify("#FF00AA") == .color, "Text payload builder should classify hex colors")

  let longText = String(repeating: "a", count: ClipboardTextPayloadBuilder.maxTitleLength + 20)
  expect(
    builder.makeTitle(from: "hello\n\tworld") == "hello  world",
    "Text payload builder should compact multiline titles"
  )
  expect(
    builder.makeTitle(from: longText).count == ClipboardTextPayloadBuilder.maxTitleLength,
    "Text payload builder should cap long titles"
  )

  guard let payload = builder.payload(from: " hello@example.com ", pasteboardTypes: ["public.utf8-plain-text"]) else {
    fatalError("Text payload builder should create payload for non-empty text")
  }

  expect(payload.kind == .email, "Text payload should use classified kind")
  expect(payload.title == "hello@example.com", "Text payload should use compact title")
  expect(payload.searchText == " hello@example.com ", "Text payload should preserve original search text")
  expect(payload.plainText == " hello@example.com ", "Text payload should preserve original plain text")
  expect(payload.contentHashBasis == " hello@example.com ", "Text payload should hash from original text")
  expect(payload.contents.count == 1, "Text payload should include one inline snapshot")
  expect(
    payload.contents.first?.pasteboardType == ClipboardTextPayloadBuilder.plainTextPasteboardType,
    "Text payload should use the plain text pasteboard type"
  )
  expect(
    payload.contents.first?.inlineData == Data(" hello@example.com ".utf8),
    "Text payload snapshot should preserve UTF-8 text data"
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

func checkPasteboardRestorePlanner() {
  let externalData = Data("external image".utf8)
  let planner = PasteboardRestorePlanner { path in
    path == "/tmp/image.png" ? externalData : nil
  }

  let textRecord = ClipboardRecord(
    kind: .text,
    title: "hello",
    searchText: "hello",
    contentHash: "text",
    plainText: "hello",
    contents: [
      ClipboardContentSnapshot(
        pasteboardType: PasteboardRestorePlanner.plainTextPasteboardType,
        storageMode: .inline,
        inlineData: Data("hello".utf8),
        byteSize: 5,
        displayOrder: 0
      )
    ]
  )

  expect(
    planner.plan(for: textRecord, asPlainText: true) == .plainText("hello"),
    "Restore planner should force plain text when requested"
  )

  let fileRecord = ClipboardRecord(
    kind: .files,
    title: "files",
    searchText: "/tmp/a.txt\n/tmp/b.txt",
    contentHash: "files",
    plainText: "/tmp/a.txt\n/tmp/b.txt",
    contents: [
      ClipboardContentSnapshot(
        pasteboardType: "public.file-url",
        storageMode: .inline,
        inlineData: Data("/tmp/a.txt".utf8),
        byteSize: 10,
        displayOrder: 1
      ),
      ClipboardContentSnapshot(
        pasteboardType: "public.file-url",
        storageMode: .inline,
        inlineData: Data("/tmp/b.txt".utf8),
        byteSize: 10,
        displayOrder: 0
      )
    ]
  )

  if case let .fileURLs(urls)? = planner.plan(for: fileRecord) {
    expect(urls.map(\.path) == ["/tmp/b.txt", "/tmp/a.txt"], "Restore planner should restore file URLs in display order")
  } else {
    fatalError("Restore planner should create a file URL plan")
  }

  let legacyFileRecord = ClipboardRecord(
    kind: .files,
    title: "legacy files",
    searchText: "/tmp/legacy.txt",
    contentHash: "legacy-files",
    plainText: "/tmp/legacy.txt"
  )

  if case let .fileURLs(urls)? = planner.plan(for: legacyFileRecord) {
    expect(urls.map(\.path) == ["/tmp/legacy.txt"], "Restore planner should restore legacy file records from plain text")
  } else {
    fatalError("Restore planner should create a file URL plan for legacy file records")
  }

  let imageRecord = ClipboardRecord(
    kind: .image,
    title: "image",
    searchText: "image",
    contentHash: "image",
    contents: [
      ClipboardContentSnapshot(
        pasteboardType: "public.png",
        storageMode: .external,
        externalFilePath: "/tmp/image.png",
        byteSize: externalData.count,
        displayOrder: 0
      )
    ]
  )

  if case let .items(items)? = planner.plan(for: imageRecord) {
    expect(items == [PasteboardRestoreItem(pasteboardType: "public.png", data: externalData)], "Restore planner should read external blob data")
  } else {
    fatalError("Restore planner should create an item plan for external data")
  }

  let richRecord = ClipboardRecord(
    kind: .html,
    title: "HTML",
    searchText: "Hello",
    contentHash: "html",
    plainText: "Hello",
    contents: [
      ClipboardContentSnapshot(
        pasteboardType: "public.html",
        storageMode: .inline,
        inlineData: Data("<b>Hello</b>".utf8),
        byteSize: 12,
        displayOrder: 0
      )
    ]
  )

  if case let .items(items)? = planner.plan(for: richRecord) {
    expect(items.map(\.pasteboardType) == ["public.html", PasteboardRestorePlanner.plainTextPasteboardType], "Restore planner should append plain text fallback for rich content")
  } else {
    fatalError("Restore planner should create an item plan for rich content")
  }

  let missingRecord = ClipboardRecord(
    kind: .image,
    title: "missing",
    searchText: "missing",
    contentHash: "missing",
    contents: [
      ClipboardContentSnapshot(
        pasteboardType: "public.png",
        storageMode: .external,
        externalFilePath: "/tmp/missing.png",
        byteSize: 0,
        displayOrder: 0
      )
    ]
  )

  expect(planner.plan(for: missingRecord) == nil, "Restore planner should fail when no restorable content exists")
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

  let multiTermResults = engine.execute(ClipboardHistoryQuery(text: "memo OldApp"), records: records)
  expect(multiTermResults.count == 1 && multiTermResults.first?.id == old.id, "Query should match multiple terms across fields")

  let fileResults = engine.execute(ClipboardHistoryQuery(filter: .files), records: records)
  expect(fileResults.count == 1 && fileResults.first?.id == popular.id, "Filter should match files")

  let popularResults = engine.execute(
    ClipboardHistoryQuery(sort: .mostUsed),
    records: records
  )
  expect(popularResults.first?.id == popular.id, "Most-used sort should sort by copy count")
}

func checkHistoryQueryPerformance() {
  let engine = ClipboardHistoryQueryEngine()
  let records = (0..<5_000).map { index in
    ClipboardRecord(
      kind: index.isMultiple(of: 7) ? .files : .text,
      title: index.isMultiple(of: 250) ? "needle document \(index)" : "document \(index)",
      searchText: "body \(index) project-\(index % 40)",
      note: index.isMultiple(of: 333) ? "important needle" : "",
      sourceAppBundleId: "com.example.App\(index % 12)",
      sourceAppName: "Source \(index % 12)",
      lastCopiedAt: Date(timeIntervalSince1970: TimeInterval(index)),
      copyCount: index % 20,
      isFavorite: index.isMultiple(of: 20),
      isPinned: index.isMultiple(of: 400),
      contentHash: "hash-\(index)"
    )
  }

  let start = DispatchTime.now().uptimeNanoseconds
  let searchResults = engine.execute(
    ClipboardHistoryQuery(text: "needle source", filter: .all, sort: .pinnedThenRecent),
    records: records
  )
  let favoriteResults = engine.execute(
    ClipboardHistoryQuery(text: "project-2", filter: .favorites, sort: .mostUsed),
    records: records
  )
  let elapsedMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000

  expect(!searchResults.isEmpty, "Large history search should find matching records")
  expect(
    favoriteResults.allSatisfy(\.isFavorite),
    "Large history filtered search should preserve favorite filter"
  )
  expect(
    elapsedMilliseconds < 1_500,
    "Large history query should stay responsive for 5,000 records"
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

@MainActor
func checkRuntimeReload() {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "LitePasteReloadChecks-\(UUID().uuidString)", directoryHint: .isDirectory)
  let historyURL = directory.appending(path: "history.json")
  let settingsURL = directory.appending(path: "settings.json")

  do {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    let repository = JSONClipboardHistoryRepository(url: historyURL)
    let initial = ClipboardRecord(kind: .text, title: "initial", searchText: "initial", contentHash: "initial")
    let imported = ClipboardRecord(kind: .text, title: "imported", searchText: "imported", contentHash: "imported")
    try repository.save([initial])

    let historyStore = HistoryStore(repository: repository)
    expect(historyStore.records.first?.title == "initial", "HistoryStore should load initial history")

    try repository.save([imported])
    try historyStore.reload()
    expect(historyStore.records.count == 1, "HistoryStore reload should replace in-memory history")
    expect(historyStore.records.first?.title == "imported", "HistoryStore reload should read imported history")

    let settingsStore = AppSettingsStore(url: settingsURL)
    settingsStore.update { settings in
      settings.viewMode = .card
      settings.hotkey = "command+shift+v"
    }

    let importedSettings = AppSettings(hotkey: "control+space", viewMode: .list)
    try JSONEncoder.litePaste.encode(importedSettings).write(to: settingsURL, options: .atomic)

    settingsStore.reload()
    expect(settingsStore.settings.viewMode == .list, "AppSettingsStore reload should read imported view mode")
    expect(settingsStore.settings.hotkey == "control+space", "AppSettingsStore reload should read imported hotkey")
  } catch {
    fatalError("Runtime reload check failed: \(error)")
  }
}

func checkImportExportValidation() {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "LitePasteBackupValidation-\(UUID().uuidString)", directoryHint: .isDirectory)
  let service = ImportExportService()

  do {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    let validBackup = directory.appending(path: "Valid.litepastebackup", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: validBackup, withIntermediateDirectories: true)
    try Data(#"{"createdAt":"2026-01-01T00:00:00Z","formatVersion":1}"#.utf8)
      .write(to: validBackup.appending(path: "manifest.json"))
    try JSONEncoder.litePaste.encode([ClipboardRecord(kind: .text, title: "backup", searchText: "backup", contentHash: "backup")])
      .write(to: validBackup.appending(path: "history.json"))
    try JSONEncoder.litePaste.encode(AppSettings())
      .write(to: validBackup.appending(path: "settings.json"))
    try FileManager.default.createDirectory(at: validBackup.appending(path: "Blobs", directoryHint: .isDirectory), withIntermediateDirectories: true)
    try service.validateBackup(at: validBackup)

    let brokenManifest = directory.appending(path: "Broken.litepastebackup", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: brokenManifest, withIntermediateDirectories: true)
    try Data("not json".utf8).write(to: brokenManifest.appending(path: "manifest.json"))

    do {
      try service.validateBackup(at: brokenManifest)
      fatalError("Broken backup manifest should be rejected")
    } catch BackupError.invalidBackup {
      // Expected.
    }

    let futureBackup = directory.appending(path: "Future.litepastebackup", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: futureBackup, withIntermediateDirectories: true)
    try Data(#"{"createdAt":"2026-01-01T00:00:00Z","formatVersion":999}"#.utf8)
      .write(to: futureBackup.appending(path: "manifest.json"))

    do {
      try service.validateBackup(at: futureBackup)
      fatalError("Unsupported backup format should be rejected")
    } catch BackupError.unsupportedFormatVersion(999) {
      // Expected.
    }
  } catch {
    fatalError("Import/export validation check failed: \(error)")
  }
}

func checkImportExportRoundTrip() {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "LitePasteBackupRoundTrip-\(UUID().uuidString)", directoryHint: .isDirectory)
  let appDirectory = directory.appending(path: "AppData", directoryHint: .isDirectory)
  let backupParent = directory.appending(path: "Backups", directoryHint: .isDirectory)
  let paths = AppStoragePaths(applicationSupportDirectory: appDirectory)
  let service = ImportExportService(paths: paths)
  let repository = JSONClipboardHistoryRepository(url: paths.historyURL)

  do {
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    try paths.ensureBlobsDirectoryExists()
    try FileManager.default.createDirectory(at: backupParent, withIntermediateDirectories: true)

    let sourceBlob = paths.blobsDirectory.appending(path: "image.bin")
    try Data("blob-a".utf8).write(to: sourceBlob, options: .atomic)
    let sourceRecord = ClipboardRecord(
      kind: .image,
      title: "image",
      searchText: "image",
      lastCopiedAt: Date(timeIntervalSince1970: 30),
      contentHash: "hash-a",
      contents: [
        ClipboardContentSnapshot(
          pasteboardType: "public.data",
          storageMode: .external,
          externalFilePath: sourceBlob.path,
          byteSize: 6,
          displayOrder: 0
        )
      ],
      previewFilePath: sourceBlob.path
    )
    try repository.save([sourceRecord])
    try JSONEncoder.litePaste.encode(AppSettings(hotkey: "control+space", viewMode: .list))
      .write(to: paths.settingsURL, options: .atomic)

    let backupURL = try service.exportBackup(to: backupParent, now: Date(timeIntervalSince1970: 100))
    let exportedHistory = try JSONClipboardHistoryRepository(url: backupURL.appending(path: "history.json")).load()
    let exportedBlob = backupURL.appending(path: "Blobs/image.bin")

    expect(FileManager.default.fileExists(atPath: exportedBlob.path), "Export should copy external blobs")
    expect(
      exportedHistory.first?.previewFilePath == exportedBlob.path,
      "Export should rewrite preview blob paths into backup directory"
    )

    try FileManager.default.removeItem(at: appDirectory)
    try service.importBackup(from: backupURL, mode: .replace)

    let restoredHistory = try repository.load()
    let restoredBlob = paths.blobsDirectory.appending(path: "image.bin")
    let restoredSettings = try JSONDecoder.litePaste.decode(
      AppSettings.self,
      from: Data(contentsOf: paths.settingsURL)
    )

    expect(restoredHistory.count == 1, "Replace import should restore exported history")
    expect(restoredHistory.first?.previewFilePath == restoredBlob.path, "Replace import should rewrite preview path")
    expect(FileManager.default.fileExists(atPath: restoredBlob.path), "Replace import should restore blob files")
    expect(restoredSettings.hotkey == "control+space", "Replace import should restore settings")

    let localRecord = ClipboardRecord(
      kind: .text,
      title: "local",
      searchText: "local",
      lastCopiedAt: Date(timeIntervalSince1970: 50),
      contentHash: "hash-local"
    )
    try repository.save([localRecord, sourceRecord])

    let mergeBackup = directory.appending(path: "Merge.litepastebackup", directoryHint: .isDirectory)
    let mergeBlobs = mergeBackup.appending(path: "Blobs", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: mergeBlobs, withIntermediateDirectories: true)
    try Data(#"{"createdAt":"2026-01-01T00:00:00Z","formatVersion":1}"#.utf8)
      .write(to: mergeBackup.appending(path: "manifest.json"))
    try JSONEncoder.litePaste.encode(AppSettings(hotkey: "command+option+v", viewMode: .card))
      .write(to: mergeBackup.appending(path: "settings.json"))

    let incomingBlob = mergeBlobs.appending(path: "incoming.bin")
    try Data("incoming".utf8).write(to: incomingBlob, options: .atomic)
    let duplicateRecord = ClipboardRecord(
      kind: .text,
      title: "duplicate",
      searchText: "duplicate",
      lastCopiedAt: Date(timeIntervalSince1970: 40),
      contentHash: "hash-a"
    )
    let incomingRecord = ClipboardRecord(
      kind: .image,
      title: "incoming",
      searchText: "incoming",
      lastCopiedAt: Date(timeIntervalSince1970: 60),
      contentHash: "hash-incoming",
      contents: [
        ClipboardContentSnapshot(
          pasteboardType: "public.data",
          storageMode: .external,
          externalFilePath: incomingBlob.path,
          byteSize: 8,
          displayOrder: 0
        )
      ],
      previewFilePath: incomingBlob.path
    )
    try JSONEncoder.litePaste.encode([duplicateRecord, incomingRecord])
      .write(to: mergeBackup.appending(path: "history.json"), options: .atomic)

    try service.importBackup(from: mergeBackup, mode: .merge)

    let mergedHistory = try repository.load()
    let hashCounts = Dictionary(grouping: mergedHistory, by: \.contentHash).mapValues(\.count)
    let mergedSettings = try JSONDecoder.litePaste.decode(
      AppSettings.self,
      from: Data(contentsOf: paths.settingsURL)
    )
    let importedBlob = paths.blobsDirectory.appending(path: "incoming.bin")

    expect(mergedHistory.count == 3, "Merge import should keep existing and add unique incoming records")
    expect(hashCounts["hash-a"] == 1, "Merge import should deduplicate by content hash")
    expect(
      mergedHistory.first(where: { $0.contentHash == "hash-incoming" })?.previewFilePath == importedBlob.path,
      "Merge import should rewrite incoming preview blob path"
    )
    expect(FileManager.default.fileExists(atPath: importedBlob.path), "Merge import should copy incoming blobs")
    expect(mergedSettings.hotkey == "control+space", "Merge import should not overwrite existing settings")
  } catch {
    fatalError("Import/export round-trip check failed: \(error)")
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
