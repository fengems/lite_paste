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
  private let maxHistoryCount: Int

  public init(
    records: [ClipboardRecord]? = nil,
    repository: any ClipboardHistoryRepository = JSONClipboardHistoryRepository(),
    blobStorage: any BlobStorage = LocalBlobStorage(),
    maxHistoryCount: Int = 1_000
  ) {
    self.repository = repository
    self.blobStorage = blobStorage
    self.maxHistoryCount = maxHistoryCount
    self.records = records ?? Self.load(from: repository)
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
      let updated = records.remove(at: index)
      records.insert(updated, at: 0)
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
    trimHistoryIfNeeded()
    return record
  }

  public func filteredRecords(query: String, filter: ClipboardFilter) -> [ClipboardRecord] {
    let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    return records.filter { record in
      guard filter.matches(record) else {
        return false
      }

      guard !normalizedQuery.isEmpty else {
        return true
      }

      let haystack = [
        record.title,
        record.searchText,
        record.note,
        record.sourceAppName ?? "",
        record.sourceAppBundleId ?? ""
      ]
        .joined(separator: "\n")
        .lowercased()

      return haystack.contains(normalizedQuery)
    }
  }

  public func toggleFavorite(_ id: ClipboardRecord.ID) {
    update(id) { record in
      record.isFavorite.toggle()
    }
  }

  public func togglePinned(_ id: ClipboardRecord.ID) {
    update(id) { record in
      record.isPinned.toggle()
    }
  }

  public func markUsed(_ id: ClipboardRecord.ID, now: Date = .now) {
    update(id) { record in
      record.lastUsedAt = now
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

  private func update(_ id: ClipboardRecord.ID, _ mutate: (inout ClipboardRecord) -> Void) {
    guard let index = records.firstIndex(where: { $0.id == id }) else {
      return
    }

    mutate(&records[index])
  }

  private func trimHistoryIfNeeded() {
    guard records.count > maxHistoryCount else {
      return
    }

    let pinned = records.filter(\.isPinned)
    let regularLimit = max(maxHistoryCount - pinned.count, 0)
    let regularRecords = records.filter { !$0.isPinned }
    let regular = regularRecords.prefix(regularLimit)
    let trimmed = regularRecords.dropFirst(regularLimit)
    removeExternalFiles(in: Array(trimmed))
    records = pinned + regular
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
