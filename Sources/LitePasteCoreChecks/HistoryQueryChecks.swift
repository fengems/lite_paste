import Foundation
import LitePasteCore

func checkHistoryQueryEngine() {
  let engine = ClipboardHistoryQueryEngine()
  let old = ClipboardRecord(
    kind: .text,
    title: "old",
    searchText: "alpha",
    note: "memo",
    sourceAppBundleId: "com.example.Old",
    sourceAppName: "OldApp",
    lastCopiedAt: Date(timeIntervalSince1970: 10),
    copyCount: 1,
    contentHash: "old"
  )
  let pinned = ClipboardRecord(
    kind: .image,
    title: "image",
    searchText: "screenshot",
    note: "",
    sourceAppBundleId: "com.example.Image",
    sourceAppName: "ImageApp",
    lastCopiedAt: Date(timeIntervalSince1970: 1),
    copyCount: 2,
    isPinned: true,
    contentHash: "image"
  )
  let popular = ClipboardRecord(
    kind: .files,
    title: "files",
    searchText: "report.pdf",
    note: "",
    sourceAppBundleId: "com.example.Files",
    sourceAppName: "Finder",
    lastCopiedAt: Date(timeIntervalSince1970: 20),
    copyCount: 9,
    contentHash: "files"
  )
  let link = ClipboardRecord(
    kind: .url,
    title: "link",
    searchText: "https://example.com",
    lastCopiedAt: Date(timeIntervalSince1970: 3),
    contentHash: "link"
  )
  let color = ClipboardRecord(
    kind: .color,
    title: "#22C55E",
    searchText: "#22C55E",
    lastCopiedAt: Date(timeIntervalSince1970: 4),
    contentHash: "color"
  )
  let records = [old, pinned, popular, link, color]

  let defaultResults = engine.execute(ClipboardHistoryQuery(), records: records)
  expect(defaultResults.first?.id == pinned.id, "Pinned records should sort before recent records")

  let noteResults = engine.execute(ClipboardHistoryQuery(text: "memo"), records: records)
  expect(noteResults.count == 1 && noteResults.first?.id == old.id, "Query should match notes")

  let multiTermResults = engine.execute(ClipboardHistoryQuery(text: "memo OldApp"), records: records)
  expect(multiTermResults.count == 1 && multiTermResults.first?.id == old.id, "Query should match multiple terms across fields")

  let fileResults = engine.execute(ClipboardHistoryQuery(filter: .files), records: records)
  expect(fileResults.count == 1 && fileResults.first?.id == popular.id, "Filter should match files")

  let linkResults = engine.execute(ClipboardHistoryQuery(filter: .links), records: records)
  expect(linkResults.count == 1 && linkResults.first?.id == link.id, "Filter should match links")

  let colorResults = engine.execute(ClipboardHistoryQuery(filter: .colors), records: records)
  expect(colorResults.count == 1 && colorResults.first?.id == color.id, "Filter should match colors")

  let popularResults = engine.execute(
    ClipboardHistoryQuery(sort: .mostUsed),
    records: records
  )
  expect(popularResults.first?.id == popular.id, "Most-used sort should sort by copy count")
}

func checkHistoryQueryPerformance() {
  let engine = ClipboardHistoryQueryEngine()
  let records = (0..<5_000).map { index in
    ClipboardRecord(
      kind: index.isMultiple(of: 7) ? .files : .text,
      title: index.isMultiple(of: 250) ? "needle document \(index)" : "document \(index)",
      searchText: "body \(index) project-\(index % 40)",
      note: index.isMultiple(of: 333) ? "important needle" : "",
      sourceAppBundleId: "com.example.App\(index % 12)",
      sourceAppName: "Source \(index % 12)",
      lastCopiedAt: Date(timeIntervalSince1970: TimeInterval(index)),
      copyCount: index % 20,
      isFavorite: index.isMultiple(of: 20),
      isPinned: index.isMultiple(of: 400),
      contentHash: "hash-\(index)"
    )
  }

  let start = DispatchTime.now().uptimeNanoseconds
  let searchResults = engine.execute(
    ClipboardHistoryQuery(text: "needle source", filter: .all, sort: .pinnedThenRecent),
    records: records
  )
  let favoriteResults = engine.execute(
    ClipboardHistoryQuery(text: "project-2", filter: .favorites, sort: .mostUsed),
    records: records
  )
  let elapsedMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000

  expect(!searchResults.isEmpty, "Large history search should find matching records")
  expect(
    favoriteResults.allSatisfy(\.isFavorite),
    "Large history filtered search should preserve favorite filter"
  )
  expect(
    elapsedMilliseconds < 1_500,
    "Large history query should stay responsive for 5,000 records"
  )
}
