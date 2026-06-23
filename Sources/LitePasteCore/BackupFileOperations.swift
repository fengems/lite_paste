import Foundation

enum BackupFileOperations {
  static func copyFileIfExists(from source: URL, to destination: URL) throws {
    guard FileManager.default.fileExists(atPath: source.path) else {
      return
    }

    try replaceFileIfExists(from: source, to: destination)
  }

  static func replaceFileIfExists(from source: URL, to destination: URL) throws {
    guard FileManager.default.fileExists(atPath: source.path) else {
      return
    }

    try removeIfExists(destination)
    try FileManager.default.copyItem(at: source, to: destination)
  }

  static func copyDirectoryIfExists(from source: URL, to destination: URL) throws {
    guard FileManager.default.fileExists(atPath: source.path) else {
      return
    }

    try replaceDirectoryIfExists(from: source, to: destination)
  }

  static func replaceDirectoryIfExists(from source: URL, to destination: URL) throws {
    guard FileManager.default.fileExists(atPath: source.path) else {
      return
    }

    try removeIfExists(destination)
    try FileManager.default.copyItem(at: source, to: destination)
  }

  static func removeIfExists(_ url: URL) throws {
    if FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.removeItem(at: url)
    }
  }
}
