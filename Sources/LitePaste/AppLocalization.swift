import Foundation
import LitePasteCore

enum AppText {
  static var usesChinese: Bool {
    let preferredLanguage = Locale.preferredLanguages.first ?? Locale.current.identifier
    return preferredLanguage.lowercased().hasPrefix("zh")
  }

  static func value(_ chinese: String, _ english: String) -> String {
    usesChinese ? chinese : english
  }

  static func itemCount(_ count: Int) -> String {
    usesChinese ? "\(count) 条" : "\(count) items"
  }
}

extension ClipboardKind {
  var localizedDisplayName: String {
    switch self {
    case .text:
      AppText.value("文本", "Text")
    case .richText:
      AppText.value("富文本", "Rich Text")
    case .html:
      "HTML"
    case .image:
      AppText.value("图片", "Images")
    case .files:
      AppText.value("文件", "Files")
    case .url:
      AppText.value("链接", "Links")
    case .email:
      AppText.value("邮箱", "Email")
    case .color:
      AppText.value("颜色", "Colors")
    case .unknown:
      AppText.value("未知", "Unknown")
    }
  }
}

extension ClipboardFilter {
  var localizedDisplayName: String {
    switch self {
    case .all:
      AppText.value("全部", "All")
    case .text:
      AppText.value("文本", "Text")
    case .images:
      AppText.value("图片", "Images")
    case .files:
      AppText.value("文件", "Files")
    case .links:
      AppText.value("链接", "Links")
    case .colors:
      AppText.value("颜色", "Colors")
    case .favorites:
      AppText.value("收藏", "Favorites")
    case .pinned:
      AppText.value("置顶", "Pinned")
    }
  }
}

extension PanelPosition {
  var localizedDisplayName: String {
    switch self {
    case .edgeBottom:
      AppText.value("靠下", "Bottom Edge")
    case .edgeTop:
      AppText.value("靠上", "Top Edge")
    case .edgeLeft:
      AppText.value("靠左", "Left Edge")
    case .edgeRight:
      AppText.value("靠右", "Right Edge")
    case .cursor:
      AppText.value("跟随鼠标指针", "Near Pointer")
    case .screenCenter:
      AppText.value("屏幕中心", "Screen Center")
    case .bottomDrawer:
      AppText.value("底部抽屉", "Bottom Drawer")
    case .statusItem:
      AppText.value("菜单栏下方", "Below Menu Bar")
    case .mouseScreenCenter:
      AppText.value("鼠标所在屏幕居中", "Pointer Screen Center")
    }
  }
}

extension ClipboardQuickAction {
  var localizedDisplayName: String {
    switch self {
    case .favorite:
      AppText.value("收藏", "Favorite")
    case .pin:
      AppText.value("置顶", "Pin")
    case .copy:
      AppText.value("复制", "Copy")
    case .copyPlainText:
      AppText.value("复制为纯文本", "Copy Plain Text")
    case .paste:
      AppText.value("粘贴", "Paste")
    case .pastePlainText:
      AppText.value("粘贴为纯文本", "Paste Plain Text")
    case .note:
      AppText.value("备注", "Note")
    case .delete:
      AppText.value("删除", "Delete")
    case .external:
      AppText.value("外部操作", "External Action")
    }
  }

  var iconName: String {
    switch self {
    case .favorite:
      "star"
    case .pin:
      "pin"
    case .copy:
      "doc.on.doc"
    case .copyPlainText:
      "doc.plaintext"
    case .paste:
      "arrow.turn.down.left"
    case .pastePlainText:
      "textformat"
    case .note:
      "note.text"
    case .delete:
      "trash"
    case .external:
      "arrow.up.right.square"
    }
  }
}

extension AppThemeMode {
  var localizedDisplayName: String {
    switch self {
    case .system:
      AppText.value("跟随系统", "Follow System")
    case .light:
      AppText.value("亮色模式", "Light")
    case .dark:
      AppText.value("暗色模式", "Dark")
    }
  }
}
