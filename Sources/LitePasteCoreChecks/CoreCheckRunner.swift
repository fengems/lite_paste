import Foundation

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
    CheckCase(group: "monitoring", name: "policy", run: checkClipboardMonitoringPolicy),
    CheckCase(group: "capture", name: "text-payload-builder", run: checkClipboardTextPayloadBuilder),
    CheckCase(group: "capture", name: "file-payload-builder", run: checkClipboardFilePayloadBuilder),
    CheckCase(group: "capture", name: "media-payload-builder", run: checkClipboardMediaPayloadBuilder),
    CheckCase(group: "capture", name: "payload-resolver", run: checkClipboardPayloadResolver),
    CheckCase(group: "capture", name: "ocr-policy", run: checkClipboardOCRPolicy),
    CheckCase(group: "capture", name: "capture-gate", run: checkClipboardCaptureGate),
    CheckCase(group: "pasteboard", name: "system-plain-text-policy", run: checkSystemClipboardPlainTextPolicy),
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
    CheckCase(group: "backup", name: "icloud", run: checkICloudBackupService),
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
