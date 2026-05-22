import Foundation

public enum BackupImportMode: Sendable {
  case replace
  case merge
}

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

    try FileManager.default.createDirectory(at: backupURL, withIntermediateDirectories: true)
    let backupBlobsDirectory = backupURL.appending(path: "Blobs", directoryHint: .isDirectory)
    try copyDirectoryIfExists(from: paths.blobsDirectory, to: backupBlobsDirectory)
    try exportHistoryIfExists(to: backupURL.appending(path: "history.json"), blobsDirectory: backupBlobsDirectory)
    try copyIfExists(from: paths.settingsURL, to: backupURL.appending(path: "settings.json"))

    let manifest = BackupManifest(createdAt: now, formatVersion: Self.supportedFormatVersion)
    let manifestData = try JSONEncoder.litePaste.encode(manifest)
    try manifestData.write(to: backupURL.appending(path: "manifest.json"), options: .atomic)

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
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: backupURL.path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
      throw BackupError.invalidBackup
    }

    let manifest = try loadManifest(from: backupURL)
    guard manifest.formatVersion == Self.supportedFormatVersion else {
      throw BackupError.unsupportedFormatVersion(manifest.formatVersion)
    }

    try validateHistoryIfExists(at: backupURL.appending(path: "history.json"))
    try validateSettingsIfExists(at: backupURL.appending(path: "settings.json"))
    try validateBlobsIfExists(at: backupURL.appending(path: "Blobs", directoryHint: .isDirectory))
  }

  private func replaceBackup(from backupURL: URL) throws {
    try replaceDirectoryIfExists(from: backupURL.appending(path: "Blobs", directoryHint: .isDirectory), to: paths.blobsDirectory)
    try replaceHistoryIfExists(from: backupURL.appending(path: "history.json"))
    try replaceIfExists(from: backupURL.appending(path: "settings.json"), to: paths.settingsURL)
  }

  private func mergeBackup(from backupURL: URL) throws {
    let incomingHistory = try loadHistoryIfExists(
      at: backupURL.appending(path: "history.json"),
      rewritingExternalBlobPathsTo: paths.blobsDirectory
    )
    let repository = currentHistoryRepository()
    let existingHistory = try repository.load()
    let merged = merge(existing: existingHistory, incoming: incomingHistory)
    try repository.save(merged)

    try copyDirectoryContentsIfExists(
      from: backupURL.appending(path: "Blobs", directoryHint: .isDirectory),
      to: paths.blobsDirectory
    )

    let incomingSettings = backupURL.appending(path: "settings.json")
    if !FileManager.default.fileExists(atPath: paths.settingsURL.path) {
      try copyIfExists(from: incomingSettings, to: paths.settingsURL)
    }
  }

  private func exportHistoryIfExists(to destination: URL, blobsDirectory: URL) throws {
    let records = try currentHistoryRepository().load()
    guard !records.isEmpty else {
      return
    }

    let portableRecords = rewriteExternalBlobPaths(in: records, to: blobsDirectory)
    let data = try JSONEncoder.litePaste.encode(portableRecords)
    try data.write(to: destination, options: .atomic)
  }

  private func replaceHistoryIfExists(from source: URL) throws {
    guard FileManager.default.fileExists(atPath: source.path) else {
      return
    }

    let records = try loadHistoryIfExists(at: source, rewritingExternalBlobPathsTo: paths.blobsDirectory)
    try currentHistoryRepository().save(records)
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
    guard FileManager.default.fileExists(atPath: url.path) else {
      return []
    }

    let records = try JSONClipboardHistoryRepository(url: url).load()
    return rewriteExternalBlobPaths(in: records, to: blobsDirectory)
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

  private func rewriteExternalBlobPaths(
    in records: [ClipboardRecord],
    to blobsDirectory: URL
  ) -> [ClipboardRecord] {
    records.map { record in
      var record = record
      record.contents = record.contents.map { snapshot in
        rewriteExternalBlobPath(in: snapshot, to: blobsDirectory)
      }

      if let previewFilePath = record.previewFilePath {
        record.previewFilePath = rewrittenBlobPath(from: previewFilePath, to: blobsDirectory)
      }

      return record
    }
  }

  private func rewriteExternalBlobPath(
    in snapshot: ClipboardContentSnapshot,
    to blobsDirectory: URL
  ) -> ClipboardContentSnapshot {
    guard snapshot.storageMode == .external,
          let externalFilePath = snapshot.externalFilePath else {
      return snapshot
    }

    var snapshot = snapshot
    snapshot.externalFilePath = rewrittenBlobPath(from: externalFilePath, to: blobsDirectory)
    return snapshot
  }

  private func rewrittenBlobPath(from path: String, to blobsDirectory: URL) -> String {
    let filename = URL(fileURLWithPath: path).lastPathComponent
    return blobsDirectory.appending(path: filename).path
  }

  private func loadManifest(from backupURL: URL) throws -> BackupManifest {
    let manifestURL = backupURL.appending(path: "manifest.json")
    guard let data = try? Data(contentsOf: manifestURL),
          let manifest = try? JSONDecoder.litePaste.decode(BackupManifest.self, from: data) else {
      throw BackupError.invalidBackup
    }

    return manifest
  }

  private func validateHistoryIfExists(at url: URL) throws {
    guard FileManager.default.fileExists(atPath: url.path) else {
      return
    }

    _ = try JSONClipboardHistoryRepository(url: url).load()
  }

  private func validateSettingsIfExists(at url: URL) throws {
    guard let data = try? Data(contentsOf: url) else {
      return
    }

    do {
      _ = try JSONDecoder.litePaste.decode(AppSettings.self, from: data)
    } catch {
      throw BackupError.invalidBackup
    }
  }

  private func validateBlobsIfExists(at url: URL) throws {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
      return
    }

    guard isDirectory.boolValue else {
      throw BackupError.invalidBackup
    }
  }

  private func copyIfExists(from source: URL, to destination: URL) throws {
    guard FileManager.default.fileExists(atPath: source.path) else {
      return
    }

    try replaceIfExists(from: source, to: destination)
  }

  private func replaceIfExists(from source: URL, to destination: URL) throws {
    guard FileManager.default.fileExists(atPath: source.path) else {
      return
    }

    if FileManager.default.fileExists(atPath: destination.path) {
      try FileManager.default.removeItem(at: destination)
    }

    try FileManager.default.copyItem(at: source, to: destination)
  }

  private func copyDirectoryIfExists(from source: URL, to destination: URL) throws {
    guard FileManager.default.fileExists(atPath: source.path) else {
      return
    }

    try replaceDirectoryIfExists(from: source, to: destination)
  }

  private func replaceDirectoryIfExists(from source: URL, to destination: URL) throws {
    guard FileManager.default.fileExists(atPath: source.path) else {
      return
    }

    if FileManager.default.fileExists(atPath: destination.path) {
      try FileManager.default.removeItem(at: destination)
    }

    try FileManager.default.copyItem(at: source, to: destination)
  }

  private func copyDirectoryContentsIfExists(from source: URL, to destination: URL) throws {
    guard FileManager.default.fileExists(atPath: source.path) else {
      return
    }

    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    let contents = try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)

    for sourceURL in contents {
      let destinationURL = destination.appending(path: sourceURL.lastPathComponent)
      if FileManager.default.fileExists(atPath: destinationURL.path) {
        continue
      }
      try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
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

public enum BackupError: Error, Equatable {
  case invalidBackup
  case unsupportedFormatVersion(Int)
}

private struct BackupManifest: Codable {
  var createdAt: Date
  var formatVersion: Int
}
