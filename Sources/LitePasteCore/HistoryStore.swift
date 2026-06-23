import Combine
import Foundation

@MainActor
public final class HistoryStore: ObservableObject {
  @Published public internal(set) var records: [ClipboardRecord] {
    didSet {
      guard !isApplyingControlledMutation else {
        return
      }

      persistAll()
    }
  }

  let repository: any ClipboardHistoryRepository
  let blobStorage: any BlobStorage
  let queryEngine: ClipboardHistoryQueryEngine
  var maxHistoryCount: Int
  var retentionDays: Int
  private var moveDuplicatesToTop: Bool
  var isApplyingControlledMutation = false
  var isLoadedPartially: Bool

  public init(
    records: [ClipboardRecord]? = nil,
    repository: any ClipboardHistoryRepository = MigratingClipboardHistoryRepository(),
    blobStorage: any BlobStorage = LocalBlobStorage(),
    queryEngine: ClipboardHistoryQueryEngine = ClipboardHistoryQueryEngine(),
    maxHistoryCount: Int = 1_000,
    retentionDays: Int = 0,
    moveDuplicatesToTop: Bool = true,
    initialLoadLimit: Int? = nil
  ) {
    let initialHistory = Self.loadInitial(from: repository, records: records, limit: initialLoadLimit)
    self.repository = repository
    self.blobStorage = blobStorage
    self.queryEngine = queryEngine
    self.maxHistoryCount = max(maxHistoryCount, 1)
    self.retentionDays = max(retentionDays, 0)
    self.moveDuplicatesToTop = moveDuplicatesToTop
    self.isLoadedPartially = initialHistory.isPartial
    self.records = initialHistory.records
    trimHistoryIfNeeded(now: .now, loadFullIfNeeded: shouldLoadFullForInitialMaintenance())
  }

  @discardableResult
  public func ingest(
    _ payload: ClipboardPayload,
    sourceAppBundleId: String?,
    sourceAppName: String?,
    now: Date = .now
  ) -> ClipboardRecord {
    let hashBasis = payload.contentHashBasis
    let contentHash = ContentHasher.hash(kind: payload.kind, text: hashBasis)

    if let duplicate = duplicateRecord(contentHash: contentHash) {
      var updated = duplicate
      updated.copyCount += 1
      updated.lastCopiedAt = now
      updated.sourceAppBundleId = sourceAppBundleId
      updated.sourceAppName = sourceAppName

      applyControlledMutation {
        if moveDuplicatesToTop {
          records.removeAll { $0.id == updated.id }
          records.insert(updated, at: frontInsertionIndex(for: updated))
        } else if let index = records.firstIndex(where: { $0.id == updated.id }) {
          records[index] = updated
        }
      }
      persistUpsert(updated, position: moveDuplicatesToTop ? frontInsertionIndex(for: updated) : nil)
      removeExternalFiles(in: payload)
      notifyHistoryChanged()
      return updated
    }

    let record = ClipboardRecord(
      kind: payload.kind,
      title: payload.title,
      searchText: payload.searchText,
      sourceAppBundleId: sourceAppBundleId,
      sourceAppName: sourceAppName,
      createdAt: now,
      lastCopiedAt: now,
      contentHash: contentHash,
      plainText: payload.plainText,
      contents: payload.contents,
      previewFilePath: payload.previewFilePath
    )

    applyControlledMutation {
      records.insert(record, at: frontInsertionIndex(for: record))
    }
    persistUpsert(record, position: frontInsertionIndex(for: record))
    trimHistoryIfNeeded(now: now, loadFullIfNeeded: false)
    return record
  }

  public func toggleFavorite(_ id: ClipboardRecord.ID) {
    update(id) { record in
      record.isFavorite.toggle()
    }
  }

  public func togglePinned(_ id: ClipboardRecord.ID) {
    if let index = records.firstIndex(where: { $0.id == id }) {
      var record = records[index]
      record.isPinned.toggle()
      if !record.isPinned {
        record.pinShortcut = nil
      }

      applyControlledMutation {
        records.remove(at: index)
        records.insert(record, at: frontInsertionIndex(for: record))
      }
      persistUpsert(record, position: frontInsertionIndex(for: record))
      return
    }

    guard var record = record(id: id) else {
      return
    }

    record.isPinned.toggle()
    if !record.isPinned {
      record.pinShortcut = nil
    }
    persistUpsert(record, position: record.isPinned ? 0 : nil)
  }

  public func markUsed(_ id: ClipboardRecord.ID, now: Date = .now) {
    if let index = records.firstIndex(where: { $0.id == id }) {
      var record = records[index]
      updateUsageMetadata(&record, now: now)

      applyControlledMutation {
        records.remove(at: index)
        records.insert(record, at: frontInsertionIndex(for: record))
      }
      persistMarkUsed(id, at: now, position: frontInsertionIndex(for: record), fallbackRecord: record)
      return
    }

    if let repository = repository as? any ClipboardHistoryUsageRepository {
      do {
        try repository.markUsed(id: id, at: now, position: 0)
        notifyHistoryChanged()
      } catch {
        notifyHistoryPersistenceFailed(operation: "更新使用记录", error: error)
      }
      return
    }

    guard var record = record(id: id) else {
      return
    }

    updateUsageMetadata(&record, now: now)
    persistUpsert(record, position: record.isPinned ? 0 : nil)
  }

  private func updateUsageMetadata(_ record: inout ClipboardRecord, now: Date) {
    record.lastUsedAt = now
    record.lastCopiedAt = now
    record.copyCount += 1
  }

  public func updateNote(_ id: ClipboardRecord.ID, note: String, autoFavorite: Bool = false) {
    update(id) { record in
      let normalizedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
      record.note = normalizedNote
      if autoFavorite && !normalizedNote.isEmpty {
        record.isFavorite = true
      }
    }
  }

  public func appendSearchText(_ id: ClipboardRecord.ID, text: String) {
    let fragment = ClipboardSearchText.normalizedFragment(text)
    guard !fragment.isEmpty else {
      return
    }

    update(id) { record in
      guard record.searchText.range(of: fragment, options: [.caseInsensitive, .diacriticInsensitive]) == nil else {
        return
      }

      record.searchText = ClipboardSearchText.appendingFragment(fragment, to: record.searchText)
    }
  }

  public func updateOCRText(_ id: ClipboardRecord.ID, text: String) {
    let fragment = ClipboardSearchText.normalizedFragment(text)
    guard !fragment.isEmpty else {
      return
    }

    update(id) { record in
      record.ocrText = fragment
      guard record.searchText.range(of: fragment, options: [.caseInsensitive, .diacriticInsensitive]) == nil else {
        return
      }
      record.searchText = ClipboardSearchText.appendingFragment(fragment, to: record.searchText)
    }
  }

  public func delete(_ id: ClipboardRecord.ID) {
    let deleted = deletionTargets(for: id)
    applyControlledMutation {
      records.removeAll { $0.id == id }
    }
    persistDelete(id: id)
    removeExternalFiles(in: deleted)
    notifyHistoryChanged()
  }

  public func clearUnpinned() {
    guard loadFullHistoryIfNeeded() else {
      return
    }

    let deleted = records.filter { !$0.isPinned }
    applyControlledMutation {
      records.removeAll { !$0.isPinned }
    }
    persistAll()
    removeExternalFiles(in: deleted)
    notifyHistoryChanged()
  }

  public func clearAll() {
    guard loadFullHistoryIfNeeded() else {
      return
    }

    removeExternalFiles(in: records)
    applyControlledMutation {
      records.removeAll()
    }
    persistDeleteAll()
  }

  public func updateMaxHistoryCount(_ maxHistoryCount: Int) {
    self.maxHistoryCount = max(maxHistoryCount, 1)
    trimHistoryIfNeeded(loadFullIfNeeded: true)
  }

  public func updateRetentionDays(_ retentionDays: Int, now: Date = .now) {
    self.retentionDays = max(retentionDays, 0)
    trimHistoryIfNeeded(now: now, loadFullIfNeeded: true)
  }

  public func updateMoveDuplicatesToTop(_ moveDuplicatesToTop: Bool) {
    self.moveDuplicatesToTop = moveDuplicatesToTop
  }

  public func reload(now: Date = .now) throws {
    let loadedRecords = try repository.load()
    applyControlledMutation {
      records = loadedRecords
      isLoadedPartially = false
    }
    trimHistoryIfNeeded(now: now, loadFullIfNeeded: false)
    notifyHistoryChanged()
  }

  private func update(_ id: ClipboardRecord.ID, _ mutate: (inout ClipboardRecord) -> Void) {
    if let index = records.firstIndex(where: { $0.id == id }) {
      applyControlledMutation {
        mutate(&records[index])
      }
      persistUpsert(records[index], position: nil)
      return
    }

    guard var record = record(id: id) else {
      return
    }

    mutate(&record)
    persistUpsert(record, position: nil)
  }

  private func duplicateRecord(contentHash: String) -> ClipboardRecord? {
    if let record = records.first(where: { $0.contentHash == contentHash }) {
      return record
    }

    if let lookupRepository = repository as? any ClipboardHistoryLookupRepository,
       let record = try? lookupRepository.record(contentHash: contentHash) {
      return record
    }

    return nil
  }

  func applyControlledMutation(_ mutate: () -> Void) {
    isApplyingControlledMutation = true
    defer { isApplyingControlledMutation = false }
    mutate()
  }

  private func frontInsertionIndex(for record: ClipboardRecord) -> Int {
    guard !record.isPinned else {
      return 0
    }

    return records.firstIndex { !$0.isPinned } ?? records.count
  }

  private func deletionTargets(for id: ClipboardRecord.ID) -> [ClipboardRecord] {
    let visibleRecords = records.filter { $0.id == id }
    guard visibleRecords.isEmpty,
          let persistedRecord = record(id: id) else {
      return visibleRecords
    }

    return [persistedRecord]
  }

  private static func loadInitial(
    from repository: any ClipboardHistoryRepository,
    records: [ClipboardRecord]?,
    limit: Int?
  ) -> (records: [ClipboardRecord], isPartial: Bool) {
    if let records {
      return (records, false)
    }

    guard let limit,
          let queryRepository = repository as? any ClipboardHistoryQueryingRepository,
          let records = try? queryRepository.execute(
            ClipboardHistoryQuery(sort: .pinnedThenRecent),
            limit: max(limit, 0),
            offset: 0
          ) else {
      return ((try? repository.load()) ?? [], false)
    }

    return (records, true)
  }

}
