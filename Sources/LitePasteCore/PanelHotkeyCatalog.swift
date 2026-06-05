import Foundation

public enum PanelHotkeyCatalog {
  public static let hotkeys = [
    "command+shift+v",
    "command+option+v",
    "command+option+shift+v",
    "command+shift+space",
    "command+option+space"
  ]

  public static func normalized(_ hotkey: String) -> String? {
    let parts = hotkey
      .split(separator: "+")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
      .filter { !$0.isEmpty }
    let modifiers = ["command", "option", "shift", "control"]
    let keys = parts.filter { !modifiers.contains($0) }

    guard keys.count == 1 else {
      return nil
    }

    let canonical = (modifiers.filter { parts.contains($0) } + [keys[0]])
      .joined(separator: "+")

    return hotkeys.contains(canonical) ? canonical : nil
  }

  public static func displayName(for hotkey: String) -> String {
    switch normalized(hotkey) ?? hotkey.lowercased() {
    case "command+shift+v":
      "⌘⇧V"
    case "command+option+v":
      "⌘⌥V"
    case "command+option+shift+v":
      "⌘⌥⇧V"
    case "command+shift+space":
      "⌘⇧Space"
    case "command+option+space":
      "⌘⌥Space"
    default:
      hotkey
    }
  }
}
