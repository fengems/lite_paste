import Foundation

@MainActor
extension HistoryStore {
  func trimHistoryIfNeeded(now: Date = .now, loadFullIfNeeded: Bool) {
    if isLoadedPartially {
      guard loadFullIfNeeded else {
        return
      }
      guard loadFullHistoryIfNeeded() else {
        return
      }
    }

    trimExpiredHistory(now: now)
    trimOverflowHistory()
  }

  func shouldLoadFullForInitialMaintenance() -> Bool {
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
}
