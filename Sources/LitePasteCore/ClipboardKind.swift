import Foundation

public enum ClipboardKind: String, CaseIterable, Codable, Identifiable, Sendable {
  case text
  case richText
  case html
  case image
  case files
  case url
  case email
  case color
  case unknown

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .text:
      "文本"
    case .richText:
      "富文本"
    case .html:
      "HTML"
    case .image:
      "图片"
    case .files:
      "文件"
    case .url:
      "链接"
    case .email:
      "邮箱"
    case .color:
      "颜色"
    case .unknown:
      "未知"
    }
  }
}

