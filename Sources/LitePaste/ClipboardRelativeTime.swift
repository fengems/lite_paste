import Foundation
import LitePasteCore

extension ClipboardRecord {
  var panelRelativeTimeText: String {
    panelRelativeTimeText(now: Date())
  }

  func panelRelativeTimeText(now: Date) -> String {
    let elapsedSeconds = max(0, now.timeIntervalSince(lastCopiedAt))
    if elapsedSeconds < 60 {
      return AppText.value("刚刚", "Just now")
    }

    let elapsedMinutes = Int(elapsedSeconds / 60)
    if elapsedMinutes < 60 {
      return AppText.value("\(elapsedMinutes) 分钟前", "\(elapsedMinutes)m ago")
    }

    let elapsedHours = Int(elapsedSeconds / 3_600)
    if elapsedHours < 24 {
      return AppText.value("\(elapsedHours) 小时前", "\(elapsedHours)h ago")
    }

    let elapsedDays = Int(elapsedSeconds / 86_400)
    return AppText.value("\(elapsedDays) 天前", "\(elapsedDays)d ago")
  }
}
