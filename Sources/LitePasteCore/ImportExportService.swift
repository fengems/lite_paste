import Foundation

public struct ImportExportService: Sendable {
  private static let supportedFormatVersion = 1
  private let paths: AppStoragePaths

  public init(paths: AppStoragePaths = AppStoragePaths()) {
    self.paths = paths
  }

  public func exportBackup(to parentDirectory: URL, now: Date = .now) throws -> URL {
    try paths.ensureApplicationSupportDirectoryExists()

    let backupURL = parentDirectory
      .appending(path: "LitePaste-\(Self.timestampFormatter.string(from: now)).litepastebackup", directoryHint: .isDirectory)

    if FileManager.default.fileExists(atPath: backupURL.path) {
      try FileManager.default.removeItem(at: backupURL)
    }

    var didFinishExport = false
    defer {
      if !didFinishExport {
        try? FileManager.default.removeItem(at: backupURL)
      }
    }

    try FileManager.default.createDirectory(at: backupURL, withIntermediateDirectories: true)
    try exportHistoryIfExists(
      to: BackupLayout.historyURL(in: backupURL),
      blobsDirectory: BackupLayout.blobsDirectory(in: backupURL)
    )
    try BackupFileOperations.copyFileIfExists(from: paths.settingsURL, to: BackupLayout.settingsURL(in: backupURL))

    let manifest = BackupManifest(createdAt: now, formatVersion: Self.supportedFormatVersion)
    let manifestData = try JSONEncoder.litePaste.encode(manifest)
    try manifestData.write(to: BackupLayout.manifestURL(in: backupURL), options: .atomic)

    didFinishExport = true
    return backupURL
  }

  public func importBackup(from backupURL: URL, mode: BackupImportMode) throws {
    try validateBackup(at: backupURL)

    try paths.ensureApplicationSupportDirectoryExists()

    switch mode {
    case .replace:
      try replaceBackup(from: backupURL)
    case .merge:
      try mergeBackup(from: backupURL)
    }
  }

  public func validateBackup(at backupURL: URL) throws {
    try BackupValidator.validateBackup(at: backupURL, supportedFormatVersion: Self.supportedFormatVersion)
  }

  private func replaceBackup(from backupURL: URL) throws {
    try replaceBlobDirectory(from: BackupLayout.blobsDirectory(in: backupURL))
    try replaceHistory(from: BackupLayout.historyURL(in: backupURL))
    try replaceSettings(from: BackupLayout.settingsURL(in: backupURL))
  }

  private func mergeBackup(from backupURL: URL) throws {
    let repository = currentHistoryRepository()
    let existingHistory = try repository.load()
    let uniqueIncomingHistory = uniqueRecords(
      in: try loadHistoryRecordsIfExists(at: BackupLayout.historyURL(in: backupURL)),
      comparedTo: existingHistory
    )
    let importedIncomingHistory = try BackupBlobMapper.copyExternalBlobsForMerge(
      in: uniqueIncomingHistory,
      from: BackupLayout.blobsDirectory(in: backupURL),
      to: paths.blobsDirectory
    )

    let merged = merge(existing: existingHistory, incoming: importedIncomingHistory)
    try repository.save(merged)

    let incomingSettings = BackupLayout.settingsURL(in: backupURL)
    if !FileManager.default.fileExists(atPath: paths.settingsURL.path) {
      try BackupFileOperations.copyFileIfExists(from: incomingSettings, to: paths.settingsURL)
    }
  }

  private func exportHistoryIfExists(to destination: URL, blobsDirectory: URL) throws {
    let records = try currentHistoryRepository().load()
    guard !records.isEmpty else {
      return
    }

    let portableRecords = try BackupBlobMapper.copyExternalBlobsForExport(in: records, to: blobsDirectory)
    let data = try JSONEncoder.litePaste.encode(portableRecords)
    try data.write(to: destination, options: .atomic)
  }

  private func replaceHistory(from source: URL) throws {
    let records = try loadHistoryIfExists(at: source, rewritingExternalBlobPathsTo: paths.blobsDirectory)
    try currentHistoryRepository().save(records)
  }

  private func replaceSettings(from source: URL) throws {
    if FileManager.default.fileExists(atPath: source.path) {
      try BackupFileOperations.replaceFileIfExists(from: source, to: paths.settingsURL)
      return
    }

    try BackupFileOperations.removeIfExists(paths.settingsURL)
  }

  private func replaceBlobDirectory(from source: URL) throws {
    if FileManager.default.fileExists(atPath: paths.blobsDirectory.path) {
      try FileManager.default.removeItem(at: paths.blobsDirectory)
    }

    try BackupFileOperations.copyDirectoryIfExists(from: source, to: paths.blobsDirectory)
  }

  private func currentHistoryRepository() -> any ClipboardHistoryRepository {
    MigratingClipboardHistoryRepository(
      sqliteURL: paths.sqliteHistoryURL,
      legacyJSONURL: paths.historyURL
    )
  }

  private func loadHistoryIfExists(
    at url: URL,
    rewritingExternalBlobPathsTo blobsDirectory: URL
  ) throws -> [ClipboardRecord] {
    let records = try loadHistoryRecordsIfExists(at: url)
    return BackupBlobMapper.rewriteExternalBlobPaths(in: records, to: blobsDirectory)
  }

  private func loadHistoryRecordsIfExists(at url: URL) throws -> [ClipboardRecord] {
    guard FileManager.default.fileExists(atPath: url.path) else {
      return []
    }

    return try JSONClipboardHistoryRepository(url: url).load()
  }

  private func uniqueRecords(
    in incoming: [ClipboardRecord],
    comparedTo existing: [ClipboardRecord]
  ) -> [ClipboardRecord] {
    var seen = Set(existing.map(\.contentHash))
    var unique: [ClipboardRecord] = []

    for record in incoming where !seen.contains(record.contentHash) {
      unique.append(record)
      seen.insert(record.contentHash)
    }

    return unique
  }

  private func merge(existing: [ClipboardRecord], incoming: [ClipboardRecord]) -> [ClipboardRecord] {
    var seen = Set(existing.map(\.contentHash))
    var merged = existing

    for record in incoming where !seen.contains(record.contentHash) {
      merged.append(record)
      seen.insert(record.contentHash)
    }

    return merged.sorted { lhs, rhs in
      if lhs.isPinned != rhs.isPinned {
        return lhs.isPinned && !rhs.isPinned
      }

      return lhs.lastCopiedAt > rhs.lastCopiedAt
    }
  }

  private static let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return formatter
  }()
}
