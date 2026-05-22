import Foundation

public enum PinShortcutCatalog {
  public static let shortcuts: [String] = (1...9).map {
    "command+option+\($0)"
  }

  public static func displayName(for shortcut: String) -> String {
    switch shortcut.lowercased() {
    case "command+option+1":
      "⌘⌥1"
    case "command+option+2":
      "⌘⌥2"
    case "command+option+3":
      "⌘⌥3"
    case "command+option+4":
      "⌘⌥4"
    case "command+option+5":
      "⌘⌥5"
    case "command+option+6":
      "⌘⌥6"
    case "command+option+7":
      "⌘⌥7"
    case "command+option+8":
      "⌘⌥8"
    case "command+option+9":
      "⌘⌥9"
    default:
      shortcut
    }
  }

  public static func firstAvailable(excluding usedShortcuts: Set<String>) -> String? {
    shortcuts.first { !usedShortcuts.contains($0) }
  }
}
