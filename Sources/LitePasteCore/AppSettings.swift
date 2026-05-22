import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
  public var hotkey: String
  public var viewMode: String
  public var maxHistoryCount: Int
  public var retentionDays: Int
  public var enabledTypes: Set<ClipboardKind>
  public var ignoredPasteboardTypes: Set<String>
  public var ignoredApps: Set<String>
  public var autoPasteMode: AutoPasteMode
  public var pastePlainByDefault: Bool
  public var privacyMode: Bool
  public var launchAtLogin: Bool

  public init(
    hotkey: String = "command+shift+v",
    viewMode: String = "card",
    maxHistoryCount: Int = 1_000,
    retentionDays: Int = 0,
    enabledTypes: Set<ClipboardKind> = Set(ClipboardKind.allCases),
    ignoredPasteboardTypes: Set<String> = PrivacyFilter.defaultIgnoredPasteboardTypes,
    ignoredApps: Set<String> = [],
    autoPasteMode: AutoPasteMode = .copyOnly,
    pastePlainByDefault: Bool = false,
    privacyMode: Bool = false,
    launchAtLogin: Bool = false
  ) {
    self.hotkey = hotkey
    self.viewMode = viewMode
    self.maxHistoryCount = maxHistoryCount
    self.retentionDays = retentionDays
    self.enabledTypes = enabledTypes
    self.ignoredPasteboardTypes = ignoredPasteboardTypes
    self.ignoredApps = ignoredApps
    self.autoPasteMode = autoPasteMode
    self.pastePlainByDefault = pastePlainByDefault
    self.privacyMode = privacyMode
    self.launchAtLogin = launchAtLogin
  }
}

public enum AutoPasteMode: String, Codable, Equatable, Sendable {
  case copyOnly
  case paste
}

