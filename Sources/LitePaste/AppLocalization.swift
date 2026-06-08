import Foundation
import LitePasteCore

enum AppText {
  private nonisolated(unsafe) static var languageSetting: AppLanguage = .system

  static func updateInterfaceLanguage(_ language: AppLanguage) {
    languageSetting = language
  }

  static var currentLanguage: AppLanguage {
    guard languageSetting == .system else {
      return languageSetting
    }

    let preferredLanguage = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased()
    if preferredLanguage.hasPrefix("zh-hant") ||
      preferredLanguage.hasPrefix("zh-tw") ||
      preferredLanguage.hasPrefix("zh-hk") ||
      preferredLanguage.hasPrefix("zh-mo") {
      return .zhHant
    }
    if preferredLanguage.hasPrefix("zh") {
      return .zhHans
    }
    if preferredLanguage.hasPrefix("ja") {
      return .ja
    }
    if preferredLanguage.hasPrefix("ko") {
      return .ko
    }
    return .en
  }

  static var usesChinese: Bool {
    switch currentLanguage {
    case .system, .zhHans, .zhHant:
      true
    case .ja, .ko, .en:
      false
    }
  }

  static func value(_ chinese: String, _ english: String) -> String {
    switch currentLanguage {
    case .system, .zhHans:
      chinese
    case .zhHant:
      translations[.zhHant]?[chinese] ?? chinese
    case .ja:
      translations[.ja]?[chinese] ?? english
    case .ko:
      translations[.ko]?[chinese] ?? english
    case .en:
      english
    }
  }

  static func itemCount(_ count: Int) -> String {
    switch currentLanguage {
    case .system, .zhHans:
      "\(count) 条"
    case .zhHant:
      "\(count) 筆"
    case .ja:
      "\(count) 件"
    case .ko:
      "\(count)개"
    case .en:
      "\(count) items"
    }
  }

  static func localized(
    zhHans: String,
    zhHant: String,
    ja: String,
    ko: String,
    en: String
  ) -> String {
    switch currentLanguage {
    case .system, .zhHans:
      zhHans
    case .zhHant:
      zhHant
    case .ja:
      ja
    case .ko:
      ko
    case .en:
      en
    }
  }

  private static let translations: [AppLanguage: [String: String]] = [
    .zhHant: [
      "文本": "文字",
      "富文本": "富文字",
      "图片": "圖片",
      "文件": "檔案",
      "链接": "連結",
      "邮箱": "郵箱",
      "颜色": "顏色",
      "未知": "未知",
      "全部": "全部",
      "收藏": "收藏",
      "置顶": "置頂",
      "复制": "複製",
      "复制为纯文本": "複製為純文字",
      "复制纯文本": "複製純文字",
      "复制图片文字": "複製圖片文字",
      "粘贴": "貼上",
      "粘贴为纯文本": "貼上為純文字",
      "纯文本粘贴": "純文字貼上",
      "粘贴为文本": "貼上為文字",
      "备注": "備註",
      "删除": "刪除",
      "外部操作": "外部操作",
      "跟随系统": "跟隨系統",
      "亮色模式": "淺色模式",
      "暗色模式": "深色模式",
      "靠下": "靠下",
      "靠上": "靠上",
      "靠左": "靠左",
      "靠右": "靠右",
      "跟随鼠标指针": "跟隨滑鼠指標",
      "屏幕中心": "螢幕中央",
      "剪贴板": "剪貼簿",
      "历史记录": "歷史記錄",
      "通用设置": "一般設定",
      "外观设置": "外觀設定",
      "快捷键": "快捷鍵",
      "数据备份": "資料備份",
      "关于": "關於",
      "窗口设置": "視窗設定",
      "窗口位置": "視窗位置",
      "默认视图": "預設檢視",
      "卡片": "卡片",
      "列表": "列表",
      "音效设置": "音效設定",
      "复制音效": "複製音效",
      "搜索设置": "搜尋設定",
      "默认聚焦": "預設聚焦",
      "自动清除": "自動清除",
      "内容设置": "內容設定",
      "默认操作": "預設操作",
      "仅复制": "僅複製",
      "自动粘贴": "自動貼上",
      "自动识别图片文字": "自動識別圖片文字",
      "操作按钮": "操作按鈕",
      "自定义": "自訂",
      "自动收藏": "自動收藏",
      "恢复原剪贴板": "還原原剪貼簿",
      "自动排序": "自動排序",
      "历史设置": "歷史設定",
      "最大历史数量": "最大歷史數量",
      "历史保留": "歷史保留",
      "大表格原始格式": "大型表格原始格式",
      "记录类型": "記錄類型",
      "监听与过滤": "監聽與篩選",
      "停止监听": "停止監聽",
      "数据状态": "資料狀態",
      "历史数量": "歷史數量",
      "数据占用": "資料占用",
      "刷新状态": "重新整理狀態",
      "显示数据目录": "顯示資料目錄",
      "应用设置": "應用程式設定",
      "开机启动": "登入時啟動",
      "显示菜单栏图标": "顯示選單列圖示",
      "显示 Dock 图标": "顯示 Dock 圖示",
      "运行状态": "執行狀態",
      "剪贴板记录": "剪貼簿記錄",
      "最近应用": "最近應用程式",
      "权限": "權限",
      "辅助功能": "輔助使用",
      "主题模式": "主題模式",
      "界面语言": "介面語言",
      "全局快捷键": "全域快捷鍵",
      "打开面板": "開啟面板",
      "面板快捷键": "面板快捷鍵",
      "选择条目": "選擇項目",
      "确认粘贴": "確認貼上",
      "复制条目": "複製項目",
      "删除条目": "刪除項目",
      "状态": "狀態",
      "版本": "版本",
      "许可证": "授權",
      "完成": "完成",
      "保存": "儲存",
      "取消": "取消",
      "确认": "確認",
      "好": "好",
      "刷新": "重新整理",
      "打开系统设置": "開啟系統設定",
      "请求权限": "請求權限",
      "稍后": "稍後",
      "卡片视图": "卡片檢視",
      "列表视图": "列表檢視",
      "关闭": "關閉",
      "清空历史": "清空歷史",
      "清空未置顶": "清空未置頂",
      "清空全部": "全部清空",
      "搜索剪贴板": "搜尋剪貼簿",
      "清空搜索": "清空搜尋",
      "加载更多": "載入更多",
      "已停止监听剪贴板": "已停止監聽剪貼簿",
      "暂无剪贴板历史": "暫無剪貼簿歷史",
      "没有匹配结果": "沒有符合結果",
      "已复制": "已複製",
      "正在识别图片文字": "正在識別圖片文字",
      "图片数据不可用": "圖片資料不可用",
      "图片过大，已跳过识别": "圖片過大，已略過識別",
      "未识别到图片文字": "未識別到圖片文字",
      "更多操作": "更多操作",
      "添加备注": "新增備註",
      "编辑备注": "編輯備註"
    ],
    .ja: [
      "文本": "テキスト",
      "富文本": "リッチテキスト",
      "图片": "画像",
      "文件": "ファイル",
      "链接": "リンク",
      "邮箱": "メール",
      "颜色": "カラー",
      "未知": "不明",
      "全部": "すべて",
      "收藏": "お気に入り",
      "置顶": "ピン留め",
      "复制": "コピー",
      "复制为纯文本": "プレーンテキストでコピー",
      "复制纯文本": "プレーンテキストをコピー",
      "复制图片文字": "画像の文字をコピー",
      "粘贴": "貼り付け",
      "粘贴为纯文本": "プレーンテキストで貼り付け",
      "纯文本粘贴": "プレーンテキストで貼り付け",
      "粘贴为文本": "テキストとして貼り付け",
      "备注": "メモ",
      "删除": "削除",
      "外部操作": "外部操作",
      "跟随系统": "システムに合わせる",
      "亮色模式": "ライト",
      "暗色模式": "ダーク",
      "靠下": "下端",
      "靠上": "上端",
      "靠左": "左端",
      "靠右": "右端",
      "跟随鼠标指针": "ポインタ付近",
      "屏幕中心": "画面中央",
      "剪贴板": "クリップボード",
      "历史记录": "履歴",
      "通用设置": "一般",
      "外观设置": "外観",
      "快捷键": "ショートカット",
      "数据备份": "バックアップ",
      "关于": "情報",
      "窗口设置": "ウィンドウ",
      "窗口位置": "位置",
      "默认视图": "デフォルト表示",
      "卡片": "カード",
      "列表": "リスト",
      "音效设置": "サウンド",
      "复制音效": "コピー音",
      "搜索设置": "検索",
      "默认聚焦": "検索にフォーカス",
      "自动清除": "開く時にクリア",
      "内容设置": "コンテンツ",
      "默认操作": "デフォルト操作",
      "仅复制": "コピーのみ",
      "自动粘贴": "自動貼り付け",
      "自动识别图片文字": "画像文字の自動認識",
      "操作按钮": "操作ボタン",
      "自定义": "カスタマイズ",
      "自动收藏": "自動お気に入り",
      "恢复原剪贴板": "元のクリップボードを復元",
      "自动排序": "自動並べ替え",
      "历史设置": "履歴",
      "最大历史数量": "最大履歴数",
      "历史保留": "保持期間",
      "大表格原始格式": "大きな表の元形式",
      "记录类型": "記録する種類",
      "监听与过滤": "監視とフィルター",
      "停止监听": "監視を停止",
      "数据状态": "データ状態",
      "历史数量": "履歴数",
      "数据占用": "使用容量",
      "刷新状态": "状態を更新",
      "显示数据目录": "データフォルダを表示",
      "应用设置": "アプリ",
      "开机启动": "ログイン時に起動",
      "显示菜单栏图标": "メニューバーアイコンを表示",
      "显示 Dock 图标": "Dock アイコンを表示",
      "运行状态": "状態",
      "剪贴板记录": "クリップボード記録",
      "最近应用": "最近のアプリ",
      "权限": "権限",
      "辅助功能": "アクセシビリティ",
      "主题模式": "テーマ",
      "界面语言": "表示言語",
      "全局快捷键": "グローバルショートカット",
      "打开面板": "パネルを開く",
      "面板快捷键": "パネルショートカット",
      "选择条目": "項目を選択",
      "确认粘贴": "貼り付けを確定",
      "复制条目": "項目をコピー",
      "删除条目": "項目を削除",
      "状态": "状態",
      "版本": "バージョン",
      "许可证": "ライセンス",
      "完成": "完了",
      "保存": "保存",
      "取消": "キャンセル",
      "确认": "確認",
      "好": "OK",
      "刷新": "更新",
      "打开系统设置": "システム設定を開く",
      "请求权限": "権限を要求",
      "稍后": "後で",
      "卡片视图": "カード表示",
      "列表视图": "リスト表示",
      "关闭": "閉じる",
      "清空历史": "履歴を消去",
      "清空未置顶": "ピン留め以外を消去",
      "清空全部": "すべて消去",
      "搜索剪贴板": "クリップボードを検索",
      "清空搜索": "検索をクリア",
      "加载更多": "さらに読み込む",
      "已停止监听剪贴板": "クリップボード監視を停止中",
      "暂无剪贴板历史": "クリップボード履歴はありません",
      "没有匹配结果": "一致する結果はありません",
      "已复制": "コピーしました",
      "正在识别图片文字": "画像の文字を認識中",
      "图片数据不可用": "画像データを利用できません",
      "图片过大，已跳过识别": "画像が大きすぎるため認識をスキップしました",
      "未识别到图片文字": "画像内の文字を認識できませんでした",
      "更多操作": "その他の操作",
      "添加备注": "メモを追加",
      "编辑备注": "メモを編集"
    ],
    .ko: [
      "文本": "텍스트",
      "富文本": "서식 있는 텍스트",
      "图片": "이미지",
      "文件": "파일",
      "链接": "링크",
      "邮箱": "이메일",
      "颜色": "색상",
      "未知": "알 수 없음",
      "全部": "전체",
      "收藏": "즐겨찾기",
      "置顶": "고정",
      "复制": "복사",
      "复制为纯文本": "일반 텍스트로 복사",
      "复制纯文本": "일반 텍스트 복사",
      "复制图片文字": "이미지 텍스트 복사",
      "粘贴": "붙여넣기",
      "粘贴为纯文本": "일반 텍스트로 붙여넣기",
      "纯文本粘贴": "일반 텍스트로 붙여넣기",
      "粘贴为文本": "텍스트로 붙여넣기",
      "备注": "메모",
      "删除": "삭제",
      "外部操作": "외부 작업",
      "跟随系统": "시스템 설정 따르기",
      "亮色模式": "라이트",
      "暗色模式": "다크",
      "靠下": "하단",
      "靠上": "상단",
      "靠左": "왼쪽",
      "靠右": "오른쪽",
      "跟随鼠标指针": "포인터 근처",
      "屏幕中心": "화면 중앙",
      "剪贴板": "클립보드",
      "历史记录": "기록",
      "通用设置": "일반",
      "外观设置": "모양",
      "快捷键": "단축키",
      "数据备份": "백업",
      "关于": "정보",
      "窗口设置": "창",
      "窗口位置": "위치",
      "默认视图": "기본 보기",
      "卡片": "카드",
      "列表": "목록",
      "音效设置": "사운드",
      "复制音效": "복사 사운드",
      "搜索设置": "검색",
      "默认聚焦": "검색 포커스",
      "自动清除": "열 때 지우기",
      "内容设置": "콘텐츠",
      "默认操作": "기본 동작",
      "仅复制": "복사만",
      "自动粘贴": "자동 붙여넣기",
      "自动识别图片文字": "이미지 텍스트 자동 인식",
      "操作按钮": "작업 버튼",
      "自定义": "사용자화",
      "自动收藏": "자동 즐겨찾기",
      "恢复原剪贴板": "원래 클립보드 복원",
      "自动排序": "자동 정렬",
      "历史设置": "기록",
      "最大历史数量": "최대 기록 수",
      "历史保留": "보관 기간",
      "大表格原始格式": "큰 표 원본 형식",
      "记录类型": "기록 유형",
      "监听与过滤": "감시 및 필터",
      "停止监听": "감시 중지",
      "数据状态": "데이터 상태",
      "历史数量": "기록 수",
      "数据占用": "사용 용량",
      "刷新状态": "상태 새로고침",
      "显示数据目录": "데이터 폴더 보기",
      "应用设置": "앱",
      "开机启动": "로그인 시 실행",
      "显示菜单栏图标": "메뉴 막대 아이콘 표시",
      "显示 Dock 图标": "Dock 아이콘 표시",
      "运行状态": "상태",
      "剪贴板记录": "클립보드 기록",
      "最近应用": "최근 앱",
      "权限": "권한",
      "辅助功能": "손쉬운 사용",
      "主题模式": "테마",
      "界面语言": "인터페이스 언어",
      "全局快捷键": "전역 단축키",
      "打开面板": "패널 열기",
      "面板快捷键": "패널 단축키",
      "选择条目": "항목 선택",
      "确认粘贴": "붙여넣기 확인",
      "复制条目": "항목 복사",
      "删除条目": "항목 삭제",
      "状态": "상태",
      "版本": "버전",
      "许可证": "라이선스",
      "完成": "완료",
      "保存": "저장",
      "取消": "취소",
      "确认": "확인",
      "好": "확인",
      "刷新": "새로고침",
      "打开系统设置": "시스템 설정 열기",
      "请求权限": "권한 요청",
      "稍后": "나중에",
      "卡片视图": "카드 보기",
      "列表视图": "목록 보기",
      "关闭": "닫기",
      "清空历史": "기록 지우기",
      "清空未置顶": "고정되지 않은 항목 지우기",
      "清空全部": "모두 지우기",
      "搜索剪贴板": "클립보드 검색",
      "清空搜索": "검색 지우기",
      "加载更多": "더 불러오기",
      "已停止监听剪贴板": "클립보드 감시 중지됨",
      "暂无剪贴板历史": "클립보드 기록 없음",
      "没有匹配结果": "일치하는 결과 없음",
      "已复制": "복사됨",
      "正在识别图片文字": "이미지 텍스트 인식 중",
      "图片数据不可用": "이미지 데이터를 사용할 수 없음",
      "图片过大，已跳过识别": "이미지가 너무 커서 인식을 건너뜀",
      "未识别到图片文字": "이미지 텍스트를 인식하지 못함",
      "更多操作": "추가 작업",
      "添加备注": "메모 추가",
      "编辑备注": "메모 편집"
    ]
  ]
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
