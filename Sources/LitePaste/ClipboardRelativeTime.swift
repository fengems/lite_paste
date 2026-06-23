import Foundation
import LitePasteCore

extension ClipboardRecord {
  private enum RelativeTime {
    static let secondsPerMinute: TimeInterval = 60
    static let secondsPerHour: TimeInterval = 3_600
    static let secondsPerDay: TimeInterval = 86_400
    static let minutesPerHour = 60
    static let hoursPerDay = 24
  }

  var panelRelativeTimeText: String {
    panelRelativeTimeText(now: Date())
  }

  func panelRelativeTimeText(now: Date) -> String {
    let elapsedSeconds = max(0, now.timeIntervalSince(lastCopiedAt))
    if elapsedSeconds < RelativeTime.secondsPerMinute {
      return AppText.value("刚刚", "Just now")
    }

    let elapsedMinutes = Int(elapsedSeconds / RelativeTime.secondsPerMinute)
    if elapsedMinutes < RelativeTime.minutesPerHour {
      return AppText.value("\(elapsedMinutes) 分钟前", "\(elapsedMinutes)m ago")
    }

    let elapsedHours = Int(elapsedSeconds / RelativeTime.secondsPerHour)
    if elapsedHours < RelativeTime.hoursPerDay {
      return AppText.value("\(elapsedHours) 小时前", "\(elapsedHours)h ago")
    }

    let elapsedDays = Int(elapsedSeconds / RelativeTime.secondsPerDay)
    return AppText.value("\(elapsedDays) 天前", "\(elapsedDays)d ago")
  }
}
