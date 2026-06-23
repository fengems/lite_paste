import Foundation

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

public enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
  case system
  case zhHans
  case zhHant
  case ja
  case ko
  case en

  public var id: String {
    rawValue
  }
}

public enum AutoPasteMode: String, Codable, Equatable, Sendable {
  case copyOnly
  case paste
}
