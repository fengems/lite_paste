import AppKit
import Foundation
import LitePasteCore

@MainActor
enum NoteEditor {
  static func edit(record: ClipboardRecord) -> String? {
    let alert = NSAlert()
    alert.messageText = AppText.value("编辑备注", "Edit Note")
    alert.informativeText = record.title
    alert.addButton(withTitle: AppText.value("保存", "Save"))
    alert.addButton(withTitle: AppText.value("取消", "Cancel"))
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
