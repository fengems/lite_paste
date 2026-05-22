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

    try validateHistoryIfExists(
      at: backupURL.appending(path: "history.json"),
      blobsDirectory: backupURL.appending(path: "Blobs", directoryHint: .isDirectory)
    )
    try validateSettingsIfExists(at: backupURL.appending(path: "settings.json"))
    try validateBlobsIfExists(at: backupURL.appending(path: "Blobs", directoryHint: .isDirectory))
  }

  private func replaceBackup(from backupURL: URL) throws {
    try replaceBlobDirectory(from: backupURL.appending(path: "Blobs", directoryHint: .isDirectory))
    try replaceHistory(from: backupURL.appending(path: "history.json"))
    try replaceIfExists(from: backupURL.appending(path: "settings.json"), to: paths.settingsURL)
  }

  private func mergeBackup(from backupURL: URL) throws {
    let repository = currentHistoryRepository()
    let existingHistory = try repository.load()
    let uniqueIncomingHistory = uniqueRecords(
      in: try loadHistoryRecordsIfExists(at: backupURL.appending(path: "history.json")),
      comparedTo: existingHistory
    )
    let importedIncomingHistory = try copyExternalBlobsForMerge(
      in: uniqueIncomingHistory,
      from: backupURL.appending(path: "Blobs", directoryHint: .isDirectory),
      to: paths.blobsDirectory
    )

    let merged = merge(existing: existingHistory, incoming: importedIncomingHistory)
    try repository.save(merged)

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

    let portableRecords = try copyExternalBlobsForExport(in: records, to: blobsDirectory)
    let data = try JSONEncoder.litePaste.encode(portableRecords)
    try data.write(to: destination, options: .atomic)
  }

  private func replaceHistory(from source: URL) throws {
    let records = try loadHistoryIfExists(at: source, rewritingExternalBlobPathsTo: paths.blobsDirectory)
    try currentHistoryRepository().save(records)
  }

  private func replaceBlobDirectory(from source: URL) throws {
    if FileManager.default.fileExists(atPath: paths.blobsDirectory.path) {
      try FileManager.default.removeItem(at: paths.blobsDirectory)
    }

    try copyDirectoryIfExists(from: source, to: paths.blobsDirectory)
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
    return rewriteExternalBlobPaths(in: records, to: blobsDirectory)
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

  private func copyExternalBlobsForMerge(
    in records: [ClipboardRecord],
    from sourceBlobsDirectory: URL,
    to destinationBlobsDirectory: URL
  ) throws -> [ClipboardRecord] {
    var copiedPaths: [String: String] = [:]

    return try records.map { record in
      var record = record
      record.contents = try record.contents.map { snapshot in
        try copyExternalBlobForMerge(
          in: snapshot,
          from: sourceBlobsDirectory,
          to: destinationBlobsDirectory,
          copiedPaths: &copiedPaths
        )
      }

      if let previewFilePath = record.previewFilePath {
        record.previewFilePath = try copiedBlobPathForMerge(
          from: previewFilePath,
          sourceBlobsDirectory: sourceBlobsDirectory,
          destinationBlobsDirectory: destinationBlobsDirectory,
          copiedPaths: &copiedPaths
        )
      }

      return record
    }
  }

  private func copyExternalBlobForMerge(
    in snapshot: ClipboardContentSnapshot,
    from sourceBlobsDirectory: URL,
    to destinationBlobsDirectory: URL,
    copiedPaths: inout [String: String]
  ) throws -> ClipboardContentSnapshot {
    guard snapshot.storageMode == .external,
          let externalFilePath = snapshot.externalFilePath else {
      return snapshot
    }

    var snapshot = snapshot
    snapshot.externalFilePath = try copiedBlobPathForMerge(
      from: externalFilePath,
      sourceBlobsDirectory: sourceBlobsDirectory,
      destinationBlobsDirectory: destinationBlobsDirectory,
      copiedPaths: &copiedPaths
    )
    return snapshot
  }

  private func copiedBlobPathForMerge(
    from path: String,
    sourceBlobsDirectory: URL,
    destinationBlobsDirectory: URL,
    copiedPaths: inout [String: String]
  ) throws -> String {
    if let copiedPath = copiedPaths[path] {
      return copiedPath
    }

    let filename = URL(fileURLWithPath: path).lastPathComponent
    let sourceURL = existingBlobSourceURL(
      originalPath: path,
      sourceBlobsDirectory: sourceBlobsDirectory
    )
    let preferredDestinationURL = destinationBlobsDirectory.appending(path: filename)

    guard let sourceURL else {
      copiedPaths[path] = preferredDestinationURL.path
      return preferredDestinationURL.path
    }

    try FileManager.default.createDirectory(at: destinationBlobsDirectory, withIntermediateDirectories: true)
    let destinationURL = uniqueDestinationURL(for: sourceURL, preferredDestinationURL: preferredDestinationURL)
    if !FileManager.default.fileExists(atPath: destinationURL.path) {
      try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    copiedPaths[path] = destinationURL.path
    return destinationURL.path
  }

  private func existingBlobSourceURL(originalPath: String, sourceBlobsDirectory: URL) -> URL? {
    let filename = URL(fileURLWithPath: originalPath).lastPathComponent
    let backupBlobURL = sourceBlobsDirectory.appending(path: filename)
    if FileManager.default.fileExists(atPath: backupBlobURL.path) {
      return backupBlobURL
    }

    let originalURL = URL(fileURLWithPath: originalPath)
    if FileManager.default.fileExists(atPath: originalURL.path) {
      return originalURL
    }

    return nil
  }

  private func uniqueDestinationURL(for sourceURL: URL, preferredDestinationURL: URL) -> URL {
    guard FileManager.default.fileExists(atPath: preferredDestinationURL.path) else {
      return preferredDestinationURL
    }

    if FileManager.default.contentsEqual(atPath: sourceURL.path, andPath: preferredDestinationURL.path) {
      return preferredDestinationURL
    }

    let directory = preferredDestinationURL.deletingLastPathComponent()
    let stem = preferredDestinationURL.deletingPathExtension().lastPathComponent
    let fileExtension = preferredDestinationURL.pathExtension

    while true {
      let suffix = UUID().uuidString
      let filename = fileExtension.isEmpty ? "\(stem)-\(suffix)" : "\(stem)-\(suffix).\(fileExtension)"
      let candidate = directory.appending(path: filename)
      if !FileManager.default.fileExists(atPath: candidate.path) {
        return candidate
      }
    }
  }

  private func copyExternalBlobsForExport(
    in records: [ClipboardRecord],
    to backupBlobsDirectory: URL
  ) throws -> [ClipboardRecord] {
    var copiedPaths: [String: String] = [:]

    return try records.map { record in
      var record = record
      record.contents = try record.contents.map { snapshot in
        try copyExternalBlobForExport(
          in: snapshot,
          to: backupBlobsDirectory,
          copiedPaths: &copiedPaths
        )
      }

      if let previewFilePath = record.previewFilePath {
        record.previewFilePath = try copiedBlobPathForExport(
          from: previewFilePath,
          to: backupBlobsDirectory,
          copiedPaths: &copiedPaths
        )
      }

      return record
    }
  }

  private func copyExternalBlobForExport(
    in snapshot: ClipboardContentSnapshot,
    to backupBlobsDirectory: URL,
    copiedPaths: inout [String: String]
  ) throws -> ClipboardContentSnapshot {
    guard snapshot.storageMode == .external,
          let externalFilePath = snapshot.externalFilePath else {
      return snapshot
    }

    var snapshot = snapshot
    snapshot.externalFilePath = try copiedBlobPathForExport(
      from: externalFilePath,
      to: backupBlobsDirectory,
      copiedPaths: &copiedPaths
    )
    return snapshot
  }

  private func copiedBlobPathForExport(
    from path: String,
    to backupBlobsDirectory: URL,
    copiedPaths: inout [String: String]
  ) throws -> String {
    if let copiedPath = copiedPaths[path] {
      return copiedPath
    }

    let sourceURL = URL(fileURLWithPath: path)
    let preferredDestinationURL = backupBlobsDirectory.appending(path: sourceURL.lastPathComponent)

    guard FileManager.default.fileExists(atPath: sourceURL.path) else {
      copiedPaths[path] = preferredDestinationURL.path
      return preferredDestinationURL.path
    }

    try FileManager.default.createDirectory(at: backupBlobsDirectory, withIntermediateDirectories: true)
    let destinationURL = uniqueDestinationURL(for: sourceURL, preferredDestinationURL: preferredDestinationURL)
    if !FileManager.default.fileExists(atPath: destinationURL.path) {
      try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    copiedPaths[path] = destinationURL.path
    return destinationURL.path
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

  private func validateHistoryIfExists(at url: URL, blobsDirectory: URL) throws {
    guard FileManager.default.fileExists(atPath: url.path) else {
      return
    }

    let records = try JSONClipboardHistoryRepository(url: url).load()
    try validateExternalBlobs(in: records, blobsDirectory: blobsDirectory)
  }

  private func validateExternalBlobs(in records: [ClipboardRecord], blobsDirectory: URL) throws {
    for record in records {
      for snapshot in record.contents where snapshot.storageMode == .external {
        guard let externalFilePath = snapshot.externalFilePath else {
          throw BackupError.missingBlob("")
        }

        try validateExternalBlob(path: externalFilePath, byteSize: snapshot.byteSize, blobsDirectory: blobsDirectory)
      }

      if let previewFilePath = record.previewFilePath {
        try validateExternalBlob(path: previewFilePath, byteSize: nil, blobsDirectory: blobsDirectory)
      }
    }
  }

  private func validateExternalBlob(path: String, byteSize: Int?, blobsDirectory: URL) throws {
    let filename = URL(fileURLWithPath: path).lastPathComponent
    guard !filename.isEmpty else {
      throw BackupError.missingBlob(path)
    }

    let blobURL = blobsDirectory.appending(path: filename)
    guard FileManager.default.fileExists(atPath: blobURL.path) else {
      throw BackupError.missingBlob(filename)
    }

    guard let byteSize, byteSize > 0 else {
      return
    }

    let attributes = try FileManager.default.attributesOfItem(atPath: blobURL.path)
    let actualByteSize = (attributes[.size] as? NSNumber)?.intValue
    guard actualByteSize == byteSize else {
      throw BackupError.missingBlob(filename)
    }
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

  private static let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return formatter
  }()
}

public enum BackupError: Error, Equatable, LocalizedError {
  case invalidBackup
  case unsupportedFormatVersion(Int)
  case missingBlob(String)

  public var errorDescription: String? {
    switch self {
    case .invalidBackup:
      "备份文件无效或已损坏。"
    case let .unsupportedFormatVersion(version):
      "不支持的备份格式版本：\(version)。"
    case let .missingBlob(filename):
      filename.isEmpty ? "备份缺少必要的媒体文件。" : "备份缺少媒体文件：\(filename)。"
    }
  }

  public var recoverySuggestion: String? {
    switch self {
    case .invalidBackup:
      "请选择由 Lite Paste 导出的完整 .litepastebackup 备份文件夹。"
    case .unsupportedFormatVersion:
      "请升级 Lite Paste 后再导入该备份，或选择较旧版本导出的备份。"
    case .missingBlob:
      "请重新导出备份，或确认备份文件夹中的 Blobs 目录未被移动、删除或修改。"
    }
  }
}

private struct BackupManifest: Codable {
  var createdAt: Date
  var formatVersion: Int
}
