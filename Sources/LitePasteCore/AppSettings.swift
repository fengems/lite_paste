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
  public var enabledTypes: Set<ClipboardKind>
  public var ignoredPasteboardTypes: Set<String>
  public var ignoredApps: Set<String>
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
  public var themeMode: AppThemeMode

  public init(
    hotkey: String = AppSettings.defaultHotkey,
    viewMode: ClipboardPanelViewMode = .card,
    panelPosition: PanelPosition = .edgeBottom,
    maxHistoryCount: Int = 1_000,
    retentionDays: Int = 0,
    enabledTypes: Set<ClipboardKind> = Set(ClipboardKind.allCases),
    ignoredPasteboardTypes: Set<String> = PrivacyFilter.defaultIgnoredPasteboardTypes,
    ignoredApps: Set<String> = PrivacyFilter.defaultIgnoredApps,
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
    self.enabledTypes = enabledTypes
    self.ignoredPasteboardTypes = Self.normalizedIgnoredPasteboardTypes(ignoredPasteboardTypes)
    self.ignoredApps = ignoredApps
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
    self.themeMode = themeMode
  }

  private enum CodingKeys: String, CodingKey {
    case hotkey
    case viewMode
    case panelPosition
    case maxHistoryCount
    case retentionDays
    case enabledTypes
    case ignoredPasteboardTypes
    case ignoredApps
    case autoPasteMode
    case copySoundEnabled
    case imageOCREnabled
    case copyPlainTextByDefault
    case pastePlainTextByDefault
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
    enabledTypes = try container.decodeIfPresent(Set<ClipboardKind>.self, forKey: .enabledTypes) ?? defaults.enabledTypes
    ignoredPasteboardTypes = Self.normalizedIgnoredPasteboardTypes(
      try container.decodeIfPresent(Set<String>.self, forKey: .ignoredPasteboardTypes) ?? defaults.ignoredPasteboardTypes
    )
    ignoredApps = try container.decodeIfPresent(Set<String>.self, forKey: .ignoredApps) ?? defaults.ignoredApps
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
    restoreClipboardAfterPaste = try container.decodeIfPresent(Bool.self, forKey: .restoreClipboardAfterPaste) ?? defaults.restoreClipboardAfterPaste
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
    themeMode = try container.decodeIfPresent(AppThemeMode.self, forKey: .themeMode) ?? defaults.themeMode
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(hotkey, forKey: .hotkey)
    try container.encode(viewMode, forKey: .viewMode)
    try container.encode(panelPosition, forKey: .panelPosition)
    try container.encode(maxHistoryCount, forKey: .maxHistoryCount)
    try container.encode(retentionDays, forKey: .retentionDays)
    try container.encode(enabledTypes, forKey: .enabledTypes)
    try container.encode(ignoredPasteboardTypes, forKey: .ignoredPasteboardTypes)
    try container.encode(ignoredApps, forKey: .ignoredApps)
    try container.encode(autoPasteMode, forKey: .autoPasteMode)
    try container.encode(copySoundEnabled, forKey: .copySoundEnabled)
    try container.encode(imageOCREnabled, forKey: .imageOCREnabled)
    try container.encode(copyPlainTextByDefault, forKey: .copyPlainTextByDefault)
    try container.encode(pastePlainTextByDefault, forKey: .pastePlainTextByDefault)
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
    try container.encode(themeMode, forKey: .themeMode)
  }

  public mutating func normalize() {
    hotkey = Self.normalizedHotkey(hotkey)
    panelPosition = Self.normalizedPanelPosition(panelPosition)
    maxHistoryCount = Self.normalizedMaxHistoryCount(maxHistoryCount)
    retentionDays = Self.normalizedRetentionDays(retentionDays)
    ignoredPasteboardTypes = Self.normalizedIgnoredPasteboardTypes(ignoredPasteboardTypes)
    let appVisibility = Self.normalizedAppVisibility(
      showMenuBarIcon: showMenuBarIcon,
      showDockIcon: showDockIcon
    )
    showMenuBarIcon = appVisibility.showMenuBarIcon
    showDockIcon = appVisibility.showDockIcon
  }

  private static func normalizedMaxHistoryCount(_ value: Int) -> Int {
    max(value, 1)
  }

  private static func normalizedRetentionDays(_ value: Int) -> Int {
    max(value, 0)
  }

  private static func normalizedHotkey(_ value: String) -> String {
    PanelHotkeyCatalog.normalized(value) ?? defaultHotkey
  }

  private static func normalizedPanelPosition(_ value: PanelPosition) -> PanelPosition {
    switch value {
    case .statusItem, .bottomDrawer:
      .edgeBottom
    case .mouseScreenCenter:
      .screenCenter
    case .edgeBottom, .edgeTop, .edgeLeft, .edgeRight, .cursor, .screenCenter:
      value
    }
  }

  private static func normalizedAppVisibility(
    showMenuBarIcon: Bool,
    showDockIcon: Bool
  ) -> (showMenuBarIcon: Bool, showDockIcon: Bool) {
    if !showMenuBarIcon && !showDockIcon {
      return (true, false)
    }

    return (showMenuBarIcon, showDockIcon)
  }

  private static func normalizedIgnoredPasteboardTypes(_ value: Set<String>) -> Set<String> {
    guard legacyDefaultIgnoredPasteboardTypes.isSubset(of: value) else {
      return value
    }

    return value.subtracting(legacyRecordablePasteboardTypes)
  }

  private static let legacyRecordablePasteboardTypes: Set<String> = [
    "com.apple.finder.node",
    "com.apple.pasteboard.promised-file-url",
    "com.apple.webarchive",
    "com.apple.flat-rtfd"
  ]

  private static let legacyDefaultIgnoredPasteboardTypes =
    PrivacyFilter.defaultIgnoredPasteboardTypes.union(legacyRecordablePasteboardTypes)
}

public enum ClipboardPanelViewMode: String, Codable, Equatable, Sendable {
  case card
  case list
}

public enum PanelPosition: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
  case edgeBottom
  case edgeTop
  case edgeLeft
  case edgeRight
  case cursor
  case screenCenter
  case bottomDrawer
  case statusItem
  case mouseScreenCenter

  public static var allCases: [PanelPosition] {
    [.edgeBottom, .edgeTop, .edgeLeft, .edgeRight, .screenCenter, .cursor]
  }

  public var id: String {
    rawValue
  }

  public var displayName: String {
    switch self {
    case .edgeBottom:
      "靠下"
    case .edgeTop:
      "靠上"
    case .edgeLeft:
      "靠左"
    case .edgeRight:
      "靠右"
    case .cursor:
      "跟随鼠标指针"
    case .screenCenter:
      "屏幕中心"
    case .bottomDrawer:
      "底部抽屉"
    case .statusItem:
      "菜单栏下方"
    case .mouseScreenCenter:
      "鼠标所在屏幕居中"
    }
  }

  public var isEdgeAttached: Bool {
    switch self {
    case .edgeBottom, .edgeTop, .edgeLeft, .edgeRight, .bottomDrawer, .statusItem:
      true
    case .cursor, .screenCenter, .mouseScreenCenter:
      false
    }
  }

  public var isVerticalEdge: Bool {
    switch self {
    case .edgeLeft, .edgeRight:
      true
    case .edgeBottom, .edgeTop, .cursor, .screenCenter, .bottomDrawer, .statusItem, .mouseScreenCenter:
      false
    }
  }
}

public enum ClipboardQuickAction: String, Codable, CaseIterable, Identifiable, Sendable {
  case favorite
  case pin
  case copy
  case copyPlainText
  case paste
  case pastePlainText
  case note
  case delete
  case external

  public static let defaultVisibleActions: Set<ClipboardQuickAction> = [.favorite, .pin]
  public static let displayOrder: [ClipboardQuickAction] = [
    .favorite,
    .pin,
    .copy,
    .copyPlainText,
    .paste,
    .pastePlainText,
    .note,
    .external,
    .delete
  ]

  public var id: String {
    rawValue
  }
}

public enum AppThemeMode: String, Codable, CaseIterable, Identifiable, Sendable {
  case system
  case light
  case dark

  public var id: String {
    rawValue
  }
}

public enum AutoPasteMode: String, Codable, Equatable, Sendable {
  case copyOnly
  case paste
}
