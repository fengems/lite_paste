import Foundation

extension ICloudBackupService {
  func requestDownloadIfNeeded(for url: URL) throws {
    let deadline = Date().addingTimeInterval(20)
    let fileManager = FileManager.default
    while true {
      let pendingURLs = try requestPendingDownloads(in: url, fileManager: fileManager)
      guard !pendingURLs.contains(where: { isNotDownloaded($0) }) else {
        guard Date() < deadline else {
          return
        }

        Thread.sleep(forTimeInterval: 0.2)
        continue
      }

      return
    }
  }

  private func requestPendingDownloads(in url: URL, fileManager: FileManager) throws -> [URL] {
    var urls = [url]

    guard let enumerator = fileManager.enumerator(
      at: url,
      includingPropertiesForKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey],
      options: [.skipsHiddenFiles]
    ) else {
      return urls
    }

    for case let childURL as URL in enumerator {
      urls.append(childURL)
    }

    for itemURL in urls where fileManager.isUbiquitousItem(at: itemURL) && isNotDownloaded(itemURL) {
      try? fileManager.startDownloadingUbiquitousItem(at: itemURL)
    }

    return urls
  }

  private func isNotDownloaded(_ url: URL) -> Bool {
    let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
    return values?.ubiquitousItemDownloadingStatus == .notDownloaded
  }
}
