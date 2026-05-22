import Foundation

public enum PanelHotkeyCatalog {
  public static let hotkeys = [
    "command+shift+v",
    "command+option+v",
    "command+shift+space",
    "command+option+space"
  ]

  public static func normalized(_ hotkey: String) -> String? {
    let value = hotkey
      .split(separator: "+")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
      .filter { !$0.isEmpty }
      .joined(separator: "+")

    return hotkeys.contains(value) ? value : nil
  }

  public static func displayName(for hotkey: String) -> String {
    switch normalized(hotkey) ?? hotkey.lowercased() {
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
