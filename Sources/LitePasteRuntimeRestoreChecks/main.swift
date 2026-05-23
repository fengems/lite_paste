import AppKit
import Foundation
import LitePasteCore

@MainActor
func main() {
  let arguments = CommandLine.arguments
  guard arguments.count == 9 else {
    fatalError(
      "Usage: LitePasteRuntimeRestoreChecks DATA_DIR TEXT URL EMAIL COLOR FILE HTML RTF"
    )
  }

  let dataDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
  let expectedText = arguments[2]
  let expectedURL = arguments[3]
  let expectedEmail = arguments[4]
  let expectedColor = arguments[5]
  let expectedFilePath = arguments[6]
  let expectedHTMLPlainText = arguments[7]
  let expectedRTFPlainText = arguments[8]

  do {
    let repository = SQLiteClipboardHistoryRepository(
      url: dataDirectory.appending(path: "history.sqlite3")
    )
    let records = try repository.load()
    let checker = RuntimeRestoreChecker(records: records)

    checker.expectStringRestore(kind: .text, plainText: expectedText)
    checker.expectStringRestore(kind: .url, plainText: expectedURL)
    checker.expectStringRestore(kind: .email, plainText: expectedEmail)
    checker.expectStringRestore(kind: .color, plainText: expectedColor)
    checker.expectFileRestore(path: expectedFilePath)
    checker.expectImageRestore()
    checker.expectRichRestore(kind: .html, plainText: expectedHTMLPlainText, pasteboardType: .html)
    checker.expectRichRestore(kind: .richText, plainText: expectedRTFPlainText, pasteboardType: .rtf)

    print("LitePasteRuntimeRestoreChecks passed")
  } catch {
    fatalError("Runtime restore checks failed: \(error)")
  }
}

@MainActor
private final class RuntimeRestoreChecker {
  private let records: [ClipboardRecord]
  private let planner = PasteboardRestorePlanner()
  private let pasteboard = NSPasteboard.general

  init(records: [ClipboardRecord]) {
    self.records = records
  }

  func expectStringRestore(kind: ClipboardKind, plainText: String) {
    let record = requireRecord(kind: kind, plainText: plainText)
    apply(record)
    expect(
      pasteboard.string(forType: .string) == plainText,
      "Expected \(kind.rawValue) restore to preserve plain text"
    )
  }

  func expectFileRestore(path: String) {
    let record = requireRecord(kind: .files, plainText: path)
    apply(record)

    let urls = pasteboard.readObjects(
      forClasses: [NSURL.self],
      options: [.urlReadingFileURLsOnly: true]
    )
    let paths = ((urls as? [URL]) ?? (urls as? [NSURL])?.map { $0 as URL } ?? []).map(\.path)

    expect(paths == [path], "Expected file restore to preserve file URL")
  }

  func expectImageRestore() {
    let record = requireRecord(kind: .image)
    apply(record)

    let hasImageData = pasteboard.data(forType: .png) != nil || pasteboard.data(forType: .tiff) != nil
    expect(hasImageData, "Expected image restore to write image pasteboard data")
    expect(NSImage(pasteboard: pasteboard) != nil, "Expected image restore to be readable as NSImage")
  }

  func expectRichRestore(kind: ClipboardKind, plainText: String, pasteboardType: NSPasteboard.PasteboardType) {
    let record = requireRecord(kind: kind, plainText: plainText)
    apply(record)

    expect(
      pasteboard.data(forType: pasteboardType) != nil,
      "Expected \(kind.rawValue) restore to preserve rich pasteboard data"
    )
    expect(
      pasteboard.string(forType: .string) == plainText,
      "Expected \(kind.rawValue) restore to preserve plain text fallback"
    )
  }

  private func requireRecord(kind: ClipboardKind, plainText: String? = nil) -> ClipboardRecord {
    guard let record = records.first(where: { record in
      record.kind == kind && (plainText == nil || record.plainText == plainText)
    }) else {
      fatalError("Missing captured \(kind.rawValue) record")
    }

    return record
  }

  private func apply(_ record: ClipboardRecord) {
    guard let plan = planner.plan(for: record) else {
      fatalError("Missing restore plan for \(record.kind.rawValue) record")
    }

    pasteboard.clearContents()

    let restored: Bool
    switch plan {
    case let .fileURLs(urls):
      restored = pasteboard.writeObjects(urls as [NSURL])
    case let .items(items):
      restored = items.allSatisfy { item in
        pasteboard.setData(
          item.data,
          forType: NSPasteboard.PasteboardType(item.pasteboardType)
        )
      }
    case let .plainText(text):
      restored = pasteboard.setString(text, forType: .string)
    }

    expect(restored, "Expected pasteboard restore to succeed")
  }

  private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
      fatalError(message)
    }
  }
}

await MainActor.run {
  main()
}
