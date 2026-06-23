import AppKit
import Foundation

extension ClipboardPasteboardReader {
  func readFileURLs() -> [URL] {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [
      .urlReadingFileURLsOnly: true
    ]
    let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options)
    let urls = (objects as? [URL]) ?? (objects as? [NSURL])?.map { $0 as URL } ?? []
    return urls.filter { $0.isFileURL }
  }
}
