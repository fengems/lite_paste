import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
  public static var defaultHotkey: String {
    AppFlavor.current.defaultPanelHotkey
  }

  public var hotkey: String
  public var viewMode: ClipboardPanelViewMode
  public var panelPosition: PanelPosition
  public var maxHistoryCount: Int
  public var retentionDays: Int
  public var autoPasteMode: AutoPasteMode
  public var copySoundEnabled: Bool
  public var imageOCREnabled: Bool
  public var copyPlainTextByDefault: Bool
  public var pastePlainTextByDefault: Bool
  public var restoreClipboardAfterPaste: Bool
  public var preserveLargeRichTextFormats: Bool
  public var visibleQuickActions: Set<ClipboardQuickAction>
  public var autoFavoriteAfterNote: Bool
  public var moveDuplicatesToTop: Bool
  public var clearSearchOnOpen: Bool
  public var focusSearchOnOpen: Bool
  public var coverMenuBarWhenEdgeAttached: Bool
  public var isMonitoringPaused: Bool
  public var launchAtLogin: Bool
  public var showMenuBarIcon: Bool
  public var showDockIcon: Bool
  public var interfaceLanguage: AppLanguage
  public var themeMode: AppThemeMode

  public init(
    hotkey: String = AppSettings.defaultHotkey,
    viewMode: ClipboardPanelViewMode = .card,
    panelPosition: PanelPosition = .edgeBottom,
    maxHistoryCount: Int = 1_000,
    retentionDays: Int = 0,
    autoPasteMode: AutoPasteMode = .copyOnly,
    copySoundEnabled: Bool = false,
    imageOCREnabled: Bool = false,
    copyPlainTextByDefault: Bool = false,
    pastePlainTextByDefault: Bool = false,
    restoreClipboardAfterPaste: Bool = false,
    preserveLargeRichTextFormats: Bool = false,
    visibleQuickActions: Set<ClipboardQuickAction> = ClipboardQuickAction.defaultVisibleActions,
    autoFavoriteAfterNote: Bool = false,
    moveDuplicatesToTop: Bool = true,
    clearSearchOnOpen: Bool = true,
    focusSearchOnOpen: Bool = true,
    coverMenuBarWhenEdgeAttached: Bool = true,
    isMonitoringPaused: Bool = false,
    launchAtLogin: Bool = false,
    showMenuBarIcon: Bool = true,
    showDockIcon: Bool = false,
    interfaceLanguage: AppLanguage = .system,
    themeMode: AppThemeMode = .system
  ) {
    let normalizedVisibility = Self.normalizedAppVisibility(
      showMenuBarIcon: showMenuBarIcon,
      showDockIcon: showDockIcon
    )
    self.hotkey = Self.normalizedHotkey(hotkey)
    self.viewMode = viewMode
    self.panelPosition = Self.normalizedPanelPosition(panelPosition)
    self.maxHistoryCount = Self.normalizedMaxHistoryCount(maxHistoryCount)
    self.retentionDays = Self.normalizedRetentionDays(retentionDays)
    self.autoPasteMode = autoPasteMode
    self.copySoundEnabled = copySoundEnabled
    self.imageOCREnabled = imageOCREnabled
    self.copyPlainTextByDefault = copyPlainTextByDefault
    self.pastePlainTextByDefault = pastePlainTextByDefault
    self.restoreClipboardAfterPaste = restoreClipboardAfterPaste
    self.preserveLargeRichTextFormats = preserveLargeRichTextFormats
    self.visibleQuickActions = visibleQuickActions
    self.autoFavoriteAfterNote = autoFavoriteAfterNote
    self.moveDuplicatesToTop = moveDuplicatesToTop
    self.clearSearchOnOpen = clearSearchOnOpen
    self.focusSearchOnOpen = focusSearchOnOpen
    self.coverMenuBarWhenEdgeAttached = coverMenuBarWhenEdgeAttached
    self.isMonitoringPaused = isMonitoringPaused
    self.launchAtLogin = launchAtLogin
    self.showMenuBarIcon = normalizedVisibility.showMenuBarIcon
    self.showDockIcon = normalizedVisibility.showDockIcon
    self.interfaceLanguage = interfaceLanguage
    self.themeMode = themeMode
  }
}
