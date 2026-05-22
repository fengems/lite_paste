import AppKit
import Foundation
import LitePasteCore

@MainActor
enum NoteEditor {
  static func edit(record: ClipboardRecord) -> String? {
    let alert = NSAlert()
    alert.messageText = "编辑备注"
    alert.informativeText = record.title
    alert.addButton(withTitle: "保存")
    alert.addButton(withTitle: "取消")
    alert.alertStyle = .informational

    let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 420, height: 120))
    textView.string = record.note
    textView.font = .systemFont(ofSize: 13)
    textView.isVerticallyResizable = true
    textView.textContainerInset = NSSize(width: 8, height: 8)

    let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 420, height: 120))
    scrollView.borderType = .bezelBorder
    scrollView.hasVerticalScroller = true
    scrollView.documentView = textView
    alert.accessoryView = scrollView

    guard alert.runModal() == .alertFirstButtonReturn else {
      return nil
    }

    return textView.string
  }
}

