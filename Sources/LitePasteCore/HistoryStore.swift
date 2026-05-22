import Combine
import Foundation

@MainActor
public final class HistoryStore: ObservableObject {
  @Published public private(set) var records: [ClipboardRecord] {
    didSet {
      persist()
    }
  }

  private let repository: any ClipboardHistoryRepository
  private let blobStorage: any BlobStorage
  private let queryEngine: ClipboardHistoryQueryEngine
  private var maxHistoryCount: Int
  private var retentionDays: Int
  private var moveDuplicatesToTop: Bool

  public init(
    records: [ClipboardRecord]? = nil,
    repository: any ClipboardHistoryRepository = JSONClipboardHistoryRepository(),
    blobStorage: any BlobStorage = LocalBlobStorage(),
    queryEngine: ClipboardHistoryQueryEngine = ClipboardHistoryQueryEngine(),
    maxHistoryCount: Int = 1_000,
    retentionDays: Int = 0,
    moveDuplicatesToTop: Bool = true
  ) {
    self.repository = repository
    self.blobStorage = blobStorage
    self.queryEngine = queryEngine
    self.maxHistoryCount = maxHistoryCount
    self.retentionDays = retentionDays
    self.moveDuplicatesToTop = moveDuplicatesToTop
    self.records = records ?? Self.load(from: repository)
    trimHistoryIfNeeded(now: .now)
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

    if let index = records.firstIndex(where: { $0.contentHash == contentHash }) {
      records[index].copyCount += 1
      records[index].lastCopiedAt = now
      records[index].sourceAppBundleId = sourceAppBundleId
      records[index].sourceAppName = sourceAppName
      let updated = records[index]
      if moveDuplicatesToTop {
        records.remove(at: index)
        records.insert(updated, at: 0)
      }
      removeExternalFiles(in: payload.contents)
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

    records.insert(record, at: 0)
    trimHistoryIfNeeded(now: now)
    return record
  }

  public func filteredRecords(query: String, filter: ClipboardFilter) -> [ClipboardRecord] {
    filteredRecords(ClipboardHistoryQuery(text: query, filter: filter))
  }

  public func filteredRecords(_ query: ClipboardHistoryQuery) -> [ClipboardRecord] {
    queryEngine.execute(query, records: records)
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

    let normalizedShortcut = shortcut?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    records[targetIndex].isPinned = true
    records[targetIndex].pinShortcut = normalizedShortcut?.isEmpty == true ? nil : normalizedShortcut

    guard let normalizedShortcut, !normalizedShortcut.isEmpty else {
      return
    }

    for index in records.indices where records[index].id != id && records[index].pinShortcut == normalizedShortcut {
      records[index].pinShortcut = nil
    }
  }

  public func usedPinShortcuts(excluding id: ClipboardRecord.ID? = nil) -> Set<String> {
    Set(
      records.compactMap { record in
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
    }
  }

  public func updateNote(_ id: ClipboardRecord.ID, note: String) {
    update(id) { record in
      record.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }

  public func delete(_ id: ClipboardRecord.ID) {
    let deleted = records.filter { $0.id == id }
    records.removeAll { $0.id == id }
    removeExternalFiles(in: deleted)
  }

  public func clearUnpinned() {
    let deleted = records.filter { !$0.isPinned }
    records.removeAll { !$0.isPinned }
    removeExternalFiles(in: deleted)
  }

  public func clearAll() {
    removeExternalFiles(in: records)
    records.removeAll()
  }

  public func updateMaxHistoryCount(_ maxHistoryCount: Int) {
    self.maxHistoryCount = max(maxHistoryCount, 1)
    trimHistoryIfNeeded()
  }

  public func updateRetentionDays(_ retentionDays: Int, now: Date = .now) {
    self.retentionDays = max(retentionDays, 0)
    trimHistoryIfNeeded(now: now)
  }

  public func updateMoveDuplicatesToTop(_ moveDuplicatesToTop: Bool) {
    self.moveDuplicatesToTop = moveDuplicatesToTop
  }

  public func reload(now: Date = .now) throws {
    records = try repository.load()
    trimHistoryIfNeeded(now: now)
  }

  private func update(_ id: ClipboardRecord.ID, _ mutate: (inout ClipboardRecord) -> Void) {
    guard let index = records.firstIndex(where: { $0.id == id }) else {
      return
    }

    mutate(&records[index])
  }

  private func trimHistoryIfNeeded(now: Date = .now) {
    trimExpiredHistory(now: now)
    trimOverflowHistory()
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
    records = queryEngine.execute(
      ClipboardHistoryQuery(sort: .pinnedThenRecent),
      records: pinned + regular
    )
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
    records.removeAll { expiredIds.contains($0.id) }
    removeExternalFiles(in: expired)
  }

  private func persist() {
    do {
      try repository.save(records)
    } catch {
      assertionFailure("Unable to save clipboard history: \(error)")
    }
  }

  private static func load(from repository: any ClipboardHistoryRepository) -> [ClipboardRecord] {
    (try? repository.load()) ?? []
  }

  private func removeExternalFiles(in records: [ClipboardRecord]) {
    removeExternalFiles(in: records.flatMap(\.contents))
  }

  private func removeExternalFiles(in snapshots: [ClipboardContentSnapshot]) {
    blobStorage.removeExternalFiles(in: snapshots)
  }
}
