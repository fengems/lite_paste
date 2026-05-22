import AppKit
import Foundation
import LitePasteCore

enum PinShortcutEditResult {
  case save(String?)
  case cancel
}

@MainActor
enum PinShortcutEditor {
  static func edit(record: ClipboardRecord, usedShortcuts: Set<String>) -> PinShortcutEditResult {
    let alert = NSAlert()
    alert.messageText = "设置置顶快捷键"
    alert.informativeText = record.title
    alert.addButton(withTitle: "保存")
    alert.addButton(withTitle: "取消")
    alert.alertStyle = .informational

    let popUpButton = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 260, height: 30))
    popUpButton.addItem(withTitle: "无")
    popUpButton.lastItem?.representedObject = ""

    for shortcut in PinShortcutCatalog.shortcuts {
      let title = PinShortcutCatalog.displayName(for: shortcut)
      popUpButton.addItem(withTitle: usedShortcuts.contains(shortcut) ? "\(title)（已占用）" : title)
      popUpButton.lastItem?.representedObject = shortcut
      popUpButton.lastItem?.isEnabled = !usedShortcuts.contains(shortcut)
    }

    if let currentShortcut = record.pinShortcut,
       let item = popUpButton.itemArray.first(where: { $0.representedObject as? String == currentShortcut }) {
      popUpButton.select(item)
    } else if let firstAvailable = PinShortcutCatalog.firstAvailable(excluding: usedShortcuts),
              let item = popUpButton.itemArray.first(where: { $0.representedObject as? String == firstAvailable }) {
      popUpButton.select(item)
    } else {
      popUpButton.selectItem(at: 0)
    }

    alert.accessoryView = popUpButton

    guard alert.runModal() == .alertFirstButtonReturn else {
      return .cancel
    }

    let shortcut = popUpButton.selectedItem?.representedObject as? String
    return .save(shortcut?.isEmpty == true ? nil : shortcut)
  }
}
