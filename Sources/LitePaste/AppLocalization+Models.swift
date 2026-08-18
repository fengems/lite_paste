import LitePasteCore

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
      "text.justify.left"
    case .note:
      "note.text"
    case .delete:
      "trash"
    case .external:
      "arrow.up.right.square"
    }
  }
}

extension TablePlainTextWrapper {
  var localizedDisplayName: String {
    switch self {
    case .none:
      AppText.value("不包裹", "None")
    case .doubleQuote:
      AppText.value("英文双引号", "Double Quotes")
    case .singleQuote:
      AppText.value("英文单引号", "Single Quotes")
    case .chineseQuote:
      AppText.value("中文引号", "Chinese Quotes")
    case .squareBracket:
      AppText.value("方括号", "Square Brackets")
    case .curlyBrace:
      AppText.value("花括号", "Curly Braces")
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

extension AppLanguage {
  var localizedDisplayName: String {
    switch self {
    case .system:
      AppText.localized(
        zhHans: "跟随系统",
        zhHant: "跟隨系統",
        ja: "システムに合わせる",
        ko: "시스템 설정 따르기",
        en: "Follow System"
      )
    case .zhHans:
      "简体中文"
    case .zhHant:
      "繁體中文"
    case .ja:
      "日本語"
    case .ko:
      "한국어"
    case .en:
      "English"
    }
  }
}
