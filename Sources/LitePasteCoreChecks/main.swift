import Foundation
import LitePasteCore

struct CheckCase {
  let group: String
  let name: String
  let run: @MainActor () -> Void

  var identifier: String {
    "\(group)/\(name)"
  }
}

@MainActor
func allChecks() -> [CheckCase] {
  [
    CheckCase(group: "core", name: "content-hasher", run: checkContentHasher),
    CheckCase(group: "settings", name: "paths-environment-override", run: checkAppPathsEnvironmentOverride),
    CheckCase(group: "settings", name: "backward-compatibility", run: checkAppSettingsBackwardCompatibility),
    CheckCase(group: "settings", name: "normalization", run: checkAppSettingsStoreNormalization),
    CheckCase(group: "settings", name: "save-failure-notification", run: checkAppSettingsStoreSaveFailureNotification),
    CheckCase(group: "permissions", name: "guide-state", run: checkPermissionGuideState),
    CheckCase(group: "privacy", name: "filter", run: checkPrivacyFilter),
    CheckCase(group: "capture", name: "text-payload-builder", run: checkClipboardTextPayloadBuilder),
    CheckCase(group: "capture", name: "file-payload-builder", run: checkClipboardFilePayloadBuilder),
    CheckCase(group: "capture", name: "media-payload-builder", run: checkClipboardMediaPayloadBuilder),
    CheckCase(group: "capture", name: "payload-resolver", run: checkClipboardPayloadResolver),
    CheckCase(group: "capture", name: "capture-gate", run: checkClipboardCaptureGate),
    CheckCase(group: "history", name: "store", run: checkHistoryStore),
    CheckCase(group: "history", name: "change-notifications", run: checkHistoryChangeNotifications),
    CheckCase(group: "history", name: "persistence-failure-notifications", run: checkHistoryPersistenceFailureNotifications),
    CheckCase(group: "history", name: "full-load-failure-notifications", run: checkHistoryFullLoadFailureNotifications),
    CheckCase(group: "history", name: "incremental-persistence", run: checkHistoryStoreIncrementalPersistence),
    CheckCase(group: "history", name: "paged-queries", run: checkHistoryStorePagedQueries),
    CheckCase(group: "history", name: "partial-initial-load", run: checkHistoryStorePartialInitialLoad),
    CheckCase(group: "history", name: "retention", run: checkHistoryRetention),
    CheckCase(group: "history", name: "blob-cleanup", run: checkHistoryBlobCleanup),
    CheckCase(group: "history", name: "query-engine", run: checkHistoryQueryEngine),
    CheckCase(group: "history", name: "query-performance", run: checkHistoryQueryPerformance),
    CheckCase(group: "pasteboard", name: "write-tracker", run: checkClipboardWriteTracker),
    CheckCase(group: "pasteboard", name: "restore-planner", run: checkPasteboardRestorePlanner),
    CheckCase(group: "repository", name: "json-history", run: checkJSONHistoryRepository),
    CheckCase(group: "repository", name: "sqlite-history", run: checkSQLiteHistoryRepository),
    CheckCase(group: "repository", name: "sqlite-query-and-maintenance", run: checkSQLiteHistoryQueryAndMaintenance),
    CheckCase(group: "repository", name: "migrating-history", run: checkMigratingHistoryRepository),
    CheckCase(group: "repository", name: "history-persistence-cleanup", run: checkHistoryPersistenceCleanup),
    CheckCase(group: "runtime", name: "reload", run: checkRuntimeReload),
    CheckCase(group: "backup", name: "validation", run: checkImportExportValidation),
    CheckCase(group: "backup", name: "round-trip", run: checkImportExportRoundTrip),
    CheckCase(group: "backup", name: "local-blob-storage", run: checkLocalBlobStorage)
  ]
}

@MainActor
func runChecks(arguments: [String] = Array(CommandLine.arguments.dropFirst())) -> Int32 {
  let checks = allChecks()

  switch parseCheckArguments(arguments) {
  case .help:
    printUsage(checks: checks)
    return EXIT_SUCCESS
  case .list:
    printCheckList(checks: checks)
    return EXIT_SUCCESS
  case let .run(filter):
    let selectedChecks = checksMatching(filter, in: checks)
    guard !selectedChecks.isEmpty else {
      fputs("No LitePasteCoreChecks matched '\(filter ?? "")'.\n", stderr)
      printUsage(checks: checks)
      return EX_USAGE
    }

    for check in selectedChecks {
      print("• \(check.identifier)")
      check.run()
    }

    print("LitePasteCoreChecks passed (\(selectedChecks.count)/\(checks.count) checks)")
    return EXIT_SUCCESS
  case let .invalid(message):
    fputs("\(message)\n", stderr)
    printUsage(checks: checks)
    return EX_USAGE
  }
}

enum CheckCommand {
  case help
  case list
  case run(filter: String?)
  case invalid(String)
}

func parseCheckArguments(_ arguments: [String]) -> CheckCommand {
  guard !arguments.isEmpty else {
    return .run(filter: nil)
  }

  switch arguments.first {
  case "--help", "-h":
    return arguments.count == 1 ? .help : .invalid("--help does not accept extra arguments.")
  case "--list":
    return arguments.count == 1 ? .list : .invalid("--list does not accept extra arguments.")
  case "--only":
    guard arguments.count == 2 else {
      return .invalid("Usage error: --only requires one group or check identifier.")
    }
    return .run(filter: arguments[1])
  default:
    return .invalid("Unknown LitePasteCoreChecks argument: \(arguments[0])")
  }
}

func checksMatching(_ filter: String?, in checks: [CheckCase]) -> [CheckCase] {
  guard let filter, !filter.isEmpty else {
    return checks
  }

  return checks.filter { check in
    check.group == filter || check.name == filter || check.identifier == filter
  }
}

func printCheckList(checks: [CheckCase]) {
  var currentGroup: String?
  for check in checks {
    if check.group != currentGroup {
      currentGroup = check.group
      print("\n[\(check.group)]")
    }
    print("  \(check.identifier)")
  }
}

func printUsage(checks: [CheckCase]) {
  let groups = Array(Set(checks.map(\.group))).sorted().joined(separator: ", ")
  print(
    """
    Usage:
      swift run LitePasteCoreChecks
      swift run LitePasteCoreChecks --list
      swift run LitePasteCoreChecks --only <group|name|group/name>

    Groups:
      \(groups)
    """
  )
}

func checkAppPathsEnvironmentOverride() {
  let override = "/tmp/LitePaste Isolated Data"
  let overriddenURL = AppPaths.applicationSupportDirectory(
    environment: [AppPaths.applicationSupportDirectoryOverrideEnvironmentKey: override]
  )
  expect(
    overriddenURL.path == override,
    "AppPaths should honor isolated application support directory overrides"
  )

  let defaultURL = AppPaths.applicationSupportDirectory(environment: [:])
  expect(
    defaultURL.lastPathComponent == "LitePaste",
    "AppPaths should default to the LitePaste application support directory"
  )
}

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

final class NotificationCounter: @unchecked Sendable {
  var count = 0
}

final class NotificationMessageSink: @unchecked Sendable {
  var messages: [String] = []
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

func checkAppSettingsBackwardCompatibility() {
  let data = Data(#"{"hotkey":"command+shift+v","viewMode":"list"}"#.utf8)

  do {
    let settings = try JSONDecoder.litePaste.decode(AppSettings.self, from: data)
    expect(settings.viewMode == ClipboardPanelViewMode.list, "Settings should decode existing view mode string")
    expect(settings.panelPosition == .edgeBottom, "Settings should default panelPosition to bottom edge for old files")
    expect(PanelHotkeyCatalog.displayName(for: settings.hotkey) == "⌘⇧V", "Panel hotkey should have display name")
    expect(settings.clearSearchOnOpen, "Settings should default clearSearchOnOpen for old files")
    expect(settings.maxHistoryCount == 1_000, "Settings should default maxHistoryCount for old files")
    expect(!settings.restoreClipboardAfterPaste, "Settings should default restoreClipboardAfterPaste for old files")
    expect(settings.moveDuplicatesToTop, "Settings should default moveDuplicatesToTop for old files")
    expect(settings.focusSearchOnOpen, "Settings should default focusSearchOnOpen for old files")
    expect(settings.coverMenuBarWhenEdgeAttached, "Settings should default menu bar coverage to on for old files")
    expect(
      settings.ignoredApps.contains("com.1password.1password"),
      "Settings should default ignoredApps for old files"
    )

    let custom = AppSettings(
      panelPosition: .cursor,
      ignoredPasteboardTypes: ["org.example.SecretType"],
      ignoredApps: ["com.example.SecretApp"],
      restoreClipboardAfterPaste: true,
      moveDuplicatesToTop: false,
      focusSearchOnOpen: false,
      coverMenuBarWhenEdgeAttached: true
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
    let legacyIgnoredPasteboardTypes = PrivacyFilter.defaultIgnoredPasteboardTypes.union([
      "com.apple.finder.node",
      "com.apple.pasteboard.promised-file-url",
      "com.apple.webarchive",
      "com.apple.flat-rtfd",
      "org.example.SecretType"
    ])
    let migratedSettings = AppSettings(ignoredPasteboardTypes: legacyIgnoredPasteboardTypes)
    expect(
      !migratedSettings.ignoredPasteboardTypes.contains("com.apple.finder.node"),
      "Settings should migrate legacy ignored types that block file capture"
    )
    expect(
      !migratedSettings.ignoredPasteboardTypes.contains("com.apple.webarchive"),
      "Settings should migrate legacy ignored types that block HTML capture"
    )
    expect(
      migratedSettings.ignoredPasteboardTypes.contains("org.example.SecretType"),
      "Settings should preserve custom ignored types during ignored type migration"
    )
    expect(
      migratedSettings.ignoredPasteboardTypes.contains("org.nspasteboard.ConcealedType"),
      "Settings should preserve privacy ignored types during ignored type migration"
    )
    expect(
      decoded.panelPosition == PanelPosition.cursor,
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
    expect(
      decoded.coverMenuBarWhenEdgeAttached,
      "Settings should preserve menu bar coverage behavior"
    )

    let invalidData = Data(#"{"hotkey":"command+shift+x","maxHistoryCount":0,"retentionDays":-12}"#.utf8)
    let invalidSettings = try JSONDecoder.litePaste.decode(AppSettings.self, from: invalidData)
    expect(invalidSettings.hotkey == "command+shift+v", "Settings should normalize invalid panel hotkey")
    expect(invalidSettings.maxHistoryCount == 1, "Settings should normalize invalid max history count")
    expect(invalidSettings.retentionDays == 0, "Settings should normalize invalid retention days")

    let invalidInit = AppSettings(hotkey: "invalid", maxHistoryCount: -50, retentionDays: -7)
    expect(invalidInit.hotkey == "command+shift+v", "Settings init should normalize panel hotkey")
    expect(invalidInit.maxHistoryCount == 1, "Settings init should normalize max history count")
    expect(invalidInit.retentionDays == 0, "Settings init should normalize retention days")
    expect(
      AppSettings(panelPosition: .statusItem).panelPosition == .edgeBottom,
      "Settings init should migrate legacy status item position"
    )
    expect(
      AppSettings(panelPosition: .mouseScreenCenter).panelPosition == .cursor,
      "Settings init should migrate legacy mouse center position"
    )

    expect(
      AppSettings(hotkey: " Command + Option + Space ").hotkey == "command+option+space",
      "Settings init should normalize panel hotkey formatting"
    )
    expect(
      PanelHotkeyCatalog.normalized(" Command + Option + Space ") == "command+option+space",
      "Panel hotkey catalog should normalize valid formatting"
    )
    expect(PanelHotkeyCatalog.normalized("control+space") == nil, "Panel hotkey catalog should reject unknown hotkeys")
    expect(
      PinShortcutCatalog.normalized(" Command + Option + 9 ") == "command+option+9",
      "Pin shortcut catalog should normalize valid formatting"
    )
    expect(PinShortcutCatalog.normalized("command+option+0") == nil, "Pin shortcut catalog should reject unknown shortcuts")
  } catch {
    fatalError("Settings compatibility check failed: \(error)")
  }
}

@MainActor
func checkAppSettingsStoreNormalization() {
  let directory = FileManager.default.temporaryDirectory.appending(
    path: "LitePasteSettingsNormalization-\(UUID().uuidString)",
    directoryHint: .isDirectory
  )
  let url = directory.appending(path: "settings.json")

  do {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = AppSettingsStore(url: url)
    store.update {
      $0.hotkey = "bad+hotkey"
      $0.maxHistoryCount = -99
      $0.retentionDays = -3
    }

    expect(store.settings.hotkey == "command+shift+v", "Settings store update should normalize invalid hotkey")
    expect(store.settings.maxHistoryCount == 1, "Settings store update should normalize max history count")
    expect(store.settings.retentionDays == 0, "Settings store update should normalize retention days")

    let reloaded = AppSettingsStore(url: url)
    expect(reloaded.settings.hotkey == "command+shift+v", "Settings store should persist normalized hotkey")
    expect(reloaded.settings.maxHistoryCount == 1, "Settings store should persist normalized max history count")
    expect(reloaded.settings.retentionDays == 0, "Settings store should persist normalized retention days")
  } catch {
    fatalError("Settings store normalization check failed: \(error)")
  }
}

@MainActor
func checkAppSettingsStoreSaveFailureNotification() {
  let directory = FileManager.default.temporaryDirectory.appending(
    path: "LitePasteSettingsSaveFailure-\(UUID().uuidString)",
    directoryHint: .isDirectory
  )
  let parentFile = directory.appending(path: "settings-parent")
  let url = parentFile.appending(path: "settings.json")
  let sink = NotificationMessageSink()

  do {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("not a directory".utf8).write(to: parentFile, options: .atomic)
    defer { try? FileManager.default.removeItem(at: directory) }

    let observer = NotificationCenter.default.addObserver(
      forName: .litePasteSettingsSaveFailed,
      object: nil,
      queue: nil
    ) { notification in
      if let message = notification.userInfo?[SettingsNotificationUserInfoKey.errorMessage] as? String {
        sink.messages.append(message)
      }
    }
    defer {
      NotificationCenter.default.removeObserver(observer)
    }

    let store = AppSettingsStore(url: url)
    store.update { $0.viewMode = .list }

    expect(!sink.messages.isEmpty, "Settings store should notify when settings cannot be saved")
  } catch {
    fatalError("Settings save failure notification check failed: \(error)")
  }
}

func checkPermissionGuideState() {
  var state = PermissionGuideState()

  expect(
    state.missingItems(accessibilityTrusted: true).isEmpty,
    "Permission guide should not report missing items when accessibility is trusted"
  )
  expect(
    state.missingItems(accessibilityTrusted: false) == [.accessibility],
    "Permission guide should report accessibility when it is not trusted"
  )
  expect(
    !state.shouldPresent(accessibilityTrusted: true),
    "Permission guide should not present when all required permissions are trusted"
  )
  expect(
    state.shouldPresent(accessibilityTrusted: false),
    "Permission guide should present when required permissions are missing"
  )

  state.dismissForSession()
  expect(
    !state.shouldPresent(accessibilityTrusted: false),
    "Permission guide should not present again after being dismissed for the current session"
  )

  let freshState = PermissionGuideState()
  expect(
    freshState.shouldPresent(accessibilityTrusted: false),
    "Permission guide dismissal should not persist across fresh sessions"
  )
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
  guard condition() else {
    fatalError(message)
  }
}

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
  expect(
    normalFilter.shouldRecord(
      sourceAppBundleId: "com.apple.finder",
      pasteboardTypes: ["public.file-url", "com.apple.finder.node"]
    ),
    "Finder file marker types should not block recordable file URLs"
  )
  expect(
    normalFilter.shouldRecord(
      sourceAppBundleId: "com.apple.Safari",
      pasteboardTypes: ["public.html", "com.apple.webarchive"]
    ),
    "Web archive marker types should not block recordable HTML"
  )
  expect(
    !normalFilter.shouldRecord(
      sourceAppBundleId: "com.apple.TextEdit",
      pasteboardTypes: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"]
    ),
    "Concealed pasteboard types should stop recording"
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
  expect(builder.classify("example.com/docs") == .url, "Text payload builder should classify bare domains")
  expect(builder.classify("www.example.com?q=1") == .url, "Text payload builder should classify www bare domains")
  expect(builder.classify("hello@example.com") == .email, "Text payload builder should classify email addresses")
  expect(builder.classify("#FF00AA") == .color, "Text payload builder should classify hex colors")
  expect(builder.classify("release notes v1.2") == .text, "Text payload builder should not classify dotted prose as URLs")

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

func checkClipboardFilePayloadBuilder() {
  let builder = ClipboardFilePayloadBuilder()

  expect(
    builder.payload(from: [], pasteboardTypes: ["public.file-url"]) == nil,
    "File payload builder should ignore empty file lists"
  )
  expect(
    builder.payload(from: [URL(string: "https://example.com/file.txt")!], pasteboardTypes: ["public.url"]) == nil,
    "File payload builder should ignore non-file URLs"
  )

  let singleURL = URL(fileURLWithPath: "/Users/example/Desktop/report.pdf")
  guard let singlePayload = builder.payload(from: [singleURL], pasteboardTypes: ["public.file-url"]) else {
    fatalError("File payload builder should create a single-file payload")
  }

  expect(singlePayload.kind == .files, "File payload should use files kind")
  expect(singlePayload.title == "report.pdf", "File payload should use single file name as title")
  expect(singlePayload.searchText == singleURL.path, "File payload should search by full file path")
  expect(singlePayload.plainText == singleURL.path, "File payload should preserve paths as plain text")
  expect(singlePayload.contentHashBasis == singleURL.path, "File payload should hash from ordered paths")
  expect(singlePayload.contents.count == 1, "Single-file payload should include one snapshot")
  expect(
    singlePayload.contents.first?.pasteboardType == ClipboardFilePayloadBuilder.fileURLPasteboardType,
    "File payload should use the file URL pasteboard type"
  )
  expect(
    singlePayload.contents.first?.inlineData == Data(singleURL.path.utf8),
    "File payload snapshot should store the file path"
  )

  let fileURLs = [
    URL(fileURLWithPath: "/tmp/a.txt"),
    URL(fileURLWithPath: "/tmp/b.txt"),
    URL(fileURLWithPath: "/tmp/c.txt"),
    URL(fileURLWithPath: "/tmp/d.txt")
  ]
  guard let multiPayload = builder.payload(from: fileURLs, pasteboardTypes: ["public.file-url"]) else {
    fatalError("File payload builder should create a multi-file payload")
  }

  expect(
    multiPayload.title == "4 个文件: a.txt, b.txt, c.txt",
    "File payload should summarize multi-file titles"
  )
  expect(
    multiPayload.plainText == fileURLs.map(\.path).joined(separator: "\n"),
    "File payload should preserve file URL order in plain text"
  )
  expect(
    multiPayload.contents.map(\.displayOrder) == [0, 1, 2, 3],
    "File payload snapshots should preserve display order"
  )
  expect(
    multiPayload.contents.compactMap { $0.inlineData.flatMap { String(data: $0, encoding: .utf8) } } == fileURLs.map(\.path),
    "File payload snapshots should preserve ordered paths"
  )
}

func checkClipboardMediaPayloadBuilder() {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "LitePasteMediaPayloadChecks-\(UUID().uuidString)", directoryHint: .isDirectory)
  let storage = LocalBlobStorage(directory: directory)
  let builder = ClipboardMediaPayloadBuilder(blobStorage: storage)

  do {
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    let imageData = Data("png-data".utf8)
    let imagePayload = try builder.imagePayload(
      data: imageData,
      pasteboardType: "public.png",
      preferredExtension: "png",
      pasteboardTypes: ["public.png"]
    )

    expect(imagePayload.kind == .image, "Media payload builder should create image payloads")
    expect(imagePayload.title == "图片", "Image payload should use localized image title")
    expect(imagePayload.searchText == "图片 image", "Image payload should include searchable image terms")
    expect(
      imagePayload.contentHashBasis == ContentHasher.hash(kind: .image, data: imageData),
      "Image payload should hash from original image data"
    )
    expect(imagePayload.contents.count == 1, "Image payload should include one blob snapshot")
    expect(imagePayload.contents.first?.pasteboardType == "public.png", "Image payload should preserve pasteboard type")
    expect(imagePayload.previewFilePath == imagePayload.contents.first?.externalFilePath, "Image payload should use blob path for preview")
    if let previewFilePath = imagePayload.previewFilePath {
      expect(FileManager.default.fileExists(atPath: previewFilePath), "Image payload should persist preview blob")
    } else {
      fatalError("Image payload should include preview path")
    }

    let htmlData = Data("<b>Hello</b>".utf8)
    let htmlPayload = try builder.richTextPayload(
      kind: .html,
      data: htmlData,
      pasteboardType: "public.html",
      preferredExtension: "html",
      fallbackTitle: "HTML",
      plainText: "Hello\nWorld",
      pasteboardTypes: ["public.html", "public.utf8-plain-text"]
    )

    expect(htmlPayload.kind == .html, "Media payload builder should create HTML payloads")
    expect(htmlPayload.title == "Hello World", "Rich payload should compact plain-text titles")
    expect(htmlPayload.searchText == "Hello\nWorld", "Rich payload should search by plain text when available")
    expect(htmlPayload.plainText == "Hello\nWorld", "Rich payload should preserve plain text fallback")
    expect(
      htmlPayload.contentHashBasis == ContentHasher.hash(kind: .html, data: htmlData),
      "Rich payload should hash from rich data"
    )
    expect(htmlPayload.contents.first?.pasteboardType == "public.html", "Rich payload should preserve pasteboard type")

    let rtfData = Data("{\\rtf1 text}".utf8)
    let rtfPayload = try builder.richTextPayload(
      kind: .richText,
      data: rtfData,
      pasteboardType: "public.rtf",
      preferredExtension: "rtf",
      fallbackTitle: "富文本",
      plainText: nil,
      pasteboardTypes: ["public.rtf"]
    )

    expect(rtfPayload.kind == .richText, "Media payload builder should create RTF payloads")
    expect(rtfPayload.title == "富文本", "Rich payload should use fallback title without plain text")
    expect(rtfPayload.searchText == "富文本", "Rich payload should use fallback search text without plain text")
    expect(rtfPayload.plainText == nil, "Rich payload should allow missing plain text")
  } catch {
    fatalError("Media payload builder check failed: \(error)")
  }
}

func checkClipboardPayloadResolver() {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "LitePastePayloadResolverChecks-\(UUID().uuidString)", directoryHint: .isDirectory)
  let resolver = ClipboardPayloadResolver(
    mediaPayloadBuilder: ClipboardMediaPayloadBuilder(
      blobStorage: LocalBlobStorage(directory: directory)
    )
  )
  let pasteboardTypes: Set<String> = [
    ClipboardFilePayloadBuilder.fileURLPasteboardType,
    "public.png",
    "public.html",
    ClipboardTextPayloadBuilder.plainTextPasteboardType
  ]

  do {
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    let filePayload = resolver.resolve(
      pasteboardTypes: pasteboardTypes,
      fileURLs: [URL(fileURLWithPath: "/tmp/report.pdf")],
      imageCandidates: [
        ClipboardImageCandidate(data: Data("image".utf8), pasteboardType: "public.png", preferredExtension: "png")
      ],
      richTextCandidates: [
        ClipboardRichTextCandidate(
          kind: .html,
          data: Data("<b>Hello</b>".utf8),
          pasteboardType: "public.html",
          preferredExtension: "html",
          fallbackTitle: "HTML"
        )
      ],
      plainText: "hello"
    )
    expect(filePayload?.kind == .files, "Payload resolver should prefer files over other candidates")

    let imagePayload = resolver.resolve(
      pasteboardTypes: pasteboardTypes,
      fileURLs: [],
      imageCandidates: [
        ClipboardImageCandidate(data: Data("image".utf8), pasteboardType: "public.png", preferredExtension: "png")
      ],
      richTextCandidates: [
        ClipboardRichTextCandidate(
          kind: .html,
          data: Data("<b>Hello</b>".utf8),
          pasteboardType: "public.html",
          preferredExtension: "html",
          fallbackTitle: "HTML"
        )
      ],
      plainText: "hello"
    )
    expect(imagePayload?.kind == .image, "Payload resolver should prefer images over rich text and text")

    let richPayload = resolver.resolve(
      pasteboardTypes: pasteboardTypes,
      fileURLs: [],
      imageCandidates: [],
      richTextCandidates: [
        ClipboardRichTextCandidate(
          kind: .html,
          data: Data("<b>Hello</b>".utf8),
          pasteboardType: "public.html",
          preferredExtension: "html",
          fallbackTitle: "HTML"
        ),
        ClipboardRichTextCandidate(
          kind: .richText,
          data: Data("{\\rtf1 Hello}".utf8),
          pasteboardType: "public.rtf",
          preferredExtension: "rtf",
          fallbackTitle: "富文本"
        )
      ],
      plainText: "hello"
    )
    expect(richPayload?.kind == .html, "Payload resolver should prefer the first rich text candidate")

    let textPayload = resolver.resolve(
      pasteboardTypes: [ClipboardTextPayloadBuilder.plainTextPasteboardType],
      fileURLs: [],
      imageCandidates: [],
      richTextCandidates: [],
      plainText: "hello"
    )
    expect(textPayload?.kind == .text, "Payload resolver should fall back to plain text")

    let emptyPayload = resolver.resolve(
      pasteboardTypes: [],
      fileURLs: [],
      imageCandidates: [],
      richTextCandidates: [],
      plainText: " \n "
    )
    expect(emptyPayload == nil, "Payload resolver should ignore blank fallback text")
  }
}

@MainActor
func checkClipboardCaptureGate() {
  let payload = ClipboardTextPayloadBuilder().payload(
    from: "hello",
    pasteboardTypes: [ClipboardTextPayloadBuilder.plainTextPasteboardType]
  )
  guard let payload else {
    fatalError("Capture gate check requires a text payload")
  }

  let defaultGate = ClipboardCaptureGate()
  expect(
    defaultGate.shouldRecord(payload: payload, sourceAppBundleId: "com.apple.TextEdit"),
    "Capture gate should allow enabled non-private payloads"
  )

  let disabledTextGate = ClipboardCaptureGate(
    enabledTypes: [.image],
    privacyFilter: PrivacyFilter()
  )
  expect(
    !disabledTextGate.shouldRecord(payload: payload, sourceAppBundleId: "com.apple.TextEdit"),
    "Capture gate should reject disabled payload kinds"
  )

  let privacyModeGate = ClipboardCaptureGate(
    enabledTypes: Set(ClipboardKind.allCases),
    privacyFilter: PrivacyFilter(privacyMode: true)
  )
  expect(
    !privacyModeGate.shouldRecord(payload: payload, sourceAppBundleId: "com.apple.TextEdit"),
    "Capture gate should reject payloads while privacy mode is enabled"
  )

  let ignoredAppGate = ClipboardCaptureGate(
    enabledTypes: Set(ClipboardKind.allCases),
    privacyFilter: PrivacyFilter(ignoredApps: ["com.example.Secret"])
  )
  expect(
    !ignoredAppGate.shouldRecord(payload: payload, sourceAppBundleId: "com.example.Secret"),
    "Capture gate should reject ignored source apps"
  )

  let sensitivePayload = ClipboardPayload(
    kind: .text,
    title: "secret",
    searchText: "secret",
    plainText: "secret",
    pasteboardTypes: ["org.nspasteboard.ConcealedType"]
  )
  expect(
    !defaultGate.shouldRecord(payload: sensitivePayload, sourceAppBundleId: "com.apple.TextEdit"),
    "Capture gate should reject ignored pasteboard types"
  )

  let tracker = ClipboardWriteTracker()
  tracker.markIgnoredChangeCount(100)
  let shouldSkipSelfWrite = tracker.shouldIgnore(changeCount: 100)
  let shouldRecordAfterSkip = !shouldSkipSelfWrite && defaultGate.shouldRecord(
    payload: payload,
    sourceAppBundleId: "com.apple.TextEdit"
  )
  expect(shouldSkipSelfWrite, "Capture gate integration should skip Lite Paste self writes before payload checks")
  expect(!shouldRecordAfterSkip, "Self-write changes should not be recorded")
  expect(
    !tracker.shouldIgnore(changeCount: 100) && defaultGate.shouldRecord(payload: payload, sourceAppBundleId: "com.apple.TextEdit"),
    "A consumed self-write marker should not block later captures"
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

  let missingRichRecord = ClipboardRecord(
    kind: .html,
    title: "Missing HTML",
    searchText: "Hello",
    contentHash: "missing-html",
    plainText: "Hello",
    contents: [
      ClipboardContentSnapshot(
        pasteboardType: "public.html",
        storageMode: .external,
        externalFilePath: "/tmp/missing.html",
        byteSize: 12,
        displayOrder: 0
      )
    ]
  )

  expect(
    planner.plan(for: missingRichRecord) == nil,
    "Restore planner should fail default restore when rich external content is missing"
  )
  expect(
    planner.plan(for: missingRichRecord, asPlainText: true) == .plainText("Hello"),
    "Restore planner should still allow explicit plain-text restore for missing rich content"
  )

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
  let second = store.ingest(world, sourceAppBundleId: nil, sourceAppName: nil)
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

  store.markUsed(first.id, now: Date(timeIntervalSince1970: 42))
  let usedFirst = store.records.first { $0.id == first.id }
  expect(usedFirst?.lastUsedAt == Date(timeIntervalSince1970: 42), "Marking a record used should update last used time")
  expect(usedFirst?.lastCopiedAt == Date(timeIntervalSince1970: 42), "Marking a record used should refresh copied time")
  expect(usedFirst?.copyCount == 3, "Marking a record used should increment copy count for most-used sorting")

  store.markUsed(second.id, now: Date(timeIntervalSince1970: 43))
  expect(store.records.first?.id == second.id, "Marking a record used should move it to the top")
  expect(
    store.filteredRecords(ClipboardHistoryQuery(sort: .recent)).first?.id == second.id,
    "Recently used records should sort first in recent queries"
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
  store.updatePinShortcut(secondShortcut.id, shortcut: " Command + Option + 2 ")
  expect(
    store.records.first(where: { $0.id == secondShortcut.id })?.pinShortcut == "command+option+2",
    "Pin shortcut update should normalize valid shortcuts"
  )
  store.updatePinShortcut(secondShortcut.id, shortcut: "command+option+0")
  expect(
    store.records.first(where: { $0.id == secondShortcut.id })?.pinShortcut == nil,
    "Pin shortcut update should clear invalid shortcuts"
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

@MainActor
func checkHistoryStorePagedQueries() {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "LitePasteHistoryStorePageChecks-\(UUID().uuidString)", directoryHint: .isDirectory)
  let url = directory.appending(path: "history.sqlite3")

  do {
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    let records = (0..<5).map { index in
      ClipboardRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000020\(index)")!,
        kind: index == 4 ? .image : .text,
        title: "record \(index)",
        searchText: "page \(index)",
        createdAt: Date(timeIntervalSince1970: TimeInterval(index)),
        lastCopiedAt: Date(timeIntervalSince1970: TimeInterval(index)),
        copyCount: index + 1,
        contentHash: "page-\(index)"
      )
    }
    let repository = SQLiteClipboardHistoryRepository(url: url)
    try repository.save(records)
    let store = HistoryStore(repository: repository)
    let query = ClipboardHistoryQuery(sort: .recent)

    let firstPage = store.filteredPage(query, limit: 2)
    expect(firstPage.records.map(\.id) == [records[4].id, records[3].id], "HistoryStore page should load first SQLite page")
    expect(firstPage.totalCount == 5, "HistoryStore page should expose total SQLite count")
    expect(firstPage.hasMore, "HistoryStore page should expose hasMore for partial pages")

    let pinnedShortcutRecord = records[2].id
    var pinnedRecords = records
    pinnedRecords[2].isPinned = true
    pinnedRecords[2].pinShortcut = "command+option+2"
    try repository.save(pinnedRecords)
    let queryBackedStore = HistoryStore(records: [], repository: repository)
    expect(
      queryBackedStore.record(id: pinnedShortcutRecord)?.id == pinnedShortcutRecord,
      "HistoryStore should look up records from the repository when they are not in memory"
    )
    expect(
      queryBackedStore.pinnedShortcutRecords().map(\.id) == [pinnedShortcutRecord],
      "HistoryStore should query pinned shortcut records from the repository"
    )

    try repository.save(records)

    let secondPage = store.filteredPage(query, limit: 2, offset: 2)
    expect(secondPage.records.map(\.id) == [records[2].id, records[1].id], "HistoryStore page should apply SQLite offsets")

    let fallbackStore = HistoryStore(records: records, repository: InMemoryClipboardHistoryRepository())
    let fallbackPage = fallbackStore.filteredPage(query, limit: 2, offset: 3)
    expect(fallbackPage.records.map(\.id) == [records[1].id, records[0].id], "HistoryStore page should fall back to in-memory paging")
    expect(fallbackPage.totalCount == 5, "HistoryStore fallback page should expose total count")
  } catch {
    fatalError("HistoryStore paged query check failed: \(error)")
  }
}

@MainActor
func checkHistoryStorePartialInitialLoad() {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "LitePasteHistoryStorePartialLoadChecks-\(UUID().uuidString)", directoryHint: .isDirectory)
  let url = directory.appending(path: "history.sqlite3")

  do {
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

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
    expect(store.records.map(\.id) == [records[4].id, records[3].id], "HistoryStore should initially load only the first page")
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
    let maxStore = HistoryStore(repository: maxRepository, maxHistoryCount: 2, initialLoadLimit: 2)
    let initiallyTrimmedRecords = try maxRepository.load()
    expect(
      maxStore.records.map(\.id) == [records[4].id, records[3].id],
      "HistoryStore should keep the first page after initial max-count trimming"
    )
    expect(
      initiallyTrimmedRecords.map(\.id) == [records[4].id, records[3].id],
      "HistoryStore should enforce max history count during partial initial load"
    )

    let hidden = records[1]
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
    expect(trimmed.map(\.id) == [hidden.id, records[4].id], "HistoryStore should keep recently used records when trimming")

    let clearRepository = SQLiteClipboardHistoryRepository(
      url: directory.appending(path: "clear-history.sqlite3")
    )
    try clearRepository.save(records)
    let clearStore = HistoryStore(repository: clearRepository, initialLoadLimit: 2)
    clearStore.clearAll()
    let clearedRecords = try clearRepository.load()
    expect(clearedRecords.isEmpty, "HistoryStore should clear full repository after partial initial load")

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

    var shortcutRecords = records
    shortcutRecords[0].isPinned = true
    shortcutRecords[0].pinShortcut = "command+option+1"
    let shortcutRepository = SQLiteClipboardHistoryRepository(
      url: directory.appending(path: "pin-shortcut-history.sqlite3")
    )
    try shortcutRepository.save(shortcutRecords)
    let shortcutStore = HistoryStore(repository: shortcutRepository, initialLoadLimit: 2)
    shortcutStore.updatePinShortcut(records[4].id, shortcut: "command+option+1")
    let shortcutUpdatedRecords = try shortcutRepository.load()
    expect(
      shortcutUpdatedRecords.first(where: { $0.id == records[4].id })?.pinShortcut == "command+option+1",
      "HistoryStore should update visible pin shortcuts after partial initial load"
    )
    expect(
      shortcutUpdatedRecords.first(where: { $0.id == records[0].id })?.pinShortcut == nil,
      "HistoryStore should clear hidden duplicate pin shortcuts after partial initial load"
    )
  } catch {
    fatalError("HistoryStore partial initial load check failed: \(error)")
  }
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

func externalBlobPayload(
  title: String,
  contentHashBasis: String,
  data: Data,
  storage: LocalBlobStorage
) throws -> ClipboardPayload {
  let snapshot = try storage.snapshot(
    data: data,
    pasteboardType: "public.data",
    preferredExtension: "bin",
    displayOrder: 0
  )

  return ClipboardPayload(
    kind: .image,
    title: title,
    searchText: title,
    contentHashBasis: contentHashBasis,
    pasteboardTypes: ["public.data"],
    contents: [snapshot],
    previewFilePath: snapshot.externalFilePath
  )
}

func record(
  from payload: ClipboardPayload,
  lastCopiedAt: Date,
  isPinned: Bool = false,
  pinShortcut: String? = nil
) -> ClipboardRecord {
  ClipboardRecord(
    kind: payload.kind,
    title: payload.title,
    searchText: payload.searchText,
    createdAt: lastCopiedAt,
    lastCopiedAt: lastCopiedAt,
    isPinned: isPinned,
    pinShortcut: pinShortcut,
    contentHash: ContentHasher.hash(kind: payload.kind, text: payload.contentHashBasis),
    plainText: payload.plainText,
    contents: payload.contents,
    previewFilePath: payload.previewFilePath
  )
}

@MainActor
func checkHistoryBlobCleanup() {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "LitePasteHistoryBlobCleanup-\(UUID().uuidString)", directoryHint: .isDirectory)
  let blobStorage = LocalBlobStorage(directory: directory)

  do {
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    let duplicateStore = HistoryStore(
      records: [],
      repository: InMemoryClipboardHistoryRepository(),
      blobStorage: blobStorage
    )
    let firstDuplicatePayload = try externalBlobPayload(
      title: "same",
      contentHashBasis: "same",
      data: Data("first".utf8),
      storage: blobStorage
    )
    let secondDuplicatePayload = try externalBlobPayload(
      title: "same again",
      contentHashBasis: "same",
      data: Data("second".utf8),
      storage: blobStorage
    )
    let firstPath = firstDuplicatePayload.contents[0].externalFilePath ?? ""
    let secondPath = secondDuplicatePayload.contents[0].externalFilePath ?? ""

    _ = duplicateStore.ingest(firstDuplicatePayload, sourceAppBundleId: nil, sourceAppName: nil)
    _ = duplicateStore.ingest(secondDuplicatePayload, sourceAppBundleId: nil, sourceAppName: nil)

    expect(duplicateStore.records.count == 1, "Duplicate blob payloads should deduplicate history records")
    expect(FileManager.default.fileExists(atPath: firstPath), "Duplicate ingest should keep the original blob")
    expect(!FileManager.default.fileExists(atPath: secondPath), "Duplicate ingest should remove the unused incoming blob")

    let deleteStore = HistoryStore(
      records: [],
      repository: InMemoryClipboardHistoryRepository(),
      blobStorage: blobStorage
    )
    let deletePayload = try externalBlobPayload(
      title: "delete",
      contentHashBasis: "delete",
      data: Data("delete".utf8),
      storage: blobStorage
    )
    let deletePath = deletePayload.contents[0].externalFilePath ?? ""
    let deleteRecord = deleteStore.ingest(deletePayload, sourceAppBundleId: nil, sourceAppName: nil)
    deleteStore.delete(deleteRecord.id)
    expect(!FileManager.default.fileExists(atPath: deletePath), "Deleting a record should remove its blob")

    let previewStore = HistoryStore(
      records: [],
      repository: InMemoryClipboardHistoryRepository(),
      blobStorage: blobStorage
    )
    let previewContent = try blobStorage.snapshot(
      data: Data("preview-content".utf8),
      pasteboardType: "public.data",
      preferredExtension: "bin",
      displayOrder: 0
    )
    let previewPath = try blobStorage.save(data: Data("preview-only".utf8), preferredExtension: "bin")
    let previewRecord = previewStore.ingest(
      ClipboardPayload(
        kind: .image,
        title: "preview",
        searchText: "preview",
        contentHashBasis: "preview",
        pasteboardTypes: ["public.data"],
        contents: [previewContent],
        previewFilePath: previewPath
      ),
      sourceAppBundleId: nil,
      sourceAppName: nil
    )
    previewStore.delete(previewRecord.id)
    expect(!FileManager.default.fileExists(atPath: previewContent.externalFilePath ?? ""), "Deleting a record should remove content blobs")
    expect(!FileManager.default.fileExists(atPath: previewPath), "Deleting a record should remove independent preview blobs")

    let clearStore = HistoryStore(
      records: [],
      repository: InMemoryClipboardHistoryRepository(),
      blobStorage: blobStorage
    )
    let pinnedPayload = try externalBlobPayload(
      title: "pinned",
      contentHashBasis: "pinned",
      data: Data("pinned".utf8),
      storage: blobStorage
    )
    let regularPayload = try externalBlobPayload(
      title: "regular",
      contentHashBasis: "regular",
      data: Data("regular".utf8),
      storage: blobStorage
    )
    let pinnedPath = pinnedPayload.contents[0].externalFilePath ?? ""
    let regularPath = regularPayload.contents[0].externalFilePath ?? ""
    let pinnedRecord = clearStore.ingest(pinnedPayload, sourceAppBundleId: nil, sourceAppName: nil)
    _ = clearStore.ingest(regularPayload, sourceAppBundleId: nil, sourceAppName: nil)
    clearStore.togglePinned(pinnedRecord.id)
    clearStore.clearUnpinned()

    expect(clearStore.records.count == 1 && clearStore.records.first?.id == pinnedRecord.id, "Clearing unpinned records should keep pinned records")
    expect(FileManager.default.fileExists(atPath: pinnedPath), "Clearing unpinned records should keep pinned blobs")
    expect(!FileManager.default.fileExists(atPath: regularPath), "Clearing unpinned records should remove regular blobs")

    clearStore.clearAll()
    expect(clearStore.records.isEmpty, "Clearing all records should empty history")
    expect(!FileManager.default.fileExists(atPath: pinnedPath), "Clearing all records should remove pinned blobs too")

    let overflowStore = HistoryStore(
      records: [],
      repository: InMemoryClipboardHistoryRepository(),
      blobStorage: blobStorage,
      maxHistoryCount: 2
    )
    let oldestPayload = try externalBlobPayload(
      title: "oldest",
      contentHashBasis: "oldest",
      data: Data("oldest".utf8),
      storage: blobStorage
    )
    let middlePayload = try externalBlobPayload(
      title: "middle",
      contentHashBasis: "middle",
      data: Data("middle".utf8),
      storage: blobStorage
    )
    let newestPayload = try externalBlobPayload(
      title: "newest",
      contentHashBasis: "newest",
      data: Data("newest".utf8),
      storage: blobStorage
    )
    let oldestPath = oldestPayload.contents[0].externalFilePath ?? ""
    let middlePath = middlePayload.contents[0].externalFilePath ?? ""
    let newestPath = newestPayload.contents[0].externalFilePath ?? ""
    _ = overflowStore.ingest(oldestPayload, sourceAppBundleId: nil, sourceAppName: nil, now: Date(timeIntervalSince1970: 1))
    _ = overflowStore.ingest(middlePayload, sourceAppBundleId: nil, sourceAppName: nil, now: Date(timeIntervalSince1970: 2))
    _ = overflowStore.ingest(newestPayload, sourceAppBundleId: nil, sourceAppName: nil, now: Date(timeIntervalSince1970: 3))

    expect(overflowStore.records.count == 2, "Overflow trimming should enforce max history count")
    expect(!FileManager.default.fileExists(atPath: oldestPath), "Overflow trimming should remove trimmed blobs")
    expect(FileManager.default.fileExists(atPath: middlePath), "Overflow trimming should keep retained middle blob")
    expect(FileManager.default.fileExists(atPath: newestPath), "Overflow trimming should keep retained newest blob")

    let pinnedOverflowStore = HistoryStore(
      records: [],
      repository: InMemoryClipboardHistoryRepository(),
      blobStorage: blobStorage,
      maxHistoryCount: 1
    )
    let pinnedOverflowPayload = try externalBlobPayload(
      title: "pinned overflow",
      contentHashBasis: "pinned overflow",
      data: Data("pinned overflow".utf8),
      storage: blobStorage
    )
    let trimmedPayload = try externalBlobPayload(
      title: "trimmed",
      contentHashBasis: "trimmed",
      data: Data("trimmed".utf8),
      storage: blobStorage
    )
    let pinnedOverflowPath = pinnedOverflowPayload.contents[0].externalFilePath ?? ""
    let trimmedPath = trimmedPayload.contents[0].externalFilePath ?? ""
    let pinnedOverflowRecord = pinnedOverflowStore.ingest(pinnedOverflowPayload, sourceAppBundleId: nil, sourceAppName: nil)
    pinnedOverflowStore.togglePinned(pinnedOverflowRecord.id)
    _ = pinnedOverflowStore.ingest(trimmedPayload, sourceAppBundleId: nil, sourceAppName: nil)

    expect(pinnedOverflowStore.records.count == 1 && pinnedOverflowStore.records.first?.id == pinnedOverflowRecord.id, "Overflow trimming should preserve pinned records")
    expect(FileManager.default.fileExists(atPath: pinnedOverflowPath), "Overflow trimming should preserve pinned blobs")
    expect(!FileManager.default.fileExists(atPath: trimmedPath), "Overflow trimming should remove non-pinned overflow blobs")
  } catch {
    fatalError("History blob cleanup check failed: \(error)")
  }
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
  let link = ClipboardRecord(
    kind: .url,
    title: "link",
    searchText: "https://example.com",
    lastCopiedAt: Date(timeIntervalSince1970: 3),
    contentHash: "link"
  )
  let color = ClipboardRecord(
    kind: .color,
    title: "#22C55E",
    searchText: "#22C55E",
    lastCopiedAt: Date(timeIntervalSince1970: 4),
    contentHash: "color"
  )
  let records = [old, pinned, popular, link, color]

  let defaultResults = engine.execute(ClipboardHistoryQuery(), records: records)
  expect(defaultResults.first?.id == pinned.id, "Pinned records should sort before recent records")

  let noteResults = engine.execute(ClipboardHistoryQuery(text: "memo"), records: records)
  expect(noteResults.count == 1 && noteResults.first?.id == old.id, "Query should match notes")

  let multiTermResults = engine.execute(ClipboardHistoryQuery(text: "memo OldApp"), records: records)
  expect(multiTermResults.count == 1 && multiTermResults.first?.id == old.id, "Query should match multiple terms across fields")

  let fileResults = engine.execute(ClipboardHistoryQuery(filter: .files), records: records)
  expect(fileResults.count == 1 && fileResults.first?.id == popular.id, "Filter should match files")

  let linkResults = engine.execute(ClipboardHistoryQuery(filter: .links), records: records)
  expect(linkResults.count == 1 && linkResults.first?.id == link.id, "Filter should match links")

  let colorResults = engine.execute(ClipboardHistoryQuery(filter: .colors), records: records)
  expect(colorResults.count == 1 && colorResults.first?.id == color.id, "Filter should match colors")

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

    let legacyData = Data(
      """
      [
        {
          "id": "00000000-0000-0000-0000-000000000121",
          "kind": "text",
          "title": "legacy",
          "searchText": "legacy",
          "createdAt": "2026-05-22T09:31:52Z",
          "lastCopiedAt": "2026-05-22T09:46:58Z",
          "copyCount": 2,
          "isFavorite": true,
          "isPinned": false,
          "contentHash": "legacy-hash",
          "plainText": "legacy"
        }
      ]
      """.utf8
    )
    try legacyData.write(to: url, options: .atomic)
    let legacyRecords = try repository.load()
    expect(legacyRecords.first?.contents.isEmpty == true, "JSON repository should default missing legacy contents")
    expect(legacyRecords.first?.previewFilePath == nil, "JSON repository should default missing legacy preview path")
  } catch {
    fatalError("JSON repository check failed: \(error)")
  }
}

func checkSQLiteHistoryRepository() {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "LitePasteSQLiteChecks-\(UUID().uuidString)", directoryHint: .isDirectory)
  let url = directory.appending(path: "history.sqlite3")

  do {
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    let repository = SQLiteClipboardHistoryRepository(url: url)
    let first = ClipboardRecord(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
      kind: .image,
      title: "first",
      searchText: "first image",
      note: "note",
      sourceAppBundleId: "com.example.Source",
      sourceAppName: "Source",
      createdAt: Date(timeIntervalSince1970: 1),
      lastCopiedAt: Date(timeIntervalSince1970: 2),
      lastUsedAt: Date(timeIntervalSince1970: 3),
      copyCount: 4,
      isFavorite: true,
      isPinned: true,
      pinShortcut: "command+option+1",
      contentHash: "hash-1",
      plainText: nil,
      contents: [
        ClipboardContentSnapshot(
          pasteboardType: "public.png",
          storageMode: .external,
          externalFilePath: "/tmp/image.png",
          byteSize: 42,
          displayOrder: 0
        )
      ],
      previewFilePath: "/tmp/preview.png"
    )
    let second = ClipboardRecord(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
      kind: .text,
      title: "second",
      searchText: "second text",
      createdAt: Date(timeIntervalSince1970: 4),
      lastCopiedAt: Date(timeIntervalSince1970: 5),
      copyCount: 1,
      contentHash: "hash-2",
      plainText: "second"
    )

    try repository.save([first, second])
    let loaded = try repository.load()

    expect(loaded == [first, second], "SQLite repository should round-trip records in saved order")

    try repository.save([second])
    let overwritten = try repository.load()

    expect(overwritten == [second], "SQLite repository save should replace previous history snapshot")
  } catch {
    fatalError("SQLite repository check failed: \(error)")
  }
}

func checkSQLiteHistoryQueryAndMaintenance() {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "LitePasteSQLiteQueryChecks-\(UUID().uuidString)", directoryHint: .isDirectory)
  let url = directory.appending(path: "history.sqlite3")

  do {
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    let repository = SQLiteClipboardHistoryRepository(url: url)
    let engine = ClipboardHistoryQueryEngine()
    let records = [
      ClipboardRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
        kind: .text,
        title: "old memo",
        searchText: "alpha body",
        note: "saved memo",
        sourceAppBundleId: "com.example.Old",
        sourceAppName: "OldApp",
        createdAt: Date(timeIntervalSince1970: 10),
        lastCopiedAt: Date(timeIntervalSince1970: 10),
        copyCount: 1,
        contentHash: "query-old"
      ),
      ClipboardRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
        kind: .image,
        title: "screenshot",
        searchText: "canvas",
        sourceAppBundleId: "com.example.Image",
        sourceAppName: "ImageApp",
        createdAt: Date(timeIntervalSince1970: 11),
        lastCopiedAt: Date(timeIntervalSince1970: 11),
        copyCount: 2,
        isPinned: true,
        contentHash: "query-image"
      ),
      ClipboardRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!,
        kind: .files,
        title: "report.pdf",
        searchText: "project source",
        sourceAppBundleId: "com.example.Files",
        sourceAppName: "Finder",
        createdAt: Date(timeIntervalSince1970: 12),
        lastCopiedAt: Date(timeIntervalSince1970: 12),
        copyCount: 9,
        isFavorite: true,
        contentHash: "query-files"
      ),
      ClipboardRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000104")!,
        kind: .url,
        title: "100%_literal",
        searchText: "https://example.com",
        createdAt: Date(timeIntervalSince1970: 13),
        lastCopiedAt: Date(timeIntervalSince1970: 13),
        copyCount: 3,
        contentHash: "query-url",
        plainText: "https://example.com"
      ),
      ClipboardRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000105")!,
        kind: .color,
        title: "#22C55E",
        searchText: "#22C55E RGB(34, 197, 94)",
        createdAt: Date(timeIntervalSince1970: 9),
        lastCopiedAt: Date(timeIntervalSince1970: 9),
        copyCount: 1,
        contentHash: "query-color",
        plainText: "#22C55E"
      )
    ]

    try repository.save(records)

    let queries = [
      ClipboardHistoryQuery(),
      ClipboardHistoryQuery(text: "memo OldApp"),
      ClipboardHistoryQuery(text: "图片"),
      ClipboardHistoryQuery(text: "100%_literal"),
      ClipboardHistoryQuery(filter: .files),
      ClipboardHistoryQuery(filter: .text),
      ClipboardHistoryQuery(filter: .links),
      ClipboardHistoryQuery(filter: .colors),
      ClipboardHistoryQuery(filter: .favorites, sort: .mostUsed),
      ClipboardHistoryQuery(sort: .mostUsed)
    ]

    for query in queries {
      let expected = engine.execute(query, records: records).map(\.id)
      let actual = try repository.execute(query).map(\.id)
      expect(actual == expected, "SQLite query should match in-memory query engine for \(query)")
    }

    let limited = try repository.execute(ClipboardHistoryQuery(sort: .recent), limit: 2)
    expect(limited.map(\.id) == [records[3].id, records[2].id], "SQLite query should apply limits after sorting")

    let lookedUp = try repository.record(id: records[2].id)
    expect(lookedUp?.id == records[2].id, "SQLite repository should look up records by id")
    let hashLookup = try repository.record(contentHash: records[2].contentHash)
    expect(hashLookup?.id == records[2].id, "SQLite repository should look up records by content hash")
    let missingRecord = try repository.record(id: UUID())
    expect(missingRecord == nil, "SQLite repository should return nil for missing ids")

    let offset = try repository.execute(ClipboardHistoryQuery(sort: .recent), limit: 2, offset: 1)
    expect(offset.map(\.id) == [records[2].id, records[1].id], "SQLite query should apply offsets after sorting")

    let favoriteCount = try repository.count(ClipboardHistoryQuery(filter: .favorites))
    expect(favoriteCount == 1, "SQLite query should count filtered records")

    var updated = records[1]
    updated.note = "incremental note"
    updated.copyCount = 12
    try repository.upsert(updated, position: nil)
    let incrementallyUpdated = try repository.record(id: updated.id)
    let idsAfterUpdate = try repository.load().map(\.id)
    expect(incrementallyUpdated == updated, "SQLite repository should update existing records incrementally")
    expect(idsAfterUpdate == records.map(\.id), "SQLite repository should preserve position when upserting existing records")

    let appended = ClipboardRecord(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000105")!,
      kind: .text,
      title: "appended",
      searchText: "appended",
      createdAt: Date(timeIntervalSince1970: 14),
      lastCopiedAt: Date(timeIntervalSince1970: 14),
      contentHash: "query-appended",
      plainText: "appended"
    )
    try repository.upsert(appended, position: nil)
    let idsAfterAppend = try repository.load().map(\.id)
    expect(idsAfterAppend.last == appended.id, "SQLite repository should append new upserted records")
    try repository.delete(id: appended.id)
    let deletedRecord = try repository.record(id: appended.id)
    expect(deletedRecord == nil, "SQLite repository should delete records incrementally")
    try repository.upsert(appended, position: 0)
    let idsAfterPositionedUpsert = try repository.load().map(\.id)
    expect(idsAfterPositionedUpsert.first == appended.id, "SQLite repository should honor explicit upsert positions")
    try repository.deleteAll()
    let recordsAfterDeleteAll = try repository.load()
    expect(recordsAfterDeleteAll.isEmpty, "SQLite repository should delete all records incrementally")
    try repository.save(records)

    try repository.performMaintenance()
    let recordsAfterMaintenance = try repository.load()
    expect(recordsAfterMaintenance == records, "SQLite maintenance should preserve saved history")
  } catch {
    fatalError("SQLite query check failed: \(error)")
  }
}

func checkMigratingHistoryRepository() {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "LitePasteMigrationChecks-\(UUID().uuidString)", directoryHint: .isDirectory)
  let legacyURL = directory.appending(path: "history.json")
  let sqliteURL = directory.appending(path: "history.sqlite3")

  do {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    let legacyRecord = ClipboardRecord(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
      kind: .text,
      title: "legacy",
      searchText: "legacy",
      createdAt: Date(timeIntervalSince1970: 10),
      lastCopiedAt: Date(timeIntervalSince1970: 11),
      contentHash: "legacy-hash",
      plainText: "legacy"
    )
    try JSONClipboardHistoryRepository(url: legacyURL).save([legacyRecord])

    let repository = MigratingClipboardHistoryRepository(sqliteURL: sqliteURL, legacyJSONURL: legacyURL)
    let migrated = try repository.load()
    let sqliteRecords = try SQLiteClipboardHistoryRepository(url: sqliteURL).load()

    expect(migrated == [legacyRecord], "Migrating repository should load legacy JSON records")
    expect(
      sqliteRecords == [legacyRecord],
      "Migrating repository should persist legacy records into SQLite"
    )
    expect(
      !FileManager.default.fileExists(atPath: legacyURL.path),
      "Migrating repository should remove legacy JSON after successful migration"
    )

    let queryLegacyURL = directory.appending(path: "query-history.json")
    let querySQLiteURL = directory.appending(path: "query-history.sqlite3")
    try JSONClipboardHistoryRepository(url: queryLegacyURL).save([legacyRecord])
    let queryRepository = MigratingClipboardHistoryRepository(sqliteURL: querySQLiteURL, legacyJSONURL: queryLegacyURL)
    let queryMigrated = try queryRepository.execute(ClipboardHistoryQuery(text: "legacy"), limit: 1, offset: 0)
    let queryCount = try queryRepository.count(ClipboardHistoryQuery())
    expect(queryMigrated == [legacyRecord], "Migrating repository should migrate before direct paged queries")
    expect(queryCount == 1, "Migrating repository should count after direct query migration")

    let lookupLegacyURL = directory.appending(path: "lookup-history.json")
    let lookupSQLiteURL = directory.appending(path: "lookup-history.sqlite3")
    try JSONClipboardHistoryRepository(url: lookupLegacyURL).save([legacyRecord])
    let lookupRepository = MigratingClipboardHistoryRepository(sqliteURL: lookupSQLiteURL, legacyJSONURL: lookupLegacyURL)
    let lookupRecord = try lookupRepository.record(id: legacyRecord.id)
    expect(
      lookupRecord == legacyRecord,
      "Migrating repository should migrate before direct record lookup"
    )
    let lookupHashRecord = try lookupRepository.record(contentHash: legacyRecord.contentHash)
    expect(
      lookupHashRecord == legacyRecord,
      "Migrating repository should support content hash lookup after migration"
    )

    let incrementalLegacyURL = directory.appending(path: "incremental-history.json")
    let incrementalSQLiteURL = directory.appending(path: "incremental-history.sqlite3")
    try JSONClipboardHistoryRepository(url: incrementalLegacyURL).save([legacyRecord])
    let incrementalRepository = MigratingClipboardHistoryRepository(
      sqliteURL: incrementalSQLiteURL,
      legacyJSONURL: incrementalLegacyURL
    )
    var incrementallyUpdated = legacyRecord
    incrementallyUpdated.note = "updated through migration"
    try incrementalRepository.upsert(incrementallyUpdated, position: nil)
    let migratedIncrementalUpdate = try incrementalRepository.record(id: legacyRecord.id)
    expect(
      migratedIncrementalUpdate == incrementallyUpdated,
      "Migrating repository should upsert after migrating legacy records"
    )
    try incrementalRepository.delete(id: legacyRecord.id)
    let deletedMigratedRecord = try incrementalRepository.record(id: legacyRecord.id)
    expect(
      deletedMigratedRecord == nil,
      "Migrating repository should delete records after migration"
    )

    let currentRecord = ClipboardRecord(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
      kind: .text,
      title: "current",
      searchText: "current",
      createdAt: Date(timeIntervalSince1970: 20),
      lastCopiedAt: Date(timeIntervalSince1970: 21),
      contentHash: "current-hash",
      plainText: "current"
    )
    try repository.save([currentRecord])
    let currentRecords = try repository.load()

    expect(currentRecords == [currentRecord], "Migrating repository should prefer SQLite after migration")

    try JSONClipboardHistoryRepository(url: legacyURL).save([legacyRecord])
    try repository.save([])
    let emptyRecords = try repository.load()
    expect(emptyRecords.isEmpty, "Migrating repository should not resurrect legacy JSON after empty save")
  } catch {
    fatalError("Migrating repository check failed: \(error)")
  }
}

@MainActor
func checkHistoryPersistenceCleanup() {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "LitePastePersistenceCleanup-\(UUID().uuidString)", directoryHint: .isDirectory)
  let historyURL = directory.appending(path: "history.json")
  let blobsDirectory = directory.appending(path: "Blobs", directoryHint: .isDirectory)
  let repository = JSONClipboardHistoryRepository(url: historyURL)
  let storage = LocalBlobStorage(directory: blobsDirectory)
  let now = Date()

  do {
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    let expiredPayload = try externalBlobPayload(
      title: "expired",
      contentHashBasis: "expired",
      data: Data("expired".utf8),
      storage: storage
    )
    let pinnedPayload = try externalBlobPayload(
      title: "pinned old",
      contentHashBasis: "pinned-old",
      data: Data("pinned old".utf8),
      storage: storage
    )
    let recentPayload = try externalBlobPayload(
      title: "recent",
      contentHashBasis: "recent",
      data: Data("recent".utf8),
      storage: storage
    )
    let newestPayload = try externalBlobPayload(
      title: "newest",
      contentHashBasis: "newest",
      data: Data("newest".utf8),
      storage: storage
    )

    let expiredPath = expiredPayload.contents[0].externalFilePath ?? ""
    let pinnedPath = pinnedPayload.contents[0].externalFilePath ?? ""
    let recentPath = recentPayload.contents[0].externalFilePath ?? ""
    let newestPath = newestPayload.contents[0].externalFilePath ?? ""

    let expired = record(
      from: expiredPayload,
      lastCopiedAt: now.addingTimeInterval(-5 * 86_400)
    )
    let pinned = record(
      from: pinnedPayload,
      lastCopiedAt: now.addingTimeInterval(-5 * 86_400),
      isPinned: true,
      pinShortcut: "command+option+1"
    )
    let recent = record(
      from: recentPayload,
      lastCopiedAt: now.addingTimeInterval(-100)
    )
    let newest = record(
      from: newestPayload,
      lastCopiedAt: now
    )

    try repository.save([expired, pinned, recent, newest])

    let store = HistoryStore(
      repository: repository,
      blobStorage: storage,
      maxHistoryCount: 2,
      retentionDays: 2
    )

    let retainedTitles = Set(store.records.map(\.title))
    expect(retainedTitles == ["pinned old", "newest"], "HistoryStore should trim loaded persistent history by retention and max count")
    expect(store.records.first?.isPinned == true, "Loaded pinned records should remain sorted before regular records")
    expect(!FileManager.default.fileExists(atPath: expiredPath), "Loading persistent history should remove expired blobs")
    expect(!FileManager.default.fileExists(atPath: recentPath), "Loading persistent history should remove overflow blobs")
    expect(FileManager.default.fileExists(atPath: pinnedPath), "Loading persistent history should keep pinned blobs")
    expect(FileManager.default.fileExists(atPath: newestPath), "Loading persistent history should keep retained blobs")

    let persistedAfterTrim = try repository.load()
    expect(
      Set(persistedAfterTrim.map(\.title)) == ["pinned old", "newest"],
      "HistoryStore should persist cleanup results back to JSON"
    )

    let importedPayload = try externalBlobPayload(
      title: "imported",
      contentHashBasis: "imported",
      data: Data("imported".utf8),
      storage: storage
    )
    let importedPath = importedPayload.contents[0].externalFilePath ?? ""
    let imported = record(from: importedPayload, lastCopiedAt: now.addingTimeInterval(10))
    try repository.save([expired, pinned, imported])
    try store.reload(now: now)

    let reloadedTitles = Set(store.records.map(\.title))
    expect(reloadedTitles == ["pinned old", "imported"], "HistoryStore reload should apply cleanup rules to persistent history")
    expect(FileManager.default.fileExists(atPath: importedPath), "HistoryStore reload should keep retained imported blobs")
  } catch {
    fatalError("History persistence cleanup check failed: \(error)")
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

    let importedSettings = AppSettings(hotkey: "command+option+space", viewMode: .list)
    try JSONEncoder.litePaste.encode(importedSettings).write(to: settingsURL, options: .atomic)

    settingsStore.reload()
    expect(settingsStore.settings.viewMode == .list, "AppSettingsStore reload should read imported view mode")
    expect(settingsStore.settings.hotkey == "command+option+space", "AppSettingsStore reload should read imported hotkey")
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

    let validBlobBackup = directory.appending(path: "ValidBlob.litepastebackup", directoryHint: .isDirectory)
    let validBlobs = validBlobBackup.appending(path: "Blobs", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: validBlobs, withIntermediateDirectories: true)
    try Data(#"{"createdAt":"2026-01-01T00:00:00Z","formatVersion":1}"#.utf8)
      .write(to: validBlobBackup.appending(path: "manifest.json"))
    try Data("blob".utf8).write(to: validBlobs.appending(path: "image.bin"))
    try JSONEncoder.litePaste.encode([
      ClipboardRecord(
        kind: .image,
        title: "image",
        searchText: "image",
        contentHash: "image",
        contents: [
          ClipboardContentSnapshot(
            pasteboardType: "public.png",
            storageMode: .external,
            externalFilePath: validBlobs.appending(path: "image.bin").path,
            byteSize: 4,
            displayOrder: 0
          )
        ],
        previewFilePath: validBlobs.appending(path: "image.bin").path
      )
    ])
    .write(to: validBlobBackup.appending(path: "history.json"))
    try service.validateBackup(at: validBlobBackup)

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

    let missingBlobBackup = directory.appending(path: "MissingBlob.litepastebackup", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: missingBlobBackup, withIntermediateDirectories: true)
    try Data(#"{"createdAt":"2026-01-01T00:00:00Z","formatVersion":1}"#.utf8)
      .write(to: missingBlobBackup.appending(path: "manifest.json"))
    try FileManager.default.createDirectory(at: missingBlobBackup.appending(path: "Blobs", directoryHint: .isDirectory), withIntermediateDirectories: true)
    try JSONEncoder.litePaste.encode([
      ClipboardRecord(
        kind: .image,
        title: "missing",
        searchText: "missing",
        contentHash: "missing",
        contents: [
          ClipboardContentSnapshot(
            pasteboardType: "public.png",
            storageMode: .external,
            externalFilePath: missingBlobBackup.appending(path: "Blobs/missing.png").path,
            byteSize: 7,
            displayOrder: 0
          )
        ]
      )
    ])
    .write(to: missingBlobBackup.appending(path: "history.json"))

    do {
      try service.validateBackup(at: missingBlobBackup)
      fatalError("Backup with missing external blob should be rejected")
    } catch BackupError.missingBlob("missing.png") {
      // Expected.
    }

    expect(
      BackupError.invalidBackup.localizedDescription == "备份文件无效或已损坏。",
      "Backup errors should have user-facing localized descriptions"
    )
    expect(
      BackupError.missingBlob("missing.png").localizedDescription == "备份缺少媒体文件：missing.png。",
      "Missing blob errors should name the missing file"
    )
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
  let legacyRepository = JSONClipboardHistoryRepository(url: paths.historyURL)
  let repository = MigratingClipboardHistoryRepository(
    sqliteURL: paths.sqliteHistoryURL,
    legacyJSONURL: paths.historyURL
  )

  do {
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    try paths.ensureBlobsDirectoryExists()
    try FileManager.default.createDirectory(at: backupParent, withIntermediateDirectories: true)

    let sourceBlob = paths.blobsDirectory.appending(path: "image.bin")
    let orphanBlob = paths.blobsDirectory.appending(path: "orphan.bin")
    try Data("blob-a".utf8).write(to: sourceBlob, options: .atomic)
    try Data("orphan".utf8).write(to: orphanBlob, options: .atomic)
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
    try legacyRepository.save([sourceRecord])
    try JSONEncoder.litePaste.encode(AppSettings(hotkey: "command+option+space", viewMode: .list))
      .write(to: paths.settingsURL, options: .atomic)

    let backupURL = try service.exportBackup(to: backupParent, now: Date(timeIntervalSince1970: 100))
    let exportedHistory = try JSONClipboardHistoryRepository(url: backupURL.appending(path: "history.json")).load()
    let exportedBlob = backupURL.appending(path: "Blobs/image.bin")
    let exportedOrphanBlob = backupURL.appending(path: "Blobs/orphan.bin")

    expect(FileManager.default.fileExists(atPath: exportedBlob.path), "Export should copy external blobs")
    expect(!FileManager.default.fileExists(atPath: exportedOrphanBlob.path), "Export should skip unreferenced orphan blobs")
    expect(
      exportedHistory.first?.previewFilePath == exportedBlob.path,
      "Export should rewrite preview blob paths into backup directory"
    )

    let backupsBeforeFailedExport = try backupDirectoryNames(in: backupParent)
    let missingExportRecord = ClipboardRecord(
      kind: .image,
      title: "missing export",
      searchText: "missing export",
      lastCopiedAt: Date(timeIntervalSince1970: 35),
      contentHash: "hash-missing-export",
      contents: [
        ClipboardContentSnapshot(
          pasteboardType: "public.data",
          storageMode: .external,
          externalFilePath: paths.blobsDirectory.appending(path: "missing-export.bin").path,
          byteSize: 6,
          displayOrder: 0
        )
      ]
    )
    try repository.save([missingExportRecord])
    do {
      _ = try service.exportBackup(to: backupParent, now: Date(timeIntervalSince1970: 101))
      fatalError("Export should fail when referenced blobs are missing")
    } catch BackupError.missingBlob("missing-export.bin") {
    } catch {
      fatalError("Export should report the missing blob name, got \(error)")
    }
    let backupsAfterFailedExport = try backupDirectoryNames(in: backupParent)
    expect(
      backupsAfterFailedExport == backupsBeforeFailedExport,
      "Failed export should remove partial backup directories"
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
    expect(restoredSettings.hotkey == "command+option+space", "Replace import should restore settings")

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
    let collisionBlob = paths.blobsDirectory.appending(path: "incoming.bin")
    try Data("local-collision".utf8).write(to: collisionBlob, options: .atomic)
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
    let importedRecord = mergedHistory.first { $0.contentHash == "hash-incoming" }
    let importedPreviewPath = importedRecord?.previewFilePath ?? ""

    expect(mergedHistory.count == 3, "Merge import should keep existing and add unique incoming records")
    expect(hashCounts["hash-a"] == 1, "Merge import should deduplicate by content hash")
    expect(
      importedPreviewPath != importedBlob.path,
      "Merge import should avoid overwriting existing blob filename collisions"
    )
    expect(FileManager.default.fileExists(atPath: importedPreviewPath), "Merge import should copy incoming blobs")
    expect(
      (try? Data(contentsOf: URL(fileURLWithPath: importedPreviewPath))) == Data("incoming".utf8),
      "Merge import should keep incoming blob data when resolving collisions"
    )
    expect(
      (try? Data(contentsOf: collisionBlob)) == Data("local-collision".utf8),
      "Merge import should not overwrite existing colliding blobs"
    )
    expect(mergedSettings.hotkey == "command+option+space", "Merge import should not overwrite existing settings")

    let emptyBackup = directory.appending(path: "Empty.litepastebackup", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: emptyBackup, withIntermediateDirectories: true)
    try Data(#"{"createdAt":"2026-01-01T00:00:00Z","formatVersion":1}"#.utf8)
      .write(to: emptyBackup.appending(path: "manifest.json"))
    try service.importBackup(from: emptyBackup, mode: .replace)

    let emptyReplaceHistory = try repository.load()
    expect(emptyReplaceHistory.isEmpty, "Replace import without history should clear existing history")
    expect(
      !FileManager.default.fileExists(atPath: paths.settingsURL.path),
      "Replace import without settings should remove existing settings so defaults are used"
    )
    expect(
      !FileManager.default.fileExists(atPath: paths.blobsDirectory.path),
      "Replace import without blobs should clear existing blobs"
    )
  } catch {
    fatalError("Import/export round-trip check failed: \(error)")
  }
}

func backupDirectoryNames(in directory: URL) throws -> [String] {
  try FileManager.default
    .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    .map(\.lastPathComponent)
    .sorted()
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
  exit(runChecks())
}

RunLoop.main.run()
