import Foundation
import LitePasteCore

func checkContentHasher() {
  let first = ContentHasher.hash(kind: .text, text: "hello")
  let second = ContentHasher.hash(kind: .text, text: "  hello\n")
  expect(first == second, "ContentHasher should normalize outer whitespace")

  let richHash = ContentHasher.hash(
    kind: .html,
    typedData: [
      (pasteboardType: "public.html", data: Data("<b>1</b>".utf8)),
      (pasteboardType: "com.microsoft.Excel", data: Data("formula".utf8))
    ]
  )
  let changedRichHash = ContentHasher.hash(
    kind: .html,
    typedData: [
      (pasteboardType: "public.html", data: Data("<b>1</b>".utf8)),
      (pasteboardType: "com.microsoft.Excel", data: Data("other formula".utf8))
    ]
  )
  expect(richHash != changedRichHash, "ContentHasher should include typed pasteboard data")
}

func checkClipboardMonitoringPolicy() {
  let pausedPolicy = ClipboardMonitoringPolicy(isMonitoringPaused: true)
  expect(
    !pausedPolicy.shouldRecord(),
    "Paused monitoring should stop recording"
  )

  let normalPolicy = ClipboardMonitoringPolicy()
  expect(
    normalPolicy.shouldRecord(),
    "Monitoring should record while it is not paused"
  )
}

func checkClipboardTextPayloadBuilder() {
  let builder = ClipboardTextPayloadBuilder()

  expect(
    builder.payload(from: " \n\t ", pasteboardTypes: ["public.utf8-plain-text"]) == nil,
    "Text payload builder should ignore blank text"
  )
  expect(builder.classify("https://example.com/docs") == .url, "Text payload builder should classify HTTPS URLs")
  expect(builder.classify("file:///tmp/report.pdf") == .url, "Text payload builder should classify file URLs")
  expect(builder.classify("raycast://extensions") == .url, "Text payload builder should classify custom URL schemes")
  expect(builder.classify("example.com/docs") == .url, "Text payload builder should classify bare domains")
  expect(builder.classify("www.example.com?q=1") == .url, "Text payload builder should classify www bare domains")
  expect(builder.classify("hello@example.com") == .email, "Text payload builder should classify email addresses")
  expect(builder.classify("#FF00AA") == .color, "Text payload builder should classify hex colors")
  expect(builder.classify("release notes v1.2") == .text, "Text payload builder should not classify dotted prose as URLs")

  let longText = String(repeating: "a", count: ClipboardTextPayloadBuilder.maxTitleLength + 20)
  expect(
    builder.makeTitle(from: "hello\n\tworld") == "hello  world",
    "Text payload builder should compact multiline titles"
  )
  expect(
    builder.makeTitle(from: longText).count == ClipboardTextPayloadBuilder.maxTitleLength,
    "Text payload builder should cap long titles"
  )

  guard let payload = builder.payload(from: " hello@example.com ", pasteboardTypes: ["public.utf8-plain-text"]) else {
    fatalError("Text payload builder should create payload for non-empty text")
  }

  expect(payload.kind == .email, "Text payload should use classified kind")
  expect(payload.title == "hello@example.com", "Text payload should use compact title")
  expect(payload.searchText == " hello@example.com ", "Text payload should preserve original search text")
  expect(payload.plainText == " hello@example.com ", "Text payload should preserve original plain text")
  expect(payload.contentHashBasis == " hello@example.com ", "Text payload should hash from original text")
  expect(payload.contents.count == 1, "Text payload should include one inline snapshot")
  expect(
    payload.contents.first?.pasteboardType == ClipboardTextPayloadBuilder.plainTextPasteboardType,
    "Text payload should use the plain text pasteboard type"
  )
  expect(
    payload.contents.first?.inlineData == Data(" hello@example.com ".utf8),
    "Text payload snapshot should preserve UTF-8 text data"
  )

  let hugeText = String(repeating: "表格内容", count: ClipboardTextPayloadBuilder.maxSearchTextLength)
  guard let hugePayload = builder.payload(from: hugeText, pasteboardTypes: ["public.utf8-plain-text"]) else {
    fatalError("Text payload builder should create payload for huge text")
  }
  expect(
    hugePayload.searchText.count == ClipboardTextPayloadBuilder.maxSearchTextLength,
    "Text payload should cap huge search text"
  )
  expect(hugePayload.plainText == hugeText, "Text payload should preserve huge plain text for paste")
}

func checkClipboardFilePayloadBuilder() {
  let builder = ClipboardFilePayloadBuilder()

  expect(
    builder.payload(from: [], pasteboardTypes: ["public.file-url"]) == nil,
    "File payload builder should ignore empty file lists"
  )
  expect(
    builder.payload(from: [URL(string: "https://example.com/file.txt")!], pasteboardTypes: ["public.url"]) == nil,
    "File payload builder should ignore non-file URLs"
  )

  let singleURL = URL(fileURLWithPath: "/Users/example/Desktop/report.pdf")
  guard let singlePayload = builder.payload(from: [singleURL], pasteboardTypes: ["public.file-url"]) else {
    fatalError("File payload builder should create a single-file payload")
  }

  expect(singlePayload.kind == .files, "File payload should use files kind")
  expect(singlePayload.title == "report.pdf", "File payload should use single file name as title")
  expect(singlePayload.searchText == singleURL.path, "File payload should search by full file path")
  expect(singlePayload.plainText == singleURL.path, "File payload should preserve paths as plain text")
  expect(singlePayload.contentHashBasis == singleURL.path, "File payload should hash from ordered paths")
  expect(singlePayload.contents.count == 1, "Single-file payload should include one snapshot")
  expect(
    singlePayload.contents.first?.pasteboardType == ClipboardFilePayloadBuilder.fileURLPasteboardType,
    "File payload should use the file URL pasteboard type"
  )
  expect(
    singlePayload.contents.first?.inlineData == Data(singleURL.path.utf8),
    "File payload snapshot should store the file path"
  )

  let fileURLs = [
    URL(fileURLWithPath: "/tmp/a.txt"),
    URL(fileURLWithPath: "/tmp/b.txt"),
    URL(fileURLWithPath: "/tmp/c.txt"),
    URL(fileURLWithPath: "/tmp/d.txt")
  ]
  guard let multiPayload = builder.payload(from: fileURLs, pasteboardTypes: ["public.file-url"]) else {
    fatalError("File payload builder should create a multi-file payload")
  }

  expect(
    multiPayload.title == "4 个文件: a.txt, b.txt, c.txt",
    "File payload should summarize multi-file titles"
  )
  expect(
    multiPayload.plainText == fileURLs.map(\.path).joined(separator: "\n"),
    "File payload should preserve file URL order in plain text"
  )
  expect(
    multiPayload.contents.map(\.displayOrder) == [0, 1, 2, 3],
    "File payload snapshots should preserve display order"
  )
  expect(
    multiPayload.contents.compactMap { $0.inlineData.flatMap { String(data: $0, encoding: .utf8) } } == fileURLs.map(\.path),
    "File payload snapshots should preserve ordered paths"
  )
}
