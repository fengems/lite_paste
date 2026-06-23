import LitePasteCore

enum SettingsText {
  static func historyCount(_ count: Int?) -> String {
    count.map(AppText.itemCount) ?? AppText.value("正在读取", "Reading")
  }

  static func panelPositionDescription(for position: PanelPosition) -> String {
    switch position {
    case .edgeBottom:
      AppText.value(
        "面板贴紧当前鼠标所在屏幕的底部和左右边缘。",
        "The panel attaches to the bottom and side edges of the current pointer screen."
      )
    case .edgeTop:
      AppText.value(
        "面板贴紧当前鼠标所在屏幕的顶部和左右边缘。",
        "The panel attaches to the top and side edges of the current pointer screen."
      )
    case .edgeLeft:
      AppText.value(
        "面板贴紧当前鼠标所在屏幕的左侧、顶部和底部。",
        "The panel attaches to the left, top, and bottom edges of the current pointer screen."
      )
    case .edgeRight:
      AppText.value(
        "面板贴紧当前鼠标所在屏幕的右侧、顶部和底部。",
        "The panel attaches to the right, top, and bottom edges of the current pointer screen."
      )
    case .cursor:
      AppText.value(
        "面板优先出现在鼠标右下角，空间不足时自动移动到完整可见的位置。",
        "The panel opens near the pointer and moves automatically when space is limited."
      )
    case .screenCenter:
      AppText.value(
        "面板在当前鼠标所在屏幕的可见区域居中显示。",
        "The panel is centered in the visible area of the current pointer screen."
      )
    case .bottomDrawer, .statusItem:
      AppText.value("旧版位置会自动迁移为靠下。", "Legacy positions are migrated to the bottom edge.")
    case .mouseScreenCenter:
      AppText.value("旧版居中位置会自动迁移为跟随鼠标指针。", "Legacy centered position is migrated to near pointer.")
    }
  }

  static func accessibilityStatusTitle(isTrusted: Bool) -> String {
    isTrusted
      ? AppText.value("辅助功能权限已授权", "Accessibility permission granted")
      : AppText.value("自动粘贴需要辅助功能权限", "Auto paste requires Accessibility permission")
  }

  static func recordingStatusTitle(isMonitoringPaused: Bool) -> String {
    isMonitoringPaused
      ? AppText.value("已停止监听剪贴板", "Clipboard monitoring paused")
      : AppText.value("正在记录", "Recording")
  }

  static func currentApplicationTitle(_ application: TrackedApplication?) -> String {
    guard let application else {
      return AppText.value("暂无", "None")
    }

    return "\(application.name) (\(application.bundleIdentifier))"
  }
}
