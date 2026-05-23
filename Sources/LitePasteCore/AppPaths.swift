import Foundation

public struct AppStoragePaths: Sendable {
  public var applicationSupportDirectory: URL

  public init(applicationSupportDirectory: URL = AppPaths.applicationSupportDirectory) {
    self.applicationSupportDirectory = applicationSupportDirectory
  }

  public var historyURL: URL {
    applicationSupportDirectory.appending(path: "history.json")
  }

  public var sqliteHistoryURL: URL {
    applicationSupportDirectory.appending(path: "history.sqlite3")
  }

  public var settingsURL: URL {
    applicationSupportDirectory.appending(path: "settings.json")
  }

  public var blobsDirectory: URL {
    applicationSupportDirectory.appending(path: "Blobs", directoryHint: .isDirectory)
  }

  public func ensureApplicationSupportDirectoryExists() throws {
    try FileManager.default.createDirectory(
      at: applicationSupportDirectory,
      withIntermediateDirectories: true
    )
  }

  public func ensureBlobsDirectoryExists() throws {
    try ensureApplicationSupportDirectoryExists()
    try FileManager.default.createDirectory(
      at: blobsDirectory,
      withIntermediateDirectories: true
    )
  }
}

public enum AppPaths {
  public static let applicationSupportDirectoryOverrideEnvironmentKey = "LITEPASTE_APPLICATION_SUPPORT_DIR"

  public static var storagePaths: AppStoragePaths {
    AppStoragePaths(applicationSupportDirectory: applicationSupportDirectory)
  }

  public static var applicationSupportDirectory: URL {
    applicationSupportDirectory(environment: ProcessInfo.processInfo.environment)
  }

  public static func applicationSupportDirectory(environment: [String: String]) -> URL {
    if let override = environment[applicationSupportDirectoryOverrideEnvironmentKey]?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !override.isEmpty {
      return URL(
        fileURLWithPath: (override as NSString).expandingTildeInPath,
        isDirectory: true
      )
      .standardizedFileURL
    }

    return FileManager.default
      .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appending(path: "LitePaste", directoryHint: .isDirectory)
  }

  public static var historyURL: URL {
    applicationSupportDirectory.appending(path: "history.json")
  }

  public static var sqliteHistoryURL: URL {
    applicationSupportDirectory.appending(path: "history.sqlite3")
  }

  public static var settingsURL: URL {
    applicationSupportDirectory.appending(path: "settings.json")
  }

  public static var blobsDirectory: URL {
    applicationSupportDirectory.appending(path: "Blobs", directoryHint: .isDirectory)
  }

  public static func ensureApplicationSupportDirectoryExists() throws {
    try storagePaths.ensureApplicationSupportDirectoryExists()
  }

  public static func ensureBlobsDirectoryExists() throws {
    try storagePaths.ensureBlobsDirectoryExists()
  }
}
