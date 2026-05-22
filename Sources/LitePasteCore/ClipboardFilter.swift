import Foundation

public enum ClipboardFilter: String, CaseIterable, Identifiable, Sendable {
  case all
  case text
  case images
  case files
  case favorites
  case pinned

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .all:
      "全部"
    case .text:
      "文本"
    case .images:
      "图片"
    case .files:
      "文件"
    case .favorites:
      "收藏"
    case .pinned:
      "置顶"
    }
  }

  public func matches(_ record: ClipboardRecord) -> Bool {
    switch self {
    case .all:
      true
    case .text:
      [.text, .richText, .html, .url, .email, .color].contains(record.kind)
    case .images:
      record.kind == .image
    case .files:
      record.kind == .files
    case .favorites:
      record.isFavorite
    case .pinned:
      record.isPinned
    }
  }
}

