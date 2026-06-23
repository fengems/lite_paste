import Foundation
import LitePasteCore

func checkMigratingHistoryRepository() {
  do {
    try withTemporaryDirectory(prefix: "LitePasteMigrationChecks") { directory in
      let legacyURL = directory.appending(path: "history.json")
      let sqliteURL = directory.appending(path: "history.sqlite3")

      let legacyRecord = ClipboardRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
        kind: .text,
        title: "legacy",
        searchText: "legacy",
        createdAt: Date(timeIntervalSince1970: 10),
        lastCopiedAt: Date(timeIntervalSince1970: 11),
        contentHash: "legacy-hash",
        plainText: "legacy"
      )
      try JSONClipboardHistoryRepository(url: legacyURL).save([legacyRecord])

      let repository = MigratingClipboardHistoryRepository(
        sqliteURL: sqliteURL, legacyJSONURL: legacyURL)
      let migrated = try repository.load()
      let sqliteRecords = try SQLiteClipboardHistoryRepository(url: sqliteURL).load()

      expect(migrated == [legacyRecord], "Migrating repository should load legacy JSON records")
      expect(
        sqliteRecords == [legacyRecord],
        "Migrating repository should persist legacy records into SQLite"
      )
      expect(
        !FileManager.default.fileExists(atPath: legacyURL.path),
        "Migrating repository should remove legacy JSON after successful migration"
      )

      let queryLegacyURL = directory.appending(path: "query-history.json")
      let querySQLiteURL = directory.appending(path: "query-history.sqlite3")
      try JSONClipboardHistoryRepository(url: queryLegacyURL).save([legacyRecord])
      let queryRepository = MigratingClipboardHistoryRepository(
        sqliteURL: querySQLiteURL, legacyJSONURL: queryLegacyURL)
      let queryMigrated = try queryRepository.execute(
        ClipboardHistoryQuery(text: "legacy"), limit: 1, offset: 0)
      let queryCount = try queryRepository.count(ClipboardHistoryQuery())
      expect(
        queryMigrated == [legacyRecord],
        "Migrating repository should migrate before direct paged queries")
      expect(queryCount == 1, "Migrating repository should count after direct query migration")

      let lookupLegacyURL = directory.appending(path: "lookup-history.json")
      let lookupSQLiteURL = directory.appending(path: "lookup-history.sqlite3")
      try JSONClipboardHistoryRepository(url: lookupLegacyURL).save([legacyRecord])
      let lookupRepository = MigratingClipboardHistoryRepository(
        sqliteURL: lookupSQLiteURL, legacyJSONURL: lookupLegacyURL)
      let lookupRecord = try lookupRepository.record(id: legacyRecord.id)
      expect(
        lookupRecord == legacyRecord,
        "Migrating repository should migrate before direct record lookup"
      )
      let lookupHashRecord = try lookupRepository.record(contentHash: legacyRecord.contentHash)
      expect(
        lookupHashRecord == legacyRecord,
        "Migrating repository should support content hash lookup after migration"
      )

      let incrementalLegacyURL = directory.appending(path: "incremental-history.json")
      let incrementalSQLiteURL = directory.appending(path: "incremental-history.sqlite3")
      try JSONClipboardHistoryRepository(url: incrementalLegacyURL).save([legacyRecord])
      let incrementalRepository = MigratingClipboardHistoryRepository(
        sqliteURL: incrementalSQLiteURL,
        legacyJSONURL: incrementalLegacyURL
      )
      var incrementallyUpdated = legacyRecord
      incrementallyUpdated.note = "updated through migration"
      try incrementalRepository.upsert(incrementallyUpdated, position: nil)
      let migratedIncrementalUpdate = try incrementalRepository.record(id: legacyRecord.id)
      expect(
        migratedIncrementalUpdate == incrementallyUpdated,
        "Migrating repository should upsert after migrating legacy records"
      )
      try incrementalRepository.delete(id: legacyRecord.id)
      let deletedMigratedRecord = try incrementalRepository.record(id: legacyRecord.id)
      expect(
        deletedMigratedRecord == nil,
        "Migrating repository should delete records after migration"
      )

      let currentRecord = ClipboardRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
        kind: .text,
        title: "current",
        searchText: "current",
        createdAt: Date(timeIntervalSince1970: 20),
        lastCopiedAt: Date(timeIntervalSince1970: 21),
        contentHash: "current-hash",
        plainText: "current"
      )
      try repository.save([currentRecord])
      let currentRecords = try repository.load()

      expect(
        currentRecords == [currentRecord],
        "Migrating repository should prefer SQLite after migration")

      try JSONClipboardHistoryRepository(url: legacyURL).save([legacyRecord])
      try repository.save([])
      let emptyRecords = try repository.load()
      expect(
        emptyRecords.isEmpty,
        "Migrating repository should not resurrect legacy JSON after empty save")
    }
  } catch {
    fatalError("Migrating repository check failed: \(error)")
  }
}
