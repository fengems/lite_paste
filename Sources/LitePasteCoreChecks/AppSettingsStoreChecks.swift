import Foundation
import LitePasteCore

@MainActor
func checkAppSettingsStoreNormalization() {
  do {
    try withTemporaryDirectory(prefix: "LitePasteSettingsNormalization") { directory in
      let url = directory.appending(path: "settings.json")

      let store = AppSettingsStore(url: url)
      store.update {
        $0.hotkey = "bad+hotkey"
        $0.maxHistoryCount = -99
        $0.retentionDays = -3
        $0.showMenuBarIcon = false
        $0.showDockIcon = false
        $0.tablePlainTextSeparator = " \n "
      }

      expect(
        store.settings.hotkey == "command+shift+v",
        "Settings store update should normalize invalid hotkey")
      expect(
        store.settings.maxHistoryCount == 1,
        "Settings store update should normalize max history count")
      expect(
        store.settings.retentionDays == 0, "Settings store update should normalize retention days")
      expect(
        store.settings.showMenuBarIcon,
        "Settings store update should keep one app entry point visible")
      expect(
        !store.settings.showDockIcon,
        "Settings store update should restore the menu bar icon by default")
      expect(
        store.settings.tablePlainTextSeparator == "、",
        "Settings store update should normalize invalid table separator")

      let reloaded = AppSettingsStore(url: url)
      expect(
        reloaded.settings.hotkey == "command+shift+v",
        "Settings store should persist normalized hotkey")
      expect(
        reloaded.settings.maxHistoryCount == 1,
        "Settings store should persist normalized max history count")
      expect(
        reloaded.settings.retentionDays == 0,
        "Settings store should persist normalized retention days")
      expect(
        reloaded.settings.showMenuBarIcon,
        "Settings store should persist normalized app entry point")
      expect(
        reloaded.settings.tablePlainTextSeparator == "、",
        "Settings store should persist normalized table separator")
    }
  } catch {
    fatalError("Settings store normalization check failed: \(error)")
  }
}

@MainActor
func checkAppSettingsStoreSaveFailureNotification() {
  let sink = NotificationMessageSink()

  do {
    try withTemporaryDirectory(prefix: "LitePasteSettingsSaveFailure") { directory in
      let parentFile = directory.appending(path: "settings-parent")
      let url = parentFile.appending(path: "settings.json")
      try Data("not a directory".utf8).write(to: parentFile, options: .atomic)

      let observer = NotificationCenter.default.addObserver(
        forName: .litePasteSettingsSaveFailed,
        object: nil,
        queue: nil
      ) { notification in
        if let message = notification.userInfo?[SettingsNotificationUserInfoKey.errorMessage]
          as? String
        {
          sink.messages.append(message)
        }
      }
      defer {
        NotificationCenter.default.removeObserver(observer)
      }

      let store = AppSettingsStore(url: url)
      store.update { $0.viewMode = .list }

      expect(!sink.messages.isEmpty, "Settings store should notify when settings cannot be saved")
    }
  } catch {
    fatalError("Settings save failure notification check failed: \(error)")
  }
}
