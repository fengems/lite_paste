import AppKit
import Foundation

struct PasteboardSnapshot {
  private struct Item {
    var contents: [(NSPasteboard.PasteboardType, Data)]
  }

  private let items: [Item]

  init(pasteboard: NSPasteboard) {
    items = pasteboard.pasteboardItems?.map { item in
      Item(
        contents: item.types.compactMap { type in
          guard let data = item.data(forType: type) else {
            return nil
          }
          return (type, data)
        }
      )
    } ?? []
  }

  @discardableResult
  func restore(to pasteboard: NSPasteboard) -> Bool {
    pasteboard.clearContents()

    guard !items.isEmpty else {
      return true
    }

    let pasteboardItems = items.map { item in
      let pasteboardItem = NSPasteboardItem()
      for (type, data) in item.contents {
        pasteboardItem.setData(data, forType: type)
      }
      return pasteboardItem
    }

    return pasteboard.writeObjects(pasteboardItems)
  }
}
