import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
  case clipboard
  case history
  case general
  case appearance
  case hotkeys
  case backup
  case about

  var id: String {
    rawValue
  }

  var title: String {
    switch self {
    case .clipboard:
      AppText.value("剪贴板", "Clipboard")
    case .history:
      AppText.value("历史记录", "History")
    case .general:
      AppText.value("通用设置", "General")
    case .appearance:
      AppText.value("外观设置", "Appearance")
    case .hotkeys:
      AppText.value("快捷键", "Shortcuts")
    case .backup:
      AppText.value("数据备份", "Backups")
    case .about:
      AppText.value("关于", "About")
    }
  }

  var systemImage: String {
    switch self {
    case .clipboard:
      "clipboard"
    case .history:
      "clock.arrow.circlepath"
    case .general:
      "gearshape"
    case .appearance:
      "paintpalette"
    case .hotkeys:
      "keyboard"
    case .backup:
      "externaldrive"
    case .about:
      "info.circle"
    }
  }

  var accentColor: Color {
    switch self {
    case .clipboard:
      Color(nsColor: NSColor(calibratedRed: 0.34, green: 0.48, blue: 0.68, alpha: 1))
    case .history:
      Color(nsColor: NSColor(calibratedRed: 0.30, green: 0.56, blue: 0.62, alpha: 1))
    case .general:
      Color(nsColor: NSColor(calibratedRed: 0.43, green: 0.47, blue: 0.66, alpha: 1))
    case .appearance:
      Color(nsColor: NSColor(calibratedRed: 0.48, green: 0.45, blue: 0.60, alpha: 1))
    case .hotkeys:
      Color(nsColor: NSColor(calibratedRed: 0.54, green: 0.43, blue: 0.64, alpha: 1))
    case .backup:
      Color(nsColor: NSColor(calibratedRed: 0.67, green: 0.49, blue: 0.32, alpha: 1))
    case .about:
      Color(nsColor: NSColor(calibratedRed: 0.38, green: 0.57, blue: 0.42, alpha: 1))
    }
  }
}
