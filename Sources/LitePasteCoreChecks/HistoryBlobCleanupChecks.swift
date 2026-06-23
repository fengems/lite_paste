import Foundation
import LitePasteCore

func externalBlobPayload(
  title: String,
  contentHashBasis: String,
  data: Data,
  storage: LocalBlobStorage
) throws -> ClipboardPayload {
  let snapshot = try storage.snapshot(
    data: data,
    pasteboardType: "public.data",
    preferredExtension: "bin",
    displayOrder: 0
  )

  return ClipboardPayload(
    kind: .image,
    title: title,
    searchText: title,
    contentHashBasis: contentHashBasis,
    pasteboardTypes: ["public.data"],
    contents: [snapshot],
    previewFilePath: snapshot.externalFilePath
  )
}

func record(
  from payload: ClipboardPayload,
  lastCopiedAt: Date,
  isPinned: Bool = false,
  pinShortcut: String? = nil
) -> ClipboardRecord {
  ClipboardRecord(
    kind: payload.kind,
    title: payload.title,
    searchText: payload.searchText,
    createdAt: lastCopiedAt,
    lastCopiedAt: lastCopiedAt,
    isPinned: isPinned,
    pinShortcut: pinShortcut,
    contentHash: ContentHasher.hash(kind: payload.kind, text: payload.contentHashBasis),
    plainText: payload.plainText,
    contents: payload.contents,
    previewFilePath: payload.previewFilePath
  )
}

@MainActor
func checkHistoryBlobCleanup() {
  do {
    try withTemporaryDirectory(prefix: "LitePasteHistoryBlobCleanup") { directory in
      let blobStorage = LocalBlobStorage(directory: directory)

      let duplicateStore = HistoryStore(
        records: [],
        repository: InMemoryClipboardHistoryRepository(),
        blobStorage: blobStorage
      )
      let firstDuplicatePayload = try externalBlobPayload(
        title: "same",
        contentHashBasis: "same",
        data: Data("first".utf8),
        storage: blobStorage
      )
      let secondDuplicatePayload = try externalBlobPayload(
        title: "same again",
        contentHashBasis: "same",
        data: Data("second".utf8),
        storage: blobStorage
      )
      let firstPath = firstDuplicatePayload.contents[0].externalFilePath ?? ""
      let secondPath = secondDuplicatePayload.contents[0].externalFilePath ?? ""

      _ = duplicateStore.ingest(firstDuplicatePayload, sourceAppBundleId: nil, sourceAppName: nil)
      _ = duplicateStore.ingest(secondDuplicatePayload, sourceAppBundleId: nil, sourceAppName: nil)

      expect(
        duplicateStore.records.count == 1,
        "Duplicate blob payloads should deduplicate history records")
      expect(
        FileManager.default.fileExists(atPath: firstPath),
        "Duplicate ingest should keep the original blob")
      expect(
        !FileManager.default.fileExists(atPath: secondPath),
        "Duplicate ingest should remove the unused incoming blob")

      let deleteStore = HistoryStore(
        records: [],
        repository: InMemoryClipboardHistoryRepository(),
        blobStorage: blobStorage
      )
      let deletePayload = try externalBlobPayload(
        title: "delete",
        contentHashBasis: "delete",
        data: Data("delete".utf8),
        storage: blobStorage
      )
      let deletePath = deletePayload.contents[0].externalFilePath ?? ""
      let deleteRecord = deleteStore.ingest(
        deletePayload, sourceAppBundleId: nil, sourceAppName: nil)
      deleteStore.delete(deleteRecord.id)
      expect(
        !FileManager.default.fileExists(atPath: deletePath),
        "Deleting a record should remove its blob")

      let previewStore = HistoryStore(
        records: [],
        repository: InMemoryClipboardHistoryRepository(),
        blobStorage: blobStorage
      )
      let previewContent = try blobStorage.snapshot(
        data: Data("preview-content".utf8),
        pasteboardType: "public.data",
        preferredExtension: "bin",
        displayOrder: 0
      )
      let previewPath = try blobStorage.save(
        data: Data("preview-only".utf8), preferredExtension: "bin")
      let previewRecord = previewStore.ingest(
        ClipboardPayload(
          kind: .image,
          title: "preview",
          searchText: "preview",
          contentHashBasis: "preview",
          pasteboardTypes: ["public.data"],
          contents: [previewContent],
          previewFilePath: previewPath
        ),
        sourceAppBundleId: nil,
        sourceAppName: nil
      )
      previewStore.delete(previewRecord.id)
      expect(
        !FileManager.default.fileExists(atPath: previewContent.externalFilePath ?? ""),
        "Deleting a record should remove content blobs")
      expect(
        !FileManager.default.fileExists(atPath: previewPath),
        "Deleting a record should remove independent preview blobs")

      let clearStore = HistoryStore(
        records: [],
        repository: InMemoryClipboardHistoryRepository(),
        blobStorage: blobStorage
      )
      let pinnedPayload = try externalBlobPayload(
        title: "pinned",
        contentHashBasis: "pinned",
        data: Data("pinned".utf8),
        storage: blobStorage
      )
      let regularPayload = try externalBlobPayload(
        title: "regular",
        contentHashBasis: "regular",
        data: Data("regular".utf8),
        storage: blobStorage
      )
      let pinnedPath = pinnedPayload.contents[0].externalFilePath ?? ""
      let regularPath = regularPayload.contents[0].externalFilePath ?? ""
      let pinnedRecord = clearStore.ingest(
        pinnedPayload, sourceAppBundleId: nil, sourceAppName: nil)
      _ = clearStore.ingest(regularPayload, sourceAppBundleId: nil, sourceAppName: nil)
      clearStore.togglePinned(pinnedRecord.id)
      clearStore.clearUnpinned()

      expect(
        clearStore.records.count == 1 && clearStore.records.first?.id == pinnedRecord.id,
        "Clearing unpinned records should keep pinned records")
      expect(
        FileManager.default.fileExists(atPath: pinnedPath),
        "Clearing unpinned records should keep pinned blobs")
      expect(
        !FileManager.default.fileExists(atPath: regularPath),
        "Clearing unpinned records should remove regular blobs")

      clearStore.clearAll()
      expect(clearStore.records.isEmpty, "Clearing all records should empty history")
      expect(
        !FileManager.default.fileExists(atPath: pinnedPath),
        "Clearing all records should remove pinned blobs too")

      let overflowStore = HistoryStore(
        records: [],
        repository: InMemoryClipboardHistoryRepository(),
        blobStorage: blobStorage,
        maxHistoryCount: 2
      )
      let oldestPayload = try externalBlobPayload(
        title: "oldest",
        contentHashBasis: "oldest",
        data: Data("oldest".utf8),
        storage: blobStorage
      )
      let middlePayload = try externalBlobPayload(
        title: "middle",
        contentHashBasis: "middle",
        data: Data("middle".utf8),
        storage: blobStorage
      )
      let newestPayload = try externalBlobPayload(
        title: "newest",
        contentHashBasis: "newest",
        data: Data("newest".utf8),
        storage: blobStorage
      )
      let oldestPath = oldestPayload.contents[0].externalFilePath ?? ""
      let middlePath = middlePayload.contents[0].externalFilePath ?? ""
      let newestPath = newestPayload.contents[0].externalFilePath ?? ""
      _ = overflowStore.ingest(
        oldestPayload, sourceAppBundleId: nil, sourceAppName: nil,
        now: Date(timeIntervalSince1970: 1))
      _ = overflowStore.ingest(
        middlePayload, sourceAppBundleId: nil, sourceAppName: nil,
        now: Date(timeIntervalSince1970: 2))
      _ = overflowStore.ingest(
        newestPayload, sourceAppBundleId: nil, sourceAppName: nil,
        now: Date(timeIntervalSince1970: 3))

      expect(overflowStore.records.count == 2, "Overflow trimming should enforce max history count")
      expect(
        !FileManager.default.fileExists(atPath: oldestPath),
        "Overflow trimming should remove trimmed blobs")
      expect(
        FileManager.default.fileExists(atPath: middlePath),
        "Overflow trimming should keep retained middle blob")
      expect(
        FileManager.default.fileExists(atPath: newestPath),
        "Overflow trimming should keep retained newest blob")

      let pinnedOverflowStore = HistoryStore(
        records: [],
        repository: InMemoryClipboardHistoryRepository(),
        blobStorage: blobStorage,
        maxHistoryCount: 1
      )
      let pinnedOverflowPayload = try externalBlobPayload(
        title: "pinned overflow",
        contentHashBasis: "pinned overflow",
        data: Data("pinned overflow".utf8),
        storage: blobStorage
      )
      let trimmedPayload = try externalBlobPayload(
        title: "trimmed",
        contentHashBasis: "trimmed",
        data: Data("trimmed".utf8),
        storage: blobStorage
      )
      let pinnedOverflowPath = pinnedOverflowPayload.contents[0].externalFilePath ?? ""
      let trimmedPath = trimmedPayload.contents[0].externalFilePath ?? ""
      let pinnedOverflowRecord = pinnedOverflowStore.ingest(
        pinnedOverflowPayload, sourceAppBundleId: nil, sourceAppName: nil)
      pinnedOverflowStore.togglePinned(pinnedOverflowRecord.id)
      _ = pinnedOverflowStore.ingest(trimmedPayload, sourceAppBundleId: nil, sourceAppName: nil)

      expect(
        pinnedOverflowStore.records.count == 1
          && pinnedOverflowStore.records.first?.id == pinnedOverflowRecord.id,
        "Overflow trimming should preserve pinned records")
      expect(
        FileManager.default.fileExists(atPath: pinnedOverflowPath),
        "Overflow trimming should preserve pinned blobs")
      expect(
        !FileManager.default.fileExists(atPath: trimmedPath),
        "Overflow trimming should remove non-pinned overflow blobs")
    }
  } catch {
    fatalError("History blob cleanup check failed: \(error)")
  }
}
