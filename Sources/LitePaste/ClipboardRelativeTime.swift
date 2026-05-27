import Foundation
import LitePasteCore

extension ClipboardRecord {
  var panelRelativeTimeText: String {
    panelRelativeTimeText(now: Date())
  }

  func panelRelativeTimeText(now: Date) -> String {
    let elapsedSeconds = max(0, now.timeIntervalSince(lastCopiedAt))
    if elapsedSeconds < 60 {
      return "刚刚"
    }

    let elapsedMinutes = Int(elapsedSeconds / 60)
    if elapsedMinutes < 60 {
      return "\(elapsedMinutes) 分钟前"
    }

    let elapsedHours = Int(elapsedSeconds / 3_600)
    if elapsedHours < 24 {
      return "\(elapsedHours) 小时前"
    }

    let elapsedDays = Int(elapsedSeconds / 86_400)
    return "\(elapsedDays) 天前"
  }
}
