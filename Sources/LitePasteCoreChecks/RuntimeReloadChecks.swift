import Foundation
import LitePasteCore

@MainActor
func checkRuntimeReload() {
  do {
    try withTemporaryDirectory(prefix: "LitePasteReloadChecks") { directory in
      let historyURL = directory.appending(path: "history.json")
      let settingsURL = directory.appending(path: "settings.json")

      let repository = JSONClipboardHistoryRepository(url: historyURL)
      let initial = ClipboardRecord(
        kind: .text, title: "initial", searchText: "initial", contentHash: "initial")
      let imported = ClipboardRecord(
        kind: .text, title: "imported", searchText: "imported", contentHash: "imported")
      try repository.save([initial])

      let historyStore = HistoryStore(repository: repository)
      expect(
        historyStore.records.first?.title == "initial", "HistoryStore should load initial history")

      try repository.save([imported])
      try historyStore.reload()
      expect(
        historyStore.records.count == 1, "HistoryStore reload should replace in-memory history")
      expect(
        historyStore.records.first?.title == "imported",
        "HistoryStore reload should read imported history")

      let settingsStore = AppSettingsStore(url: settingsURL)
      settingsStore.update { settings in
        settings.viewMode = .card
        settings.hotkey = "command+shift+v"
      }

      let importedSettings = AppSettings(hotkey: "command+option+space", viewMode: .list)
      try JSONEncoder.litePaste.encode(importedSettings).write(to: settingsURL, options: .atomic)

      settingsStore.reload()
      expect(
        settingsStore.settings.viewMode == .list,
        "AppSettingsStore reload should read imported view mode")
      expect(
        settingsStore.settings.hotkey == "command+option+space",
        "AppSettingsStore reload should read imported hotkey")
    }
  } catch {
    fatalError("Runtime reload check failed: \(error)")
  }
}
