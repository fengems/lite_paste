import Foundation

enum BackupBlobMapper {
  static func uniqueDestinationURL(for sourceURL: URL, preferredDestinationURL: URL) -> URL {
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
}
