import Foundation

@MainActor
extension HistoryStore {
  func persistUpsert(_ record: ClipboardRecord, position: Int?) {
    guard let repository = repository as? any ClipboardHistoryIncrementalRepository else {
      persistAll()
      return
    }

    do {
      try repository.upsert(record, position: position)
      notifyHistoryChanged()
    } catch {
      notifyHistoryPersistenceFailed(operation: "保存历史", error: error)
    }
  }

  func persistMarkUsed(
    _ id: ClipboardRecord.ID,
    at date: Date,
    position: Int,
    fallbackRecord: ClipboardRecord
  ) {
    guard let repository = repository as? any ClipboardHistoryUsageRepository else {
      persistUpsert(fallbackRecord, position: position)
      return
    }

    do {
      try repository.markUsed(id: id, at: date, position: position)
      notifyHistoryChanged()
    } catch {
      notifyHistoryPersistenceFailed(operation: "更新使用记录", error: error)
    }
  }

  func persistDelete(id: ClipboardRecord.ID) {
    guard let repository = repository as? any ClipboardHistoryIncrementalRepository else {
      persistAll()
      return
    }

    do {
      try repository.delete(id: id)
      notifyHistoryChanged()
    } catch {
      notifyHistoryPersistenceFailed(operation: "删除历史", error: error)
    }
  }

  func persistDeleteAll() {
    guard let repository = repository as? any ClipboardHistoryIncrementalRepository else {
      persistAll()
      return
    }

    do {
      try repository.deleteAll()
      notifyHistoryChanged()
    } catch {
      notifyHistoryPersistenceFailed(operation: "清空历史", error: error)
    }
  }

  func persistAll() {
    do {
      if isLoadedPartially {
        try loadFullHistoryIfNeededThrowing()
      }
      try repository.save(records)
      notifyHistoryChanged()
    } catch {
      notifyHistoryPersistenceFailed(operation: "保存历史", error: error)
    }
  }

  func notifyHistoryChanged() {
    NotificationCenter.default.post(name: .litePasteHistoryChanged, object: nil)
  }

  func notifyHistoryPersistenceFailed(operation: String, error: Error) {
    NotificationCenter.default.post(
      name: .litePasteHistoryPersistenceFailed,
      object: self,
      userInfo: [
        HistoryNotificationUserInfoKey.operation: operation,
        HistoryNotificationUserInfoKey.errorMessage: error.localizedDescription
      ]
    )
    NSLog("Unable to persist Lite Paste clipboard history during \(operation): \(error)")
  }

  @discardableResult
  func loadFullHistoryIfNeeded() -> Bool {
    do {
      try loadFullHistoryIfNeededThrowing()
      return true
    } catch {
      notifyHistoryPersistenceFailed(operation: "读取完整历史", error: error)
      return false
    }
  }

  func loadFullHistoryIfNeededThrowing() throws {
    guard isLoadedPartially else {
      return
    }

    let loadedRecords = try repository.load()
    applyControlledMutation {
      records = loadedRecords
      isLoadedPartially = false
    }
  }
}
