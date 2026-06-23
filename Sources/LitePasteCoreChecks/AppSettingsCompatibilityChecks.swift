import Foundation
import LitePasteCore

func checkAppSettingsBackwardCompatibility() {
  let data = Data(#"{"hotkey":"command+shift+v","viewMode":"list"}"#.utf8)

  do {
    let settings = try JSONDecoder.litePaste.decode(AppSettings.self, from: data)
    expect(settings.viewMode == ClipboardPanelViewMode.list, "Settings should decode existing view mode string")
    expect(settings.panelPosition == .edgeBottom, "Settings should default panelPosition to bottom edge for old files")
    expect(PanelHotkeyCatalog.displayName(for: settings.hotkey) == "⌘⇧V", "Panel hotkey should have display name")
    expect(settings.clearSearchOnOpen, "Settings should default clearSearchOnOpen for old files")
    expect(settings.maxHistoryCount == 1_000, "Settings should default maxHistoryCount for old files")
    expect(!settings.restoreClipboardAfterPaste, "Settings should default restoreClipboardAfterPaste for old files")
    expect(!settings.preserveLargeRichTextFormats, "Settings should default large rich text preservation to off")
    expect(!settings.copySoundEnabled, "Settings should default copy sound to off")
    expect(!settings.imageOCREnabled, "Settings should default image OCR to off")
    expect(!settings.copyPlainTextByDefault, "Settings should default plain-text copy to off")
    expect(!settings.pastePlainTextByDefault, "Settings should default plain-text paste to off")
    expect(settings.visibleQuickActions == ClipboardQuickAction.defaultVisibleActions, "Settings should default quick actions")
    expect(!settings.autoFavoriteAfterNote, "Settings should default auto favorite after notes to off")
    expect(settings.moveDuplicatesToTop, "Settings should default moveDuplicatesToTop for old files")
    expect(settings.focusSearchOnOpen, "Settings should default focusSearchOnOpen for old files")
    expect(settings.coverMenuBarWhenEdgeAttached, "Settings should default menu bar coverage to on for old files")
    expect(!settings.isMonitoringPaused, "Settings should default paused monitoring to off for old files")
    expect(settings.showMenuBarIcon, "Settings should default menu bar icon to on")
    expect(!settings.showDockIcon, "Settings should default Dock icon to off")
    expect(settings.interfaceLanguage == .system, "Settings should default interface language to system")
    expect(settings.themeMode == .system, "Settings should default theme mode to system")

    let legacyPausedData = Data(#"{"privacyMode":true}"#.utf8)
    let legacyPausedSettings = try JSONDecoder.litePaste.decode(AppSettings.self, from: legacyPausedData)
    expect(legacyPausedSettings.isMonitoringPaused, "Settings should migrate legacy privacyMode to paused monitoring")

    let legacyPlainTextData = Data(#"{"pastePlainByDefault":true}"#.utf8)
    let legacyPlainTextSettings = try JSONDecoder.litePaste.decode(AppSettings.self, from: legacyPlainTextData)
    expect(legacyPlainTextSettings.copyPlainTextByDefault, "Settings should migrate legacy plain-text copy")
    expect(legacyPlainTextSettings.pastePlainTextByDefault, "Settings should migrate legacy plain-text paste")

    let custom = AppSettings(
      panelPosition: .cursor,
      copySoundEnabled: true,
      imageOCREnabled: true,
      copyPlainTextByDefault: true,
      pastePlainTextByDefault: true,
      restoreClipboardAfterPaste: true,
      preserveLargeRichTextFormats: true,
      visibleQuickActions: [.copy, .pastePlainText, .delete],
      autoFavoriteAfterNote: true,
      moveDuplicatesToTop: false,
      focusSearchOnOpen: false,
      coverMenuBarWhenEdgeAttached: true,
      isMonitoringPaused: true,
      showMenuBarIcon: false,
      showDockIcon: true,
      interfaceLanguage: .ja,
      themeMode: .dark
    )
    let encoded = try JSONEncoder.litePaste.encode(custom)
    let decoded = try JSONDecoder.litePaste.decode(AppSettings.self, from: encoded)

    expect(decoded.isMonitoringPaused, "Settings should preserve paused monitoring")
    expect(
      decoded.panelPosition == PanelPosition.cursor,
      "Settings should preserve panel position"
    )
    expect(
      decoded.restoreClipboardAfterPaste,
      "Settings should preserve clipboard restore behavior"
    )
    expect(
      decoded.preserveLargeRichTextFormats,
      "Settings should preserve large rich text preservation behavior"
    )
    expect(decoded.copySoundEnabled, "Settings should preserve copy sound")
    expect(decoded.imageOCREnabled, "Settings should preserve image OCR")
    expect(decoded.copyPlainTextByDefault, "Settings should preserve plain-text copy")
    expect(decoded.pastePlainTextByDefault, "Settings should preserve plain-text paste")
    expect(decoded.visibleQuickActions == [.copy, .pastePlainText, .delete], "Settings should preserve quick actions")
    expect(decoded.autoFavoriteAfterNote, "Settings should preserve auto favorite after notes")
    expect(
      !decoded.moveDuplicatesToTop,
      "Settings should preserve duplicate ordering behavior"
    )
    expect(
      !decoded.focusSearchOnOpen,
      "Settings should preserve search focus behavior"
    )
    expect(
      decoded.coverMenuBarWhenEdgeAttached,
      "Settings should preserve menu bar coverage behavior"
    )
    expect(!decoded.showMenuBarIcon, "Settings should preserve hidden menu bar icon")
    expect(decoded.showDockIcon, "Settings should preserve shown Dock icon")
    expect(decoded.interfaceLanguage == .ja, "Settings should preserve interface language")
    expect(decoded.themeMode == .dark, "Settings should preserve theme mode")

    let hiddenEntrypoints = AppSettings(showMenuBarIcon: false, showDockIcon: false)
    expect(hiddenEntrypoints.showMenuBarIcon, "Settings should keep at least one visible app entry point")
    expect(!hiddenEntrypoints.showDockIcon, "Settings should not force Dock icon when restoring menu bar icon")

    let invalidData = Data(#"{"hotkey":"command+shift+x","maxHistoryCount":0,"retentionDays":-12}"#.utf8)
    let invalidSettings = try JSONDecoder.litePaste.decode(AppSettings.self, from: invalidData)
    expect(invalidSettings.hotkey == "command+shift+v", "Settings should normalize invalid panel hotkey")
    expect(invalidSettings.maxHistoryCount == 1, "Settings should normalize invalid max history count")
    expect(invalidSettings.retentionDays == 0, "Settings should normalize invalid retention days")

    let invalidInit = AppSettings(hotkey: "invalid", maxHistoryCount: -50, retentionDays: -7)
    expect(invalidInit.hotkey == "command+shift+v", "Settings init should normalize panel hotkey")
    expect(invalidInit.maxHistoryCount == 1, "Settings init should normalize max history count")
    expect(invalidInit.retentionDays == 0, "Settings init should normalize retention days")
    expect(
      AppSettings(panelPosition: .statusItem).panelPosition == .edgeBottom,
      "Settings init should migrate legacy status item position"
    )
    expect(
      AppSettings(panelPosition: .mouseScreenCenter).panelPosition == .screenCenter,
      "Settings init should migrate legacy mouse center position"
    )

    expect(
      AppSettings(hotkey: " Command + Option + Space ").hotkey == "command+option+space",
      "Settings init should normalize panel hotkey formatting"
    )
    expect(
      PanelHotkeyCatalog.normalized(" Command + Option + Space ") == "command+option+space",
      "Panel hotkey catalog should normalize valid formatting"
    )
    expect(
      PanelHotkeyCatalog.normalized("command+option+shift+v") == "command+option+shift+v",
      "Panel hotkey catalog should include the dev default shortcut"
    )
    expect(
      PanelHotkeyCatalog.normalized("Option + Command + Shift + V") == "command+option+shift+v",
      "Panel hotkey catalog should normalize modifier order"
    )
    expect(
      PanelHotkeyCatalog.displayName(for: AppFlavor.dev.defaultPanelHotkey) == "⌘⌥⇧V",
      "Panel hotkey catalog should display the dev default shortcut"
    )
    expect(
      ClipboardQuickAction.displayOrder.contains(.pastePlainText),
      "Quick action order should include plain-text paste"
    )
    expect(PanelHotkeyCatalog.normalized("control+space") == nil, "Panel hotkey catalog should reject unknown hotkeys")
  } catch {
    fatalError("Settings compatibility check failed: \(error)")
  }
}
