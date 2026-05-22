import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
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
  public var moveDuplicatesToTop: Bool
  public var clearSearchOnOpen: Bool
  public var focusSearchOnOpen: Bool
  public var privacyMode: Bool
  public var launchAtLogin: Bool

  public init(
    hotkey: String = "command+shift+v",
    viewMode: ClipboardPanelViewMode = .card,
    panelPosition: PanelPosition = .statusItem,
    maxHistoryCount: Int = 1_000,
    retentionDays: Int = 0,
    enabledTypes: Set<ClipboardKind> = Set(ClipboardKind.allCases),
    ignoredPasteboardTypes: Set<String> = PrivacyFilter.defaultIgnoredPasteboardTypes,
    ignoredApps: Set<String> = PrivacyFilter.defaultIgnoredApps,
    autoPasteMode: AutoPasteMode = .copyOnly,
    pastePlainByDefault: Bool = false,
    restoreClipboardAfterPaste: Bool = false,
    moveDuplicatesToTop: Bool = true,
    clearSearchOnOpen: Bool = true,
    focusSearchOnOpen: Bool = true,
    privacyMode: Bool = false,
    launchAtLogin: Bool = false
  ) {
    self.hotkey = hotkey
    self.viewMode = viewMode
    self.panelPosition = panelPosition
    self.maxHistoryCount = Self.normalizedMaxHistoryCount(maxHistoryCount)
    self.retentionDays = Self.normalizedRetentionDays(retentionDays)
    self.enabledTypes = enabledTypes
    self.ignoredPasteboardTypes = ignoredPasteboardTypes
    self.ignoredApps = ignoredApps
    self.autoPasteMode = autoPasteMode
    self.pastePlainByDefault = pastePlainByDefault
    self.restoreClipboardAfterPaste = restoreClipboardAfterPaste
    self.moveDuplicatesToTop = moveDuplicatesToTop
    self.clearSearchOnOpen = clearSearchOnOpen
    self.focusSearchOnOpen = focusSearchOnOpen
    self.privacyMode = privacyMode
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
    case moveDuplicatesToTop
    case clearSearchOnOpen
    case focusSearchOnOpen
    case privacyMode
    case launchAtLogin
  }

  public init(from decoder: Decoder) throws {
    let defaults = AppSettings()
    let container = try decoder.container(keyedBy: CodingKeys.self)

    hotkey = try container.decodeIfPresent(String.self, forKey: .hotkey) ?? defaults.hotkey
    viewMode = try container.decodeIfPresent(ClipboardPanelViewMode.self, forKey: .viewMode) ?? defaults.viewMode
    panelPosition = try container.decodeIfPresent(PanelPosition.self, forKey: .panelPosition) ?? defaults.panelPosition
    maxHistoryCount = Self.normalizedMaxHistoryCount(
      try container.decodeIfPresent(Int.self, forKey: .maxHistoryCount) ?? defaults.maxHistoryCount
    )
    retentionDays = Self.normalizedRetentionDays(
      try container.decodeIfPresent(Int.self, forKey: .retentionDays) ?? defaults.retentionDays
    )
    enabledTypes = try container.decodeIfPresent(Set<ClipboardKind>.self, forKey: .enabledTypes) ?? defaults.enabledTypes
    ignoredPasteboardTypes = try container.decodeIfPresent(Set<String>.self, forKey: .ignoredPasteboardTypes) ?? defaults.ignoredPasteboardTypes
    ignoredApps = try container.decodeIfPresent(Set<String>.self, forKey: .ignoredApps) ?? defaults.ignoredApps
    autoPasteMode = try container.decodeIfPresent(AutoPasteMode.self, forKey: .autoPasteMode) ?? defaults.autoPasteMode
    pastePlainByDefault = try container.decodeIfPresent(Bool.self, forKey: .pastePlainByDefault) ?? defaults.pastePlainByDefault
    restoreClipboardAfterPaste = try container.decodeIfPresent(Bool.self, forKey: .restoreClipboardAfterPaste) ?? defaults.restoreClipboardAfterPaste
    moveDuplicatesToTop = try container.decodeIfPresent(Bool.self, forKey: .moveDuplicatesToTop) ?? defaults.moveDuplicatesToTop
    clearSearchOnOpen = try container.decodeIfPresent(Bool.self, forKey: .clearSearchOnOpen) ?? defaults.clearSearchOnOpen
    focusSearchOnOpen = try container.decodeIfPresent(Bool.self, forKey: .focusSearchOnOpen) ?? defaults.focusSearchOnOpen
    privacyMode = try container.decodeIfPresent(Bool.self, forKey: .privacyMode) ?? defaults.privacyMode
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
    try container.encode(moveDuplicatesToTop, forKey: .moveDuplicatesToTop)
    try container.encode(clearSearchOnOpen, forKey: .clearSearchOnOpen)
    try container.encode(focusSearchOnOpen, forKey: .focusSearchOnOpen)
    try container.encode(privacyMode, forKey: .privacyMode)
    try container.encode(launchAtLogin, forKey: .launchAtLogin)
  }

  private static func normalizedMaxHistoryCount(_ value: Int) -> Int {
    max(value, 1)
  }

  private static func normalizedRetentionDays(_ value: Int) -> Int {
    max(value, 0)
  }
}

public enum ClipboardPanelViewMode: String, Codable, Equatable, Sendable {
  case card
  case list
}

public enum PanelPosition: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
  case statusItem
  case mouseScreenCenter

  public var id: String {
    rawValue
  }

  public var displayName: String {
    switch self {
    case .statusItem:
      "菜单栏下方"
    case .mouseScreenCenter:
      "鼠标所在屏幕居中"
    }
  }
}

public enum AutoPasteMode: String, Codable, Equatable, Sendable {
  case copyOnly
  case paste
}
