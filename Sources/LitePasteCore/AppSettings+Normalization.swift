import Foundation

extension AppSettings {
  public mutating func normalize() {
    hotkey = Self.normalizedHotkey(hotkey)
    panelPosition = Self.normalizedPanelPosition(panelPosition)
    maxHistoryCount = Self.normalizedMaxHistoryCount(maxHistoryCount)
    retentionDays = Self.normalizedRetentionDays(retentionDays)
    let appVisibility = Self.normalizedAppVisibility(
      showMenuBarIcon: showMenuBarIcon,
      showDockIcon: showDockIcon
    )
    showMenuBarIcon = appVisibility.showMenuBarIcon
    showDockIcon = appVisibility.showDockIcon
    tablePlainTextSeparator = TablePlainTextFormatter.normalizedSeparator(tablePlainTextSeparator)
  }

  static func normalizedMaxHistoryCount(_ value: Int) -> Int {
    max(value, 1)
  }

  static func normalizedRetentionDays(_ value: Int) -> Int {
    max(value, 0)
  }

  static func normalizedHotkey(_ value: String) -> String {
    PanelHotkeyCatalog.normalized(value) ?? defaultHotkey
  }

  static func normalizedPanelPosition(_ value: PanelPosition) -> PanelPosition {
    switch value {
    case .statusItem, .bottomDrawer:
      .edgeBottom
    case .mouseScreenCenter:
      .screenCenter
    case .edgeBottom, .edgeTop, .edgeLeft, .edgeRight, .cursor, .screenCenter:
      value
    }
  }

  static func normalizedAppVisibility(
    showMenuBarIcon: Bool,
    showDockIcon: Bool
  ) -> (showMenuBarIcon: Bool, showDockIcon: Bool) {
    if !showMenuBarIcon && !showDockIcon {
      return (true, false)
    }

    return (showMenuBarIcon, showDockIcon)
  }
}
