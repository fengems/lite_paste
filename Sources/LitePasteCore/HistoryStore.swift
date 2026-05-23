import Combine
import Foundation

@MainActor
public final class HistoryStore: ObservableObject {
  @Published public private(set) var records: [ClipboardRecord] {
    didSet {
      guard !isApplyingControlledMutation else {
        return
      }

      persistAll()
    }
  }

  private let repository: any ClipboardHistoryRepository
  private let blobStorage: any BlobStorage
  private let queryEngine: ClipboardHistoryQueryEngine
  private var maxHistoryCount: Int
  private var retentionDays: Int
  private var moveDuplicatesToTop: Bool
  private var isApplyingControlledMutation = false
  private var isLoadedPartially: Bool

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
          records.insert(updated, at: 0)
        } else if let index = records.firstIndex(where: { $0.id == updated.id }) {
          records[index] = updated
        }
      }
      persistUpsert(updated, position: moveDuplicatesToTop ? 0 : nil)
      removeExternalFiles(in: payload.contents)
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
      records.insert(record, at: 0)
    }
    persistUpsert(record, position: 0)
    trimHistoryIfNeeded(now: now, loadFullIfNeeded: false)
    return record
  }

  public func filteredRecords(query: String, filter: ClipboardFilter) -> [ClipboardRecord] {
    filteredRecords(ClipboardHistoryQuery(text: query, filter: filter))
  }

  public func filteredRecords(_ query: ClipboardHistoryQuery) -> [ClipboardRecord] {
    filteredRecords(query, limit: nil)
  }

  public func filteredRecords(
    _ query: ClipboardHistoryQuery,
    limit: Int?,
    offset: Int = 0
  ) -> [ClipboardRecord] {
    if let queryRepository = repository as? any ClipboardHistoryQueryingRepository,
       let records = try? queryRepository.execute(query, limit: limit, offset: offset) {
      return records
    }

    return slice(queryEngine.execute(query, records: records), limit: limit, offset: offset)
  }

  public func filteredRecordCount(_ query: ClipboardHistoryQuery) -> Int {
    if let queryRepository = repository as? any ClipboardHistoryQueryingRepository,
       let count = try? queryRepository.count(query) {
      return count
    }

    return queryEngine.execute(query, records: records).count
  }

  public func allRecordCount() -> Int {
    filteredRecordCount(ClipboardHistoryQuery(filter: .all))
  }

  public func unpinnedRecordCount() -> Int {
    max(
      allRecordCount() - filteredRecordCount(ClipboardHistoryQuery(filter: .pinned)),
      0
    )
  }

  public func filteredPage(
    _ query: ClipboardHistoryQuery,
    limit: Int,
    offset: Int = 0
  ) -> ClipboardHistoryPage {
    let limit = max(limit, 0)
    let offset = max(offset, 0)
    return ClipboardHistoryPage(
      records: filteredRecords(query, limit: limit, offset: offset),
      totalCount: filteredRecordCount(query),
      limit: limit,
      offset: offset
    )
  }

  public func record(id: ClipboardRecord.ID) -> ClipboardRecord? {
    if let record = records.first(where: { $0.id == id }) {
      return record
    }

    if let lookupRepository = repository as? any ClipboardHistoryLookupRepository,
       let record = try? lookupRepository.record(id: id) {
      return record
    }

    return nil
  }

  public func pinnedShortcutRecords() -> [ClipboardRecord] {
    if let queryRepository = repository as? any ClipboardHistoryQueryingRepository,
       let records = try? queryRepository.execute(
         ClipboardHistoryQuery(filter: .pinned, sort: .recent),
         limit: nil,
         offset: 0
       ) {
      return records.filter { $0.pinShortcut != nil }
    }

    return records
      .filter { $0.isPinned && $0.pinShortcut != nil }
      .sorted { $0.lastCopiedAt > $1.lastCopiedAt }
  }

  public func toggleFavorite(_ id: ClipboardRecord.ID) {
    update(id) { record in
      record.isFavorite.toggle()
    }
  }

  public func togglePinned(_ id: ClipboardRecord.ID) {
    update(id) { record in
      record.isPinned.toggle()
      if !record.isPinned {
        record.pinShortcut = nil
      }
    }
  }

  public func updatePinShortcut(_ id: ClipboardRecord.ID, shortcut: String?) {
    guard let targetIndex = records.firstIndex(where: { $0.id == id }) else {
      return
    }

    let normalizedShortcut = shortcut.flatMap(PinShortcutCatalog.normalized)
    applyControlledMutation {
      records[targetIndex].isPinned = true
      records[targetIndex].pinShortcut = normalizedShortcut
    }
    persistUpsert(records[targetIndex], position: nil)

    guard let normalizedShortcut else {
      return
    }

    for index in records.indices where records[index].id != id && records[index].pinShortcut == normalizedShortcut {
      applyControlledMutation {
        records[index].pinShortcut = nil
      }
      persistUpsert(records[index], position: nil)
    }
  }

  public func usedPinShortcuts(excluding id: ClipboardRecord.ID? = nil) -> Set<String> {
    Set(
      pinnedShortcutRecords().compactMap { record in
        guard record.id != id else {
          return nil
        }
        return record.pinShortcut
      }
    )
  }

  public func markUsed(_ id: ClipboardRecord.ID, now: Date = .now) {
    update(id) { record in
      record.lastUsedAt = now
      record.copyCount += 1
    }
  }

  public func updateNote(_ id: ClipboardRecord.ID, note: String) {
    update(id) { record in
      record.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }

  public func delete(_ id: ClipboardRecord.ID) {
    let deleted = records.filter { $0.id == id } + [record(id: id)].compactMap { optionalLookup in
      guard let lookup = optionalLookup else {
        return nil
      }
      guard records.allSatisfy({ $0.id != lookup.id }) else {
        return nil
      }
      return lookup
    }
    applyControlledMutation {
      records.removeAll { $0.id == id }
    }
    persistDelete(id: id)
    removeExternalFiles(in: deleted)
    notifyHistoryChanged()
  }

  public func clearUnpinned() {
    loadFullHistoryIfNeeded()
    let deleted = records.filter { !$0.isPinned }
    applyControlledMutation {
      records.removeAll { !$0.isPinned }
    }
    persistAll()
    removeExternalFiles(in: deleted)
    notifyHistoryChanged()
  }

  public func clearAll() {
    loadFullHistoryIfNeeded()
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

  private func trimHistoryIfNeeded(now: Date = .now, loadFullIfNeeded: Bool) {
    if isLoadedPartially {
      guard loadFullIfNeeded else {
        return
      }
      loadFullHistoryIfNeeded()
    }

    trimExpiredHistory(now: now)
    trimOverflowHistory()
  }

  private func shouldLoadFullForInitialMaintenance() -> Bool {
    guard isLoadedPartially else {
      return false
    }

    return retentionDays > 0 || allRecordCount() > maxHistoryCount
  }

  private func trimOverflowHistory() {
    guard records.count > maxHistoryCount else {
      return
    }

    let pinned = records.filter(\.isPinned)
    let regularLimit = max(maxHistoryCount - pinned.count, 0)
    let regularRecords = queryEngine.execute(
      ClipboardHistoryQuery(sort: .recent),
      records: records.filter { !$0.isPinned }
    )
    let regular = regularRecords.prefix(regularLimit)
    let trimmed = regularRecords.dropFirst(regularLimit)
    removeExternalFiles(in: Array(trimmed))
    applyControlledMutation {
      records = queryEngine.execute(
        ClipboardHistoryQuery(sort: .pinnedThenRecent),
        records: pinned + regular
      )
    }
    persistAll()
  }

  private func trimExpiredHistory(now: Date) {
    guard retentionDays > 0 else {
      return
    }

    let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: now) ?? now
    let expired = records.filter { record in
      !record.isPinned && record.lastCopiedAt < cutoff
    }

    guard !expired.isEmpty else {
      return
    }

    let expiredIds = Set(expired.map(\.id))
    applyControlledMutation {
      records.removeAll { expiredIds.contains($0.id) }
    }
    persistAll()
    removeExternalFiles(in: expired)
    notifyHistoryChanged()
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

  private func applyControlledMutation(_ mutate: () -> Void) {
    isApplyingControlledMutation = true
    mutate()
    isApplyingControlledMutation = false
  }

  private func persistUpsert(_ record: ClipboardRecord, position: Int?) {
    guard let repository = repository as? any ClipboardHistoryIncrementalRepository else {
      persistAll()
      return
    }

    do {
      try repository.upsert(record, position: position)
      notifyHistoryChanged()
    } catch {
      assertionFailure("Unable to upsert clipboard history: \(error)")
    }
  }

  private func persistDelete(id: ClipboardRecord.ID) {
    guard let repository = repository as? any ClipboardHistoryIncrementalRepository else {
      persistAll()
      return
    }

    do {
      try repository.delete(id: id)
      notifyHistoryChanged()
    } catch {
      assertionFailure("Unable to delete clipboard history: \(error)")
    }
  }

  private func persistDeleteAll() {
    guard let repository = repository as? any ClipboardHistoryIncrementalRepository else {
      persistAll()
      return
    }

    do {
      try repository.deleteAll()
      notifyHistoryChanged()
    } catch {
      assertionFailure("Unable to clear clipboard history: \(error)")
    }
  }

  private func persistAll() {
    do {
      if isLoadedPartially {
        try loadFullHistoryIfNeededThrowing()
      }
      try repository.save(records)
      notifyHistoryChanged()
    } catch {
      assertionFailure("Unable to save clipboard history: \(error)")
    }
  }

  private func notifyHistoryChanged() {
    NotificationCenter.default.post(name: .litePasteHistoryChanged, object: nil)
  }

  private func loadFullHistoryIfNeeded() {
    do {
      try loadFullHistoryIfNeededThrowing()
    } catch {
      assertionFailure("Unable to load full clipboard history: \(error)")
    }
  }

  private func loadFullHistoryIfNeededThrowing() throws {
    guard isLoadedPartially else {
      return
    }

    let loadedRecords = try repository.load()
    applyControlledMutation {
      records = loadedRecords
      isLoadedPartially = false
    }
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

  private func slice(_ records: [ClipboardRecord], limit: Int?, offset: Int) -> [ClipboardRecord] {
    let offset = min(max(offset, 0), records.count)
    let records = records.dropFirst(offset)
    guard let limit else {
      return Array(records)
    }

    return Array(records.prefix(max(limit, 0)))
  }

  private func removeExternalFiles(in records: [ClipboardRecord]) {
    removeExternalFiles(in: records.flatMap(\.contents))
  }

  private func removeExternalFiles(in snapshots: [ClipboardContentSnapshot]) {
    blobStorage.removeExternalFiles(in: snapshots)
  }
}
