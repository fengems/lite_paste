import AppKit
import Combine
import LitePasteCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let settingsStore = AppSettingsStore.shared
  lazy var store = HistoryStore(
    maxHistoryCount: settingsStore.settings.maxHistoryCount,
    retentionDays: settingsStore.settings.retentionDays,
    moveDuplicatesToTop: settingsStore.settings.moveDuplicatesToTop
  )

  private var statusItem: NSStatusItem?
  private var statusMenu: NSMenu?
  private var monitor: ClipboardMonitor?
  private var writer: PasteboardWriter?
  private var panelCoordinator: PanelCoordinator?
  private var hotkeyController: GlobalHotkeyController?
  private var pinnedHotkeyController: PinnedHotkeyController?
  private let clipboardWriteTracker = ClipboardWriteTracker()
  private let launchAtLoginController = LaunchAtLoginController()
  private let activeApplicationTracker = ActiveApplicationTracker.shared
  private var cancellables = Set<AnyCancellable>()

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)

    let writer = PasteboardWriter(store: store, writeTracker: clipboardWriteTracker)
    let panelCoordinator = PanelCoordinator(store: store, writer: writer)
    let monitor = ClipboardMonitor(
      store: store,
      writeTracker: clipboardWriteTracker,
      privacyFilter: PrivacyFilter(
        privacyMode: settingsStore.settings.privacyMode,
        ignoredApps: settingsStore.settings.ignoredApps,
        ignoredPasteboardTypes: settingsStore.settings.ignoredPasteboardTypes
      ),
      enabledTypes: settingsStore.settings.enabledTypes
    )

    self.writer = writer
    self.panelCoordinator = panelCoordinator
    self.monitor = monitor

    configureStatusItem()
    configureHotkey()
    configurePinnedHotkeys()
    observeSettings()
    launchAtLoginController.sync(with: settingsStore.settings.launchAtLogin)
    activeApplicationTracker.start()
    monitor.start()
  }

  func applicationWillTerminate(_ notification: Notification) {
    monitor?.stop()
    activeApplicationTracker.stop()
    hotkeyController?.unregister()
    pinnedHotkeyController?.unregister()
  }

  private func configureStatusItem() {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.button?.image = NSImage(
      systemSymbolName: "doc.on.clipboard",
      accessibilityDescription: "Lite Paste"
    )
    statusItem.button?.target = self
    statusItem.button?.action = #selector(handleStatusItemClick(_:))
    statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    self.statusItem = statusItem
    configureStatusMenu()
  }

  private func configureStatusMenu() {
    let menu = NSMenu()
    menu.addItem(
      NSMenuItem(
        title: "打开 Lite Paste",
        action: #selector(openPanelFromMenu),
        keyEquivalent: ""
      )
    )
    menu.addItem(
      NSMenuItem(
        title: "设置...",
        action: #selector(openSettings),
        keyEquivalent: ","
      )
    )
    menu.addItem(.separator())
    menu.addItem(
      NSMenuItem(
        title: "退出 Lite Paste",
        action: #selector(quit),
        keyEquivalent: "q"
      )
    )

    for item in menu.items {
      item.target = self
    }

    statusMenu = menu
  }

  private func configureHotkey() {
    let hotkeyController = GlobalHotkeyController { [weak self] in
      self?.togglePanel()
    }
    hotkeyController.registerDefaultHotkey()
    self.hotkeyController = hotkeyController
  }

  private func configurePinnedHotkeys() {
    let pinnedHotkeyController = PinnedHotkeyController { [weak self] recordID in
      self?.pastePinnedRecord(recordID)
    }
    pinnedHotkeyController.update(records: store.records)
    self.pinnedHotkeyController = pinnedHotkeyController

    store.$records
      .sink { [weak pinnedHotkeyController] records in
        pinnedHotkeyController?.update(records: records)
      }
      .store(in: &cancellables)
  }

  private func observeSettings() {
    settingsStore.settingsPublisher
      .dropFirst()
      .sink { [weak self] settings in
        self?.monitor?.updatePrivacyFilter(
          PrivacyFilter(
            privacyMode: settings.privacyMode,
            ignoredApps: settings.ignoredApps,
            ignoredPasteboardTypes: settings.ignoredPasteboardTypes
          )
        )
        self?.monitor?.updateEnabledTypes(settings.enabledTypes)
        self?.store.updateMaxHistoryCount(settings.maxHistoryCount)
        self?.store.updateRetentionDays(settings.retentionDays)
        self?.store.updateMoveDuplicatesToTop(settings.moveDuplicatesToTop)
      }
      .store(in: &cancellables)
  }

  @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
    guard NSApp.currentEvent?.type == .rightMouseUp,
          let statusItem,
          let statusMenu else {
      togglePanel()
      return
    }

    statusItem.menu = statusMenu
    statusItem.button?.performClick(nil)
    statusItem.menu = nil
  }

  @objc private func openPanelFromMenu() {
    panelCoordinator?.show(relativeTo: statusItem?.button)
  }

  @objc private func openSettings() {
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }

  private func togglePanel() {
    panelCoordinator?.toggle(relativeTo: statusItem?.button)
  }

  private func pastePinnedRecord(_ recordID: ClipboardRecord.ID) {
    guard let record = store.records.first(where: { $0.id == recordID }) else {
      return
    }

    let targetApplication = NSWorkspace.shared.frontmostApplication
    let result = writer?.paste(
      record,
      targetApplication: targetApplication,
      asPlainText: settingsStore.settings.pastePlainByDefault,
      restorePreviousClipboard: settingsStore.settings.restoreClipboardAfterPaste
    )

    if result == .accessibilityPermissionRequired {
      showAccessibilityPermissionAlert()
    }
  }

  private func showAccessibilityPermissionAlert() {
    let alert = NSAlert()
    alert.messageText = "需要辅助功能权限"
    alert.informativeText = "Lite Paste 已复制该内容。授予辅助功能权限后，可以使用置顶快捷键自动粘贴。"
    alert.addButton(withTitle: "好")
    alert.alertStyle = .informational
    alert.runModal()
  }
}
