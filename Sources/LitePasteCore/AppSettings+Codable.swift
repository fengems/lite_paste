import Foundation

extension AppSettings {
  private enum CodingKeys: String, CodingKey {
    case hotkey
    case viewMode
    case panelPosition
    case maxHistoryCount
    case retentionDays
    case autoPasteMode
    case copySoundEnabled
    case imageOCREnabled
    case copyPlainTextByDefault
    case pastePlainTextByDefault
    case sanitizesSystemClipboardOnCopy
    case pastePlainByDefault
    case restoreClipboardAfterPaste
    case preserveLargeRichTextFormats
    case visibleQuickActions
    case autoFavoriteAfterNote
    case moveDuplicatesToTop
    case clearSearchOnOpen
    case focusSearchOnOpen
    case coverMenuBarWhenEdgeAttached
    case isMonitoringPaused
    case privacyMode
    case launchAtLogin
    case showMenuBarIcon
    case showDockIcon
    case interfaceLanguage
    case themeMode
  }

  public init(from decoder: Decoder) throws {
    let defaults = AppSettings()
    let container = try decoder.container(keyedBy: CodingKeys.self)

    hotkey = Self.normalizedHotkey(
      try container.decodeIfPresent(String.self, forKey: .hotkey) ?? defaults.hotkey
    )
    viewMode = try container.decodeIfPresent(ClipboardPanelViewMode.self, forKey: .viewMode) ?? defaults.viewMode
    panelPosition = Self.normalizedPanelPosition(
      try container.decodeIfPresent(PanelPosition.self, forKey: .panelPosition) ?? defaults.panelPosition
    )
    maxHistoryCount = Self.normalizedMaxHistoryCount(
      try container.decodeIfPresent(Int.self, forKey: .maxHistoryCount) ?? defaults.maxHistoryCount
    )
    retentionDays = Self.normalizedRetentionDays(
      try container.decodeIfPresent(Int.self, forKey: .retentionDays) ?? defaults.retentionDays
    )
    autoPasteMode = try container.decodeIfPresent(AutoPasteMode.self, forKey: .autoPasteMode) ?? defaults.autoPasteMode
    copySoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .copySoundEnabled) ?? defaults.copySoundEnabled
    imageOCREnabled = try container.decodeIfPresent(Bool.self, forKey: .imageOCREnabled) ?? defaults.imageOCREnabled
    let legacyPastePlainByDefault = try container.decodeIfPresent(Bool.self, forKey: .pastePlainByDefault)
    copyPlainTextByDefault =
      try container.decodeIfPresent(Bool.self, forKey: .copyPlainTextByDefault) ??
      legacyPastePlainByDefault ??
      defaults.copyPlainTextByDefault
    pastePlainTextByDefault =
      try container.decodeIfPresent(Bool.self, forKey: .pastePlainTextByDefault) ??
      legacyPastePlainByDefault ??
      defaults.pastePlainTextByDefault
    sanitizesSystemClipboardOnCopy =
      try container.decodeIfPresent(Bool.self, forKey: .sanitizesSystemClipboardOnCopy) ??
      defaults.sanitizesSystemClipboardOnCopy
    restoreClipboardAfterPaste =
      try container.decodeIfPresent(Bool.self, forKey: .restoreClipboardAfterPaste) ??
      defaults.restoreClipboardAfterPaste
    preserveLargeRichTextFormats =
      try container.decodeIfPresent(Bool.self, forKey: .preserveLargeRichTextFormats) ??
      defaults.preserveLargeRichTextFormats
    visibleQuickActions =
      try container.decodeIfPresent(Set<ClipboardQuickAction>.self, forKey: .visibleQuickActions) ??
      defaults.visibleQuickActions
    autoFavoriteAfterNote =
      try container.decodeIfPresent(Bool.self, forKey: .autoFavoriteAfterNote) ??
      defaults.autoFavoriteAfterNote
    moveDuplicatesToTop = try container.decodeIfPresent(Bool.self, forKey: .moveDuplicatesToTop) ?? defaults.moveDuplicatesToTop
    clearSearchOnOpen = try container.decodeIfPresent(Bool.self, forKey: .clearSearchOnOpen) ?? defaults.clearSearchOnOpen
    focusSearchOnOpen = try container.decodeIfPresent(Bool.self, forKey: .focusSearchOnOpen) ?? defaults.focusSearchOnOpen
    coverMenuBarWhenEdgeAttached =
      try container.decodeIfPresent(Bool.self, forKey: .coverMenuBarWhenEdgeAttached) ??
      defaults.coverMenuBarWhenEdgeAttached
    isMonitoringPaused =
      try container.decodeIfPresent(Bool.self, forKey: .isMonitoringPaused) ??
      container.decodeIfPresent(Bool.self, forKey: .privacyMode) ??
      defaults.isMonitoringPaused
    launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? defaults.launchAtLogin
    let appVisibility = Self.normalizedAppVisibility(
      showMenuBarIcon: try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? defaults.showMenuBarIcon,
      showDockIcon: try container.decodeIfPresent(Bool.self, forKey: .showDockIcon) ?? defaults.showDockIcon
    )
    showMenuBarIcon = appVisibility.showMenuBarIcon
    showDockIcon = appVisibility.showDockIcon
    interfaceLanguage =
      try container.decodeIfPresent(AppLanguage.self, forKey: .interfaceLanguage) ??
      defaults.interfaceLanguage
    themeMode = try container.decodeIfPresent(AppThemeMode.self, forKey: .themeMode) ?? defaults.themeMode
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(hotkey, forKey: .hotkey)
    try container.encode(viewMode, forKey: .viewMode)
    try container.encode(panelPosition, forKey: .panelPosition)
    try container.encode(maxHistoryCount, forKey: .maxHistoryCount)
    try container.encode(retentionDays, forKey: .retentionDays)
    try container.encode(autoPasteMode, forKey: .autoPasteMode)
    try container.encode(copySoundEnabled, forKey: .copySoundEnabled)
    try container.encode(imageOCREnabled, forKey: .imageOCREnabled)
    try container.encode(copyPlainTextByDefault, forKey: .copyPlainTextByDefault)
    try container.encode(pastePlainTextByDefault, forKey: .pastePlainTextByDefault)
    try container.encode(sanitizesSystemClipboardOnCopy, forKey: .sanitizesSystemClipboardOnCopy)
    try container.encode(restoreClipboardAfterPaste, forKey: .restoreClipboardAfterPaste)
    try container.encode(preserveLargeRichTextFormats, forKey: .preserveLargeRichTextFormats)
    try container.encode(visibleQuickActions, forKey: .visibleQuickActions)
    try container.encode(autoFavoriteAfterNote, forKey: .autoFavoriteAfterNote)
    try container.encode(moveDuplicatesToTop, forKey: .moveDuplicatesToTop)
    try container.encode(clearSearchOnOpen, forKey: .clearSearchOnOpen)
    try container.encode(focusSearchOnOpen, forKey: .focusSearchOnOpen)
    try container.encode(coverMenuBarWhenEdgeAttached, forKey: .coverMenuBarWhenEdgeAttached)
    try container.encode(isMonitoringPaused, forKey: .isMonitoringPaused)
    try container.encode(launchAtLogin, forKey: .launchAtLogin)
    try container.encode(showMenuBarIcon, forKey: .showMenuBarIcon)
    try container.encode(showDockIcon, forKey: .showDockIcon)
    try container.encode(interfaceLanguage, forKey: .interfaceLanguage)
    try container.encode(themeMode, forKey: .themeMode)
  }
}
