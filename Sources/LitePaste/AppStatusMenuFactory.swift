import AppKit
import LitePasteCore

struct AppStatusMenuConfiguration {
  let menu: NSMenu
  let pauseMonitoringItem: NSMenuItem
}

enum AppStatusMenuFactory {
  static func makeMenu(
    target: AnyObject,
    delegate: (any NSMenuDelegate)?,
    openPanelAction: Selector,
    toggleMonitoringAction: Selector,
    openSettingsAction: Selector,
    quitAction: Selector
  ) -> AppStatusMenuConfiguration {
    let menu = NSMenu()
    menu.delegate = delegate

    menu.addItem(
      NSMenuItem(
        title: AppText.value("打开 \(AppMetadata.displayName)", "Open \(AppMetadata.displayName)"),
        action: openPanelAction,
        keyEquivalent: ""
      )
    )

    let pauseMonitoringItem = NSMenuItem(
      title: AppText.value("停止监听剪贴板", "Pause Clipboard Monitoring"),
      action: toggleMonitoringAction,
      keyEquivalent: ""
    )
    menu.addItem(pauseMonitoringItem)

    menu.addItem(
      NSMenuItem(
        title: AppText.value("设置...", "Settings..."),
        action: openSettingsAction,
        keyEquivalent: ""
      )
    )
    menu.addItem(.separator())
    menu.addItem(
      NSMenuItem(
        title: AppText.value("退出 \(AppMetadata.displayName)", "Quit \(AppMetadata.displayName)"),
        action: quitAction,
        keyEquivalent: "q"
      )
    )

    for item in menu.items {
      item.target = target
    }
    removeItemImages(in: menu)

    return AppStatusMenuConfiguration(menu: menu, pauseMonitoringItem: pauseMonitoringItem)
  }

  static func removeItemImages(in menu: NSMenu) {
    for item in menu.items {
      item.image = nil
    }
  }
}
