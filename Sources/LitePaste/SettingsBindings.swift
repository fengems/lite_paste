import LitePasteCore
import SwiftUI

@MainActor
struct SettingsBindings {
  let store: AppSettingsStore
  let launchAtLoginController: LaunchAtLoginController

  var launchAtLogin: Binding<Bool> {
    Binding {
      store.settings.launchAtLogin
    } set: { value in
      do {
        try launchAtLoginController.setEnabled(value)
        store.update { $0.launchAtLogin = value }
      } catch {
        UserAlerts.showMessage(
          title: AppText.value("无法更新开机启动", "Unable To Update Launch At Login"),
          message: error.localizedDescription,
          style: .warning
        )
      }
    }
  }

  var panelHotkey: Binding<String> {
    setting(\.hotkey)
  }

  var copySoundEnabled: Binding<Bool> {
    setting(\.copySoundEnabled)
  }

  var imageOCREnabled: Binding<Bool> {
    setting(\.imageOCREnabled)
  }

  var copyPlainTextByDefault: Binding<Bool> {
    setting(\.copyPlainTextByDefault)
  }

  var pastePlainTextByDefault: Binding<Bool> {
    setting(\.pastePlainTextByDefault)
  }

  var sanitizesSystemClipboardOnCopy: Binding<Bool> {
    setting(\.sanitizesSystemClipboardOnCopy)
  }

  var visibleQuickActions: Binding<Set<ClipboardQuickAction>> {
    setting(\.visibleQuickActions)
  }

  var autoFavoriteAfterNote: Binding<Bool> {
    setting(\.autoFavoriteAfterNote)
  }

  var restoreClipboardAfterPaste: Binding<Bool> {
    setting(\.restoreClipboardAfterPaste)
  }

  var preserveLargeRichTextFormats: Binding<Bool> {
    setting(\.preserveLargeRichTextFormats)
  }

  var clearSearchOnOpen: Binding<Bool> {
    setting(\.clearSearchOnOpen)
  }

  var focusSearchOnOpen: Binding<Bool> {
    setting(\.focusSearchOnOpen)
  }

  var coverMenuBarWhenEdgeAttached: Binding<Bool> {
    setting(\.coverMenuBarWhenEdgeAttached)
  }

  var moveDuplicatesToTop: Binding<Bool> {
    setting(\.moveDuplicatesToTop)
  }

  var viewMode: Binding<ClipboardPanelViewMode> {
    setting(\.viewMode)
  }

  var showMenuBarIcon: Binding<Bool> {
    setting(\.showMenuBarIcon)
  }

  var showDockIcon: Binding<Bool> {
    setting(\.showDockIcon)
  }

  var interfaceLanguage: Binding<AppLanguage> {
    Binding {
      store.settings.interfaceLanguage
    } set: { value in
      AppText.updateInterfaceLanguage(value)
      store.update { $0.interfaceLanguage = value }
    }
  }

  var themeMode: Binding<AppThemeMode> {
    setting(\.themeMode)
  }

  var panelPosition: Binding<PanelPosition> {
    setting(\.panelPosition)
  }

  var maxHistoryCount: Binding<Int> {
    setting(\.maxHistoryCount)
  }

  var retentionDays: Binding<Int> {
    setting(\.retentionDays)
  }

  var isMonitoringPaused: Binding<Bool> {
    setting(\.isMonitoringPaused)
  }

  var autoPasteMode: Binding<AutoPasteMode> {
    setting(\.autoPasteMode)
  }

  private func setting<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
    Binding {
      store.settings[keyPath: keyPath]
    } set: { value in
      store.update { $0[keyPath: keyPath] = value }
    }
  }
}
