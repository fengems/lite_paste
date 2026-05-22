import Foundation

public enum BackupImportMode: Sendable {
  case replace
  case merge
}

public struct ImportExportService: Sendable {
  public init() {}

  public func exportBackup(to parentDirectory: URL, now: Date = .now) throws -> URL {
    try AppPaths.ensureApplicationSupportDirectoryExists()

    let backupURL = parentDirectory
      .appending(path: "LitePaste-\(Self.timestampFormatter.string(from: now)).litepastebackup", directoryHint: .isDirectory)

    if FileManager.default.fileExists(atPath: backupURL.path) {
      try FileManager.default.removeItem(at: backupURL)
    }

    try FileManager.default.createDirectory(at: backupURL, withIntermediateDirectories: true)
    try copyIfExists(from: AppPaths.historyURL, to: backupURL.appending(path: "history.json"))
    try copyIfExists(from: AppPaths.settingsURL, to: backupURL.appending(path: "settings.json"))
    try copyDirectoryIfExists(from: AppPaths.blobsDirectory, to: backupURL.appending(path: "Blobs", directoryHint: .isDirectory))

    let manifest = BackupManifest(createdAt: now, formatVersion: 1)
    let manifestData = try JSONEncoder.litePaste.encode(manifest)
    try manifestData.write(to: backupURL.appending(path: "manifest.json"), options: .atomic)

    return backupURL
  }

  public func importBackup(from backupURL: URL, mode: BackupImportMode) throws {
    let manifestURL = backupURL.appending(path: "manifest.json")
    guard FileManager.default.fileExists(atPath: manifestURL.path) else {
      throw BackupError.invalidBackup
    }

    try AppPaths.ensureApplicationSupportDirectoryExists()

    switch mode {
    case .replace:
      try replaceBackup(from: backupURL)
    case .merge:
      try mergeBackup(from: backupURL)
    }
  }

  private func replaceBackup(from backupURL: URL) throws {
    try replaceIfExists(from: backupURL.appending(path: "history.json"), to: AppPaths.historyURL)
    try replaceIfExists(from: backupURL.appending(path: "settings.json"), to: AppPaths.settingsURL)
    try replaceDirectoryIfExists(from: backupURL.appending(path: "Blobs", directoryHint: .isDirectory), to: AppPaths.blobsDirectory)
  }

  private func mergeBackup(from backupURL: URL) throws {
    let incomingHistory = try JSONClipboardHistoryRepository(url: backupURL.appending(path: "history.json")).load()
    let repository = JSONClipboardHistoryRepository()
    let existingHistory = try repository.load()
    let merged = merge(existing: existingHistory, incoming: incomingHistory)
    try repository.save(merged)

    try copyDirectoryContentsIfExists(
      from: backupURL.appending(path: "Blobs", directoryHint: .isDirectory),
      to: AppPaths.blobsDirectory
    )

    let incomingSettings = backupURL.appending(path: "settings.json")
    if !FileManager.default.fileExists(atPath: AppPaths.settingsURL.path) {
      try copyIfExists(from: incomingSettings, to: AppPaths.settingsURL)
    }
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
}

private struct BackupManifest: Codable {
  var createdAt: Date
  var formatVersion: Int
}
