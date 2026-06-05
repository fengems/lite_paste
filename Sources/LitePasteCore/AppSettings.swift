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
  public var pastePlainByDefault: Bool
  public var restoreClipboardAfterPaste: Bool
  public var preserveLargeRichTextFormats: Bool
  public var moveDuplicatesToTop: Bool
  public var clearSearchOnOpen: Bool
  public var focusSearchOnOpen: Bool
  public var coverMenuBarWhenEdgeAttached: Bool
  public var isMonitoringPaused: Bool
  public var launchAtLogin: Bool

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
    pastePlainByDefault: Bool = false,
    restoreClipboardAfterPaste: Bool = false,
    preserveLargeRichTextFormats: Bool = false,
    moveDuplicatesToTop: Bool = true,
    clearSearchOnOpen: Bool = true,
    focusSearchOnOpen: Bool = true,
    coverMenuBarWhenEdgeAttached: Bool = true,
    isMonitoringPaused: Bool = false,
    launchAtLogin: Bool = false
  ) {
    self.hotkey = Self.normalizedHotkey(hotkey)
    self.viewMode = viewMode
    self.panelPosition = Self.normalizedPanelPosition(panelPosition)
    self.maxHistoryCount = Self.normalizedMaxHistoryCount(maxHistoryCount)
    self.retentionDays = Self.normalizedRetentionDays(retentionDays)
    self.enabledTypes = enabledTypes
    self.ignoredPasteboardTypes = Self.normalizedIgnoredPasteboardTypes(ignoredPasteboardTypes)
    self.ignoredApps = ignoredApps
    self.autoPasteMode = autoPasteMode
    self.pastePlainByDefault = pastePlainByDefault
    self.restoreClipboardAfterPaste = restoreClipboardAfterPaste
    self.preserveLargeRichTextFormats = preserveLargeRichTextFormats
    self.moveDuplicatesToTop = moveDuplicatesToTop
    self.clearSearchOnOpen = clearSearchOnOpen
    self.focusSearchOnOpen = focusSearchOnOpen
    self.coverMenuBarWhenEdgeAttached = coverMenuBarWhenEdgeAttached
    self.isMonitoringPaused = isMonitoringPaused
    self.launchAtLogin = launchAtLogin
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
    case pastePlainByDefault
    case restoreClipboardAfterPaste
    case preserveLargeRichTextFormats
    case moveDuplicatesToTop
    case clearSearchOnOpen
    case focusSearchOnOpen
    case coverMenuBarWhenEdgeAttached
    case isMonitoringPaused
    case privacyMode
    case launchAtLogin
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
    pastePlainByDefault = try container.decodeIfPresent(Bool.self, forKey: .pastePlainByDefault) ?? defaults.pastePlainByDefault
    restoreClipboardAfterPaste = try container.decodeIfPresent(Bool.self, forKey: .restoreClipboardAfterPaste) ?? defaults.restoreClipboardAfterPaste
    preserveLargeRichTextFormats =
      try container.decodeIfPresent(Bool.self, forKey: .preserveLargeRichTextFormats) ??
      defaults.preserveLargeRichTextFormats
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
    try container.encode(pastePlainByDefault, forKey: .pastePlainByDefault)
    try container.encode(restoreClipboardAfterPaste, forKey: .restoreClipboardAfterPaste)
    try container.encode(preserveLargeRichTextFormats, forKey: .preserveLargeRichTextFormats)
    try container.encode(moveDuplicatesToTop, forKey: .moveDuplicatesToTop)
    try container.encode(clearSearchOnOpen, forKey: .clearSearchOnOpen)
    try container.encode(focusSearchOnOpen, forKey: .focusSearchOnOpen)
    try container.encode(coverMenuBarWhenEdgeAttached, forKey: .coverMenuBarWhenEdgeAttached)
    try container.encode(isMonitoringPaused, forKey: .isMonitoringPaused)
    try container.encode(launchAtLogin, forKey: .launchAtLogin)
  }

  public mutating func normalize() {
    hotkey = Self.normalizedHotkey(hotkey)
    panelPosition = Self.normalizedPanelPosition(panelPosition)
    maxHistoryCount = Self.normalizedMaxHistoryCount(maxHistoryCount)
    retentionDays = Self.normalizedRetentionDays(retentionDays)
    ignoredPasteboardTypes = Self.normalizedIgnoredPasteboardTypes(ignoredPasteboardTypes)
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
      .cursor
    case .edgeBottom, .edgeTop, .edgeLeft, .edgeRight, .cursor:
      value
    }
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
  case bottomDrawer
  case statusItem
  case mouseScreenCenter

  public static var allCases: [PanelPosition] {
    [.edgeBottom, .edgeTop, .edgeLeft, .edgeRight, .cursor]
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
    case .cursor, .mouseScreenCenter:
      false
    }
  }

  public var isVerticalEdge: Bool {
    switch self {
    case .edgeLeft, .edgeRight:
      true
    case .edgeBottom, .edgeTop, .cursor, .bottomDrawer, .statusItem, .mouseScreenCenter:
      false
    }
  }
}

public enum AutoPasteMode: String, Codable, Equatable, Sendable {
  case copyOnly
  case paste
}
