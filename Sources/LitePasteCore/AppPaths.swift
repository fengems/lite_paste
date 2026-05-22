import Foundation

public enum AppPaths {
  public static var applicationSupportDirectory: URL {
    FileManager.default
      .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appending(path: "LitePaste", directoryHint: .isDirectory)
  }

  public static var historyURL: URL {
    applicationSupportDirectory.appending(path: "history.json")
  }

  public static var settingsURL: URL {
    applicationSupportDirectory.appending(path: "settings.json")
  }

  public static func ensureApplicationSupportDirectoryExists() throws {
    try FileManager.default.createDirectory(
      at: applicationSupportDirectory,
      withIntermediateDirectories: true
    )
  }
}

