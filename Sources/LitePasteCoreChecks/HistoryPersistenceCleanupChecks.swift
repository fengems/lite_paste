import Foundation
import LitePasteCore

@MainActor
func checkHistoryPersistenceCleanup() {
  let now = Date()

  do {
    try withTemporaryDirectory(prefix: "LitePastePersistenceCleanup") { directory in
      let historyURL = directory.appending(path: "history.json")
      let blobsDirectory = directory.appending(path: "Blobs", directoryHint: .isDirectory)
      let repository = JSONClipboardHistoryRepository(url: historyURL)
      let storage = LocalBlobStorage(directory: blobsDirectory)

      let expiredPayload = try externalBlobPayload(
        title: "expired",
        contentHashBasis: "expired",
        data: Data("expired".utf8),
        storage: storage
      )
      let pinnedPayload = try externalBlobPayload(
        title: "pinned old",
        contentHashBasis: "pinned-old",
        data: Data("pinned old".utf8),
        storage: storage
      )
      let recentPayload = try externalBlobPayload(
        title: "recent",
        contentHashBasis: "recent",
        data: Data("recent".utf8),
        storage: storage
      )
      let newestPayload = try externalBlobPayload(
        title: "newest",
        contentHashBasis: "newest",
        data: Data("newest".utf8),
        storage: storage
      )

      let expiredPath = expiredPayload.contents[0].externalFilePath ?? ""
      let pinnedPath = pinnedPayload.contents[0].externalFilePath ?? ""
      let recentPath = recentPayload.contents[0].externalFilePath ?? ""
      let newestPath = newestPayload.contents[0].externalFilePath ?? ""

      let expired = record(
        from: expiredPayload,
        lastCopiedAt: now.addingTimeInterval(-5 * 86_400)
      )
      let pinned = record(
        from: pinnedPayload,
        lastCopiedAt: now.addingTimeInterval(-5 * 86_400),
        isPinned: true,
        pinShortcut: "command+option+1"
      )
      let recent = record(
        from: recentPayload,
        lastCopiedAt: now.addingTimeInterval(-100)
      )
      let newest = record(
        from: newestPayload,
        lastCopiedAt: now
      )

      try repository.save([expired, pinned, recent, newest])

      let store = HistoryStore(
        repository: repository,
        blobStorage: storage,
        maxHistoryCount: 2,
        retentionDays: 2
      )

      let retainedTitles = Set(store.records.map(\.title))
      expect(
        retainedTitles == ["pinned old", "newest"],
        "HistoryStore should trim loaded persistent history by retention and max count")
      expect(
        store.records.first?.isPinned == true,
        "Loaded pinned records should remain sorted before regular records")
      expect(
        !FileManager.default.fileExists(atPath: expiredPath),
        "Loading persistent history should remove expired blobs")
      expect(
        !FileManager.default.fileExists(atPath: recentPath),
        "Loading persistent history should remove overflow blobs")
      expect(
        FileManager.default.fileExists(atPath: pinnedPath),
        "Loading persistent history should keep pinned blobs")
      expect(
        FileManager.default.fileExists(atPath: newestPath),
        "Loading persistent history should keep retained blobs")

      let persistedAfterTrim = try repository.load()
      expect(
        Set(persistedAfterTrim.map(\.title)) == ["pinned old", "newest"],
        "HistoryStore should persist cleanup results back to JSON"
      )

      let importedPayload = try externalBlobPayload(
        title: "imported",
        contentHashBasis: "imported",
        data: Data("imported".utf8),
        storage: storage
      )
      let importedPath = importedPayload.contents[0].externalFilePath ?? ""
      let imported = record(from: importedPayload, lastCopiedAt: now.addingTimeInterval(10))
      try repository.save([expired, pinned, imported])
      try store.reload(now: now)

      let reloadedTitles = Set(store.records.map(\.title))
      expect(
        reloadedTitles == ["pinned old", "imported"],
        "HistoryStore reload should apply cleanup rules to persistent history")
      expect(
        FileManager.default.fileExists(atPath: importedPath),
        "HistoryStore reload should keep retained imported blobs")
    }
  } catch {
    fatalError("History persistence cleanup check failed: \(error)")
  }
}
