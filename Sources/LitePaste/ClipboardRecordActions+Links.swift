import AppKit
import Foundation
import LitePasteCore

extension ClipboardRecordActions {
  func openURL(_ record: ClipboardRecord) -> ClipboardExternalActionResult {
    guard let value = record.plainText?.trimmingCharacters(in: .whitespacesAndNewlines),
          let url = normalizedURL(from: value) else {
      return .failed(
        title: AppText.value("无法打开链接", "Unable To Open Link"),
        message: AppText.value("这条历史记录没有可用的 URL。", "This history item does not contain a usable URL.")
      )
    }

    return NSWorkspace.shared.open(url)
      ? .completed(message: AppText.value("已打开链接", "Opened Link"))
      : .failed(
        title: AppText.value("无法打开链接", "Unable To Open Link"),
        message: AppText.value("系统无法打开：\(value)", "The system could not open: \(value)")
      )
  }

  func composeEmail(_ record: ClipboardRecord) -> ClipboardExternalActionResult {
    guard let value = record.plainText?.trimmingCharacters(in: .whitespacesAndNewlines),
          let url = mailtoURL(for: value) else {
      return .failed(
        title: AppText.value("无法发送邮件", "Unable To Send Email"),
        message: AppText.value("这条历史记录没有可用的邮箱地址。", "This history item does not contain a usable email address.")
      )
    }

    return NSWorkspace.shared.open(url)
      ? .completed(message: AppText.value("已打开邮件", "Opened Mail"))
      : .failed(
        title: AppText.value("无法发送邮件", "Unable To Send Email"),
        message: AppText.value("系统无法打开默认邮件客户端。", "The system could not open the default mail client.")
      )
  }

  private func normalizedURL(from value: String) -> URL? {
    guard let directURL = URL(string: value) else {
      return nil
    }

    if directURL.scheme != nil {
      return directURL
    }

    return URL(string: "https://\(value)")
  }

  private func mailtoURL(for value: String) -> URL? {
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = value
    return components.url
  }
}
