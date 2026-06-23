import Foundation
import LitePasteCore

func checkJSONHistoryRepository() {
  do {
    try withTemporaryDirectory(prefix: "LitePasteCoreChecks") { directory in
      let url = directory.appending(path: "history.json")

      let repository = JSONClipboardHistoryRepository(url: url)
      let record = ClipboardRecord(
        kind: .text,
        title: "persisted",
        searchText: "persisted",
        contentHash: "hash",
        plainText: "persisted"
      )

      try repository.save([record])
      let loaded = try repository.load()

      expect(loaded.count == 1, "JSON repository should load saved records")
      expect(loaded.first?.title == "persisted", "JSON repository should preserve record fields")

      let legacyData = Data(
        """
        [
          {
            "id": "00000000-0000-0000-0000-000000000121",
            "kind": "text",
            "title": "legacy",
            "searchText": "legacy",
            "createdAt": "2026-05-22T09:31:52Z",
            "lastCopiedAt": "2026-05-22T09:46:58Z",
            "copyCount": 2,
            "isFavorite": true,
            "isPinned": false,
            "contentHash": "legacy-hash",
            "plainText": "legacy"
          }
        ]
        """.utf8
      )
      try legacyData.write(to: url, options: .atomic)
      let legacyRecords = try repository.load()
      expect(
        legacyRecords.first?.contents.isEmpty == true,
        "JSON repository should default missing legacy contents")
      expect(
        legacyRecords.first?.previewFilePath == nil,
        "JSON repository should default missing legacy preview path")
    }
  } catch {
    fatalError("JSON repository check failed: \(error)")
  }
}
