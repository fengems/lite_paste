import Foundation

public enum PanelHotkeyCatalog {
  public static let hotkeys = [
    "command+shift+v",
    "command+option+v",
    "command+shift+space",
    "command+option+space"
  ]

  public static func displayName(for hotkey: String) -> String {
    switch hotkey.lowercased() {
    case "command+shift+v":
      "⌘⇧V"
    case "command+option+v":
      "⌘⌥V"
    case "command+shift+space":
      "⌘⇧Space"
    case "command+option+space":
      "⌘⌥Space"
    default:
      hotkey
    }
  }
}
