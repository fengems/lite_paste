import Foundation
import LitePasteCore

func checkPasteboardRestorePlanner() {
  let externalData = Data("external image".utf8)
  let planner = PasteboardRestorePlanner { path in
    path == "/tmp/image.png" ? externalData : nil
  }

  let textRecord = ClipboardRecord(
    kind: .text,
    title: "hello",
    searchText: "hello",
    contentHash: "text",
    plainText: "hello",
    contents: [
      ClipboardContentSnapshot(
        pasteboardType: PasteboardRestorePlanner.plainTextPasteboardType,
        storageMode: .inline,
        inlineData: Data("hello".utf8),
        byteSize: 5,
        displayOrder: 0
      )
    ]
  )

  expect(
    planner.plan(for: textRecord, asPlainText: true) == .plainText("hello"),
    "Restore planner should force plain text when requested"
  )

  let fileRecord = ClipboardRecord(
    kind: .files,
    title: "files",
    searchText: "/tmp/a.txt\n/tmp/b.txt",
    contentHash: "files",
    plainText: "/tmp/a.txt\n/tmp/b.txt",
    contents: [
      ClipboardContentSnapshot(
        pasteboardType: "public.file-url",
        storageMode: .inline,
        inlineData: Data("/tmp/a.txt".utf8),
        byteSize: 10,
        displayOrder: 1
      ),
      ClipboardContentSnapshot(
        pasteboardType: "public.file-url",
        storageMode: .inline,
        inlineData: Data("/tmp/b.txt".utf8),
        byteSize: 10,
        displayOrder: 0
      )
    ]
  )

  if case let .fileURLs(urls)? = planner.plan(for: fileRecord) {
    expect(urls.map(\.path) == ["/tmp/b.txt", "/tmp/a.txt"], "Restore planner should restore file URLs in display order")
  } else {
    fatalError("Restore planner should create a file URL plan")
  }

  let legacyFileRecord = ClipboardRecord(
    kind: .files,
    title: "legacy files",
    searchText: "/tmp/legacy.txt",
    contentHash: "legacy-files",
    plainText: "/tmp/legacy.txt"
  )

  if case let .fileURLs(urls)? = planner.plan(for: legacyFileRecord) {
    expect(urls.map(\.path) == ["/tmp/legacy.txt"], "Restore planner should restore legacy file records from plain text")
  } else {
    fatalError("Restore planner should create a file URL plan for legacy file records")
  }

  let imageRecord = ClipboardRecord(
    kind: .image,
    title: "image",
    searchText: "image",
    contentHash: "image",
    contents: [
      ClipboardContentSnapshot(
        pasteboardType: "public.png",
        storageMode: .external,
        externalFilePath: "/tmp/image.png",
        byteSize: externalData.count,
        displayOrder: 0
      )
    ]
  )

  if case let .items(items)? = planner.plan(for: imageRecord) {
    expect(items == [PasteboardRestoreItem(pasteboardType: "public.png", data: externalData)], "Restore planner should read external blob data")
  } else {
    fatalError("Restore planner should create an item plan for external data")
  }

  let imageTextRecord = ClipboardRecord(
    kind: .image,
    title: "image text",
    searchText: "image",
    contentHash: "image-text",
    plainText: "  ",
    ocrText: "Recognized image text",
    contents: [
      ClipboardContentSnapshot(
        pasteboardType: "public.png",
        storageMode: .external,
        externalFilePath: "/tmp/image.png",
        byteSize: externalData.count,
        displayOrder: 0
      )
    ]
  )
  expect(
    planner.plan(for: imageTextRecord, asPlainText: true) == .plainText("Recognized image text"),
    "Restore planner should use OCR text for explicit image plain-text restore"
  )

  let richRecord = ClipboardRecord(
    kind: .html,
    title: "HTML",
    searchText: "Hello",
    contentHash: "html",
    plainText: "Hello",
    contents: [
      ClipboardContentSnapshot(
        pasteboardType: "public.html",
        storageMode: .inline,
        inlineData: Data("<b>Hello</b>".utf8),
        byteSize: 12,
        displayOrder: 0
      )
    ]
  )

  if case let .items(items)? = planner.plan(for: richRecord) {
    expect(items.map(\.pasteboardType) == ["public.html", PasteboardRestorePlanner.plainTextPasteboardType], "Restore planner should append plain text fallback for rich content")
  } else {
    fatalError("Restore planner should create an item plan for rich content")
  }

  let highFidelityRichRecord = ClipboardRecord(
    kind: .html,
    title: "Excel",
    searchText: "1",
    contentHash: "excel-html",
    plainText: "1",
    contents: [
      ClipboardContentSnapshot(
        pasteboardType: "com.microsoft.Excel",
        storageMode: .inline,
        inlineData: Data("formula".utf8),
        byteSize: 7,
        displayOrder: 0
      ),
      ClipboardContentSnapshot(
        pasteboardType: "public.html",
        storageMode: .inline,
        inlineData: Data("<b>1</b>".utf8),
        byteSize: 8,
        displayOrder: 1
      )
    ]
  )

  if case let .items(items)? = planner.plan(for: highFidelityRichRecord) {
    expect(
      items.map(\.pasteboardType) == [
        "com.microsoft.Excel",
        "public.html",
        PasteboardRestorePlanner.plainTextPasteboardType
      ],
      "Restore planner should keep private rich pasteboard types before plain fallback"
    )
  } else {
    fatalError("Restore planner should create an item plan for high-fidelity rich content")
  }

  let missingRichRecord = ClipboardRecord(
    kind: .html,
    title: "Missing HTML",
    searchText: "Hello",
    contentHash: "missing-html",
    plainText: "Hello",
    contents: [
      ClipboardContentSnapshot(
        pasteboardType: "public.html",
        storageMode: .external,
        externalFilePath: "/tmp/missing.html",
        byteSize: 12,
        displayOrder: 0
      )
    ]
  )

  expect(
    planner.plan(for: missingRichRecord) == nil,
    "Restore planner should fail default restore when rich external content is missing"
  )
  expect(
    planner.plan(for: missingRichRecord, asPlainText: true) == .plainText("Hello"),
    "Restore planner should still allow explicit plain-text restore for missing rich content"
  )

  let missingRecord = ClipboardRecord(
    kind: .image,
    title: "missing",
    searchText: "missing",
    contentHash: "missing",
    contents: [
      ClipboardContentSnapshot(
        pasteboardType: "public.png",
        storageMode: .external,
        externalFilePath: "/tmp/missing.png",
        byteSize: 0,
        displayOrder: 0
      )
    ]
  )

  expect(planner.plan(for: missingRecord) == nil, "Restore planner should fail when no restorable content exists")
}
