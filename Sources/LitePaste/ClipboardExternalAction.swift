enum ClipboardExternalAction {
  case openURL
  case composeEmail
  case showInFinder
  case exportImage

  var iconName: String {
    switch self {
    case .openURL:
      "safari"
    case .composeEmail:
      "envelope.open"
    case .showInFinder:
      "folder"
    case .exportImage:
      "square.and.arrow.down"
    }
  }

  var accessibilityLabel: String {
    switch self {
    case .openURL:
      AppText.value("打开链接", "Open Link")
    case .composeEmail:
      AppText.value("发送邮件", "Send Email")
    case .showInFinder:
      AppText.value("在 Finder 中显示", "Show In Finder")
    case .exportImage:
      AppText.value("导出图片", "Export Image")
    }
  }
}

enum ClipboardExternalActionResult {
  case completed(message: String)
  case failed(title: String, message: String)
}
