import Foundation
import LitePasteCore

func checkSQLiteHistoryRepository() {
  do {
    try withTemporaryDirectory(prefix: "LitePasteSQLiteChecks") { directory in
      let url = directory.appending(path: "history.sqlite3")

      let repository = SQLiteClipboardHistoryRepository(url: url)
      let first = ClipboardRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        kind: .image,
        title: "first",
        searchText: "first image",
        note: "note",
        sourceAppBundleId: "com.example.Source",
        sourceAppName: "Source",
        createdAt: Date(timeIntervalSince1970: 1),
        lastCopiedAt: Date(timeIntervalSince1970: 2),
        lastUsedAt: Date(timeIntervalSince1970: 3),
        copyCount: 4,
        isFavorite: true,
        isPinned: true,
        pinShortcut: "command+option+1",
        contentHash: "hash-1",
        plainText: nil,
        ocrText: "recognized first image",
        contents: [
          ClipboardContentSnapshot(
            pasteboardType: "public.png",
            storageMode: .external,
            externalFilePath: "/tmp/image.png",
            byteSize: 42,
            displayOrder: 0
          )
        ],
        previewFilePath: "/tmp/preview.png"
      )
      let second = ClipboardRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        kind: .text,
        title: "second",
        searchText: "second text",
        createdAt: Date(timeIntervalSince1970: 4),
        lastCopiedAt: Date(timeIntervalSince1970: 5),
        copyCount: 1,
        contentHash: "hash-2",
        plainText: "second"
      )

      try repository.save([first, second])
      let loaded = try repository.load()

      expect(
        loaded == [first, second], "SQLite repository should round-trip records in saved order")
      let ocrSearchResults = try repository.execute(
        ClipboardHistoryQuery(text: "recognized"), limit: nil, offset: 0)
      expect(
        ocrSearchResults.first?.id == first.id,
        "SQLite repository should search OCR text"
      )

      try repository.save([second])
      let overwritten = try repository.load()

      expect(
        overwritten == [second], "SQLite repository save should replace previous history snapshot")
    }
  } catch {
    fatalError("SQLite repository check failed: \(error)")
  }
}

func checkSQLiteHistoryQueryAndMaintenance() {
  do {
    try withTemporaryDirectory(prefix: "LitePasteSQLiteQueryChecks") { directory in
      let url = directory.appending(path: "history.sqlite3")

      let repository = SQLiteClipboardHistoryRepository(url: url)
      let engine = ClipboardHistoryQueryEngine()
      let records = [
        ClipboardRecord(
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
          kind: .text,
          title: "old memo",
          searchText: "alpha body",
          note: "saved memo",
          sourceAppBundleId: "com.example.Old",
          sourceAppName: "OldApp",
          createdAt: Date(timeIntervalSince1970: 10),
          lastCopiedAt: Date(timeIntervalSince1970: 10),
          copyCount: 1,
          contentHash: "query-old"
        ),
        ClipboardRecord(
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
          kind: .image,
          title: "screenshot",
          searchText: "canvas",
          sourceAppBundleId: "com.example.Image",
          sourceAppName: "ImageApp",
          createdAt: Date(timeIntervalSince1970: 11),
          lastCopiedAt: Date(timeIntervalSince1970: 11),
          copyCount: 2,
          isPinned: true,
          contentHash: "query-image"
        ),
        ClipboardRecord(
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!,
          kind: .files,
          title: "report.pdf",
          searchText: "project source",
          sourceAppBundleId: "com.example.Files",
          sourceAppName: "Finder",
          createdAt: Date(timeIntervalSince1970: 12),
          lastCopiedAt: Date(timeIntervalSince1970: 12),
          copyCount: 9,
          isFavorite: true,
          contentHash: "query-files"
        ),
        ClipboardRecord(
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000104")!,
          kind: .url,
          title: "100%_literal",
          searchText: "https://example.com",
          createdAt: Date(timeIntervalSince1970: 13),
          lastCopiedAt: Date(timeIntervalSince1970: 13),
          copyCount: 3,
          contentHash: "query-url",
          plainText: "https://example.com"
        ),
        ClipboardRecord(
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000105")!,
          kind: .color,
          title: "#22C55E",
          searchText: "#22C55E RGB(34, 197, 94)",
          createdAt: Date(timeIntervalSince1970: 9),
          lastCopiedAt: Date(timeIntervalSince1970: 9),
          copyCount: 1,
          contentHash: "query-color",
          plainText: "#22C55E"
        ),
      ]

      try repository.save(records)

      let queries = [
        ClipboardHistoryQuery(),
        ClipboardHistoryQuery(text: "memo OldApp"),
        ClipboardHistoryQuery(text: "图片"),
        ClipboardHistoryQuery(text: "100%_literal"),
        ClipboardHistoryQuery(filter: .files),
        ClipboardHistoryQuery(filter: .text),
        ClipboardHistoryQuery(filter: .links),
        ClipboardHistoryQuery(filter: .colors),
        ClipboardHistoryQuery(filter: .favorites, sort: .mostUsed),
        ClipboardHistoryQuery(sort: .mostUsed),
      ]

      for query in queries {
        let expected = engine.execute(query, records: records).map(\.id)
        let actual = try repository.execute(query).map(\.id)
        expect(actual == expected, "SQLite query should match in-memory query engine for \(query)")
      }

      let limited = try repository.execute(ClipboardHistoryQuery(sort: .recent), limit: 2)
      expect(
        limited.map(\.id) == [records[3].id, records[2].id],
        "SQLite query should apply limits after sorting")

      let lookedUp = try repository.record(id: records[2].id)
      expect(lookedUp?.id == records[2].id, "SQLite repository should look up records by id")
      let hashLookup = try repository.record(contentHash: records[2].contentHash)
      expect(
        hashLookup?.id == records[2].id, "SQLite repository should look up records by content hash")
      let missingRecord = try repository.record(id: UUID())
      expect(missingRecord == nil, "SQLite repository should return nil for missing ids")

      let offset = try repository.execute(ClipboardHistoryQuery(sort: .recent), limit: 2, offset: 1)
      expect(
        offset.map(\.id) == [records[2].id, records[1].id],
        "SQLite query should apply offsets after sorting")

      let favoriteCount = try repository.count(ClipboardHistoryQuery(filter: .favorites))
      expect(favoriteCount == 1, "SQLite query should count filtered records")

      var updated = records[1]
      updated.note = "incremental note"
      updated.copyCount = 12
      try repository.upsert(updated, position: nil)
      let incrementallyUpdated = try repository.record(id: updated.id)
      let idsAfterUpdate = try repository.load().map(\.id)
      expect(
        incrementallyUpdated == updated,
        "SQLite repository should update existing records incrementally")
      expect(
        idsAfterUpdate == records.map(\.id),
        "SQLite repository should preserve position when upserting existing records")

      let appended = ClipboardRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000105")!,
        kind: .text,
        title: "appended",
        searchText: "appended",
        createdAt: Date(timeIntervalSince1970: 14),
        lastCopiedAt: Date(timeIntervalSince1970: 14),
        contentHash: "query-appended",
        plainText: "appended"
      )
      try repository.upsert(appended, position: nil)
      let idsAfterAppend = try repository.load().map(\.id)
      expect(
        idsAfterAppend.last == appended.id, "SQLite repository should append new upserted records")
      try repository.delete(id: appended.id)
      let deletedRecord = try repository.record(id: appended.id)
      expect(deletedRecord == nil, "SQLite repository should delete records incrementally")
      try repository.upsert(appended, position: 0)
      let idsAfterPositionedUpsert = try repository.load().map(\.id)
      expect(
        idsAfterPositionedUpsert.first == appended.id,
        "SQLite repository should honor explicit upsert positions")
      try repository.deleteAll()
      let recordsAfterDeleteAll = try repository.load()
      expect(
        recordsAfterDeleteAll.isEmpty, "SQLite repository should delete all records incrementally")
      try repository.save(records)

      try repository.performMaintenance()
      let recordsAfterMaintenance = try repository.load()
      expect(recordsAfterMaintenance == records, "SQLite maintenance should preserve saved history")
    }
  } catch {
    fatalError("SQLite query check failed: \(error)")
  }
}
