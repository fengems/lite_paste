import AppKit
import Combine
import LitePasteCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let settingsStore = AppSettingsStore.shared
  lazy var store = HistoryStore(
    maxHistoryCount: settingsStore.settings.maxHistoryCount,
    retentionDays: settingsStore.settings.retentionDays,
    moveDuplicatesToTop: settingsStore.settings.moveDuplicatesToTop,
    initialLoadLimit: 80
  )

  private var statusItem: NSStatusItem?
  private var statusMenu: NSMenu?
  private var privacyModeMenuItem: NSMenuItem?
  private var ignoreApplicationMenuItem: NSMenuItem?
  private var monitor: ClipboardMonitor?
  private var writer: PasteboardWriter?
  private var panelCoordinator: PanelCoordinator?
  private var settingsWindow: NSWindow?
  private var permissionGuideWindow: NSWindow?
  private var hotkeyController: GlobalHotkeyController?
  private var pinnedHotkeyController: PinnedHotkeyController?
  private var registeredPanelHotkey: String?
  private var isRevertingPanelHotkey = false
  private var pinnedHotkeyIssueSignature: String?
  private var permissionGuideState = PermissionGuideState()
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
    observeBackupImports()
    launchAtLoginController.sync(with: settingsStore.settings.launchAtLogin)
    activeApplicationTracker.start()
    monitor.start()
    presentPermissionGuideIfNeeded()
  }

  func applicationWillTerminate(_ notification: Notification) {
    monitor?.stop()
    activeApplicationTracker.stop()
    hotkeyController?.unregister()
    pinnedHotkeyController?.unregister()
  }

  private func configureStatusItem() {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.button?.image = StatusItemIcon.makeImage()
    statusItem.button?.toolTip = "Lite Paste"
    statusItem.button?.target = self
    statusItem.button?.action = #selector(handleStatusItemClick(_:))
    statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    self.statusItem = statusItem
    configureStatusMenu()
    updateStatusMenuState()
  }

  private func configureStatusMenu() {
    let menu = NSMenu()
    menu.delegate = self
    menu.addItem(
      NSMenuItem(
        title: "打开 Lite Paste",
        action: #selector(openPanelFromMenu),
        keyEquivalent: ""
      )
    )
    let privacyModeItem = NSMenuItem(
      title: "私密模式",
      action: #selector(togglePrivacyModeFromMenu),
      keyEquivalent: ""
    )
    menu.addItem(privacyModeItem)
    self.privacyModeMenuItem = privacyModeItem

    let ignoreApplicationItem = NSMenuItem(
      title: "忽略当前应用",
      action: #selector(ignoreCurrentApplicationFromMenu),
      keyEquivalent: ""
    )
    menu.addItem(ignoreApplicationItem)
    self.ignoreApplicationMenuItem = ignoreApplicationItem

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
    registerPanelHotkey(settingsStore.settings.hotkey, controller: hotkeyController)
    self.hotkeyController = hotkeyController
  }

  private func registerPanelHotkey(_ hotkey: String, controller: GlobalHotkeyController? = nil) {
    guard let hotkeyController = controller ?? self.hotkeyController else {
      return
    }

    guard registeredPanelHotkey != hotkey else {
      return
    }

    let previousHotkey = registeredPanelHotkey
    let result = hotkeyController.register(hotkey: hotkey)
    guard result.isRegistered else {
      let restoredPreviousHotkey = restorePreviousPanelHotkey(previousHotkey, controller: hotkeyController)
      showPanelHotkeyRegistrationAlert(
        hotkey: hotkey,
        result: result,
        restoredPreviousHotkey: restoredPreviousHotkey
      )
      revertPanelHotkeySetting(to: restoredPreviousHotkey ?? AppSettings().hotkey)
      return
    }

    registeredPanelHotkey = hotkey
  }

  private func restorePreviousPanelHotkey(
    _ previousHotkey: String?,
    controller: GlobalHotkeyController
  ) -> String? {
    guard let previousHotkey else {
      return nil
    }

    if controller.register(hotkey: previousHotkey).isRegistered {
      registeredPanelHotkey = previousHotkey
      return previousHotkey
    }

    registeredPanelHotkey = nil
    return nil
  }

  private func revertPanelHotkeySetting(to hotkey: String) {
    guard settingsStore.settings.hotkey != hotkey else {
      return
    }

    isRevertingPanelHotkey = true
    settingsStore.update { $0.hotkey = hotkey }
    isRevertingPanelHotkey = false
  }

  private func configurePinnedHotkeys() {
    let pinnedHotkeyController = PinnedHotkeyController { [weak self] recordID in
      self?.pastePinnedRecord(recordID)
    }
    handlePinnedHotkeyIssues(pinnedHotkeyController.update(records: store.pinnedShortcutRecords()))
    self.pinnedHotkeyController = pinnedHotkeyController

    store.$records
      .sink { [weak self] _ in
        guard let self else {
          return
        }
        handlePinnedHotkeyIssues(pinnedHotkeyController.update(records: store.pinnedShortcutRecords()))
      }
      .store(in: &cancellables)
  }

  private func handlePinnedHotkeyIssues(_ issues: [PinnedHotkeyRegistrationIssue]) {
    guard !issues.isEmpty else {
      pinnedHotkeyIssueSignature = nil
      return
    }

    let signature = issues
      .map { "\($0.recordID.uuidString):\($0.shortcut):\(pinnedHotkeyIssueReasonDescription($0.reason))" }
      .sorted()
      .joined(separator: "|")
    guard signature != pinnedHotkeyIssueSignature else {
      return
    }

    pinnedHotkeyIssueSignature = signature
    showPinnedHotkeyRegistrationAlert(issues)
  }

  private func observeSettings() {
    settingsStore.settingsPublisher
      .dropFirst()
      .sink { [weak self] settings in
        self?.apply(settings)
      }
      .store(in: &cancellables)
  }

  private func observeBackupImports() {
    NotificationCenter.default.publisher(for: .litePasteBackupImported)
      .sink { [weak self] _ in
        self?.reloadImportedBackup()
      }
      .store(in: &cancellables)
  }

  private func apply(_ settings: AppSettings) {
    monitor?.updatePrivacyFilter(
      PrivacyFilter(
        privacyMode: settings.privacyMode,
        ignoredApps: settings.ignoredApps,
        ignoredPasteboardTypes: settings.ignoredPasteboardTypes
      )
    )
    monitor?.updateEnabledTypes(settings.enabledTypes)
    store.updateMaxHistoryCount(settings.maxHistoryCount)
    store.updateRetentionDays(settings.retentionDays)
    store.updateMoveDuplicatesToTop(settings.moveDuplicatesToTop)
    if !isRevertingPanelHotkey {
      registerPanelHotkey(settings.hotkey)
    }
    launchAtLoginController.sync(with: settings.launchAtLogin)
    updateStatusMenuState()
  }

  private func reloadImportedBackup() {
    settingsStore.reload()
    apply(settingsStore.settings)

    do {
      try store.reload()
    } catch {
      showAlert(title: "导入后刷新失败", message: error.localizedDescription)
    }
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

  @objc private func togglePrivacyModeFromMenu() {
    settingsStore.update { settings in
      settings.privacyMode.toggle()
    }
    updateStatusMenuState()
  }

  @objc private func ignoreCurrentApplicationFromMenu() {
    guard let application = activeApplicationTracker.lastExternalApplication else {
      return
    }

    settingsStore.update { settings in
      if settings.ignoredApps.contains(application.bundleIdentifier) {
        settings.ignoredApps.remove(application.bundleIdentifier)
      } else {
        settings.ignoredApps.insert(application.bundleIdentifier)
      }
    }
    updateStatusMenuState()
  }

  @objc private func openSettings() {
    let window = settingsWindow ?? makeSettingsWindow()
    settingsWindow = window
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }

  private func togglePanel() {
    panelCoordinator?.toggle(relativeTo: statusItem?.button)
  }

  private func makeSettingsWindow() -> NSWindow {
    let hostingController = NSHostingController(rootView: SettingsView())
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 920, height: 640),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Lite Paste 设置"
    window.contentViewController = hostingController
    window.minSize = NSSize(width: 860, height: 600)
    window.isReleasedWhenClosed = false
    window.center()
    return window
  }

  private func presentPermissionGuideIfNeeded() {
    let accessibilityTrusted = AccessibilityPermissionController.isTrusted
    guard permissionGuideState.shouldPresent(accessibilityTrusted: accessibilityTrusted) else {
      if accessibilityTrusted {
        closePermissionGuideWindow()
      }
      return
    }

    let window = permissionGuideWindow ?? makePermissionGuideWindow()
    permissionGuideWindow = window
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  private func makePermissionGuideWindow() -> NSWindow {
    let hostingController = NSHostingController(
      rootView: PermissionGuideView(
        isAccessibilityTrusted: { AccessibilityPermissionController.isTrusted },
        requestPermission: { AccessibilityPermissionController.requestPermission() },
        openSystemSettings: { AccessibilityPermissionController.openSystemSettings() },
        dismissForSession: { [weak self] in
          self?.permissionGuideState.dismissForSession()
          self?.closePermissionGuideWindow()
        },
        completeGuide: { [weak self] in
          self?.closePermissionGuideWindow()
        }
      )
    )
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 520, height: 300),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "Lite Paste 权限设置"
    window.contentViewController = hostingController
    window.isReleasedWhenClosed = false
    window.center()
    return window
  }

  private func closePermissionGuideWindow() {
    permissionGuideWindow?.orderOut(nil)
  }

  private func updateStatusMenuState() {
    let privacyMode = settingsStore.settings.privacyMode
    privacyModeMenuItem?.state = privacyMode ? .on : .off
    updateIgnoreApplicationMenuItem()
    statusItem?.button?.toolTip = privacyMode ? "Lite Paste - 私密模式已开启" : "Lite Paste"
  }

  private func updateIgnoreApplicationMenuItem() {
    guard let item = ignoreApplicationMenuItem else {
      return
    }

    guard let application = activeApplicationTracker.lastExternalApplication else {
      item.title = "忽略当前应用"
      item.isEnabled = false
      item.state = .off
      return
    }

    let isIgnored = settingsStore.settings.ignoredApps.contains(application.bundleIdentifier)
    item.title = isIgnored ? "取消忽略 \(application.name)" : "忽略 \(application.name)"
    item.isEnabled = true
    item.state = isIgnored ? .on : .off
  }

  private func pastePinnedRecord(_ recordID: ClipboardRecord.ID) {
    guard let record = store.record(id: recordID) else {
      return
    }

    let targetApplication = NSWorkspace.shared.frontmostApplication
    let result = writer?.paste(
      record,
      targetApplication: targetApplication,
      asPlainText: settingsStore.settings.pastePlainByDefault,
      restorePreviousClipboard: settingsStore.settings.restoreClipboardAfterPaste
    )

    switch result {
    case .some(.accessibilityPermissionRequired):
      showAccessibilityPermissionAlert()
    case .some(.missingContent):
      showMissingContentAlert()
    case .some(.targetApplicationUnavailable):
      showTargetApplicationUnavailableAlert()
    case .some(.copied), .some(.pasted), .none:
      break
    }
  }

  private func showAccessibilityPermissionAlert() {
    let alert = NSAlert()
    alert.messageText = "需要辅助功能权限"
    alert.informativeText = "Lite Paste 已复制该内容。授予辅助功能权限后，可以使用置顶快捷键自动粘贴。"
    alert.addButton(withTitle: "打开系统设置")
    alert.addButton(withTitle: "稍后")
    alert.alertStyle = .informational

    if alert.runModal() == .alertFirstButtonReturn {
      AccessibilityPermissionController.openSystemSettings()
    }
  }

  private func showMissingContentAlert() {
    showAlert(
      title: "无法恢复该内容",
      message: "该历史记录引用的文件或媒体数据已经不存在。你可以删除这条记录，或从备份恢复缺失的 Blobs 数据。"
    )
  }

  private func showTargetApplicationUnavailableAlert() {
    showAlert(
      title: "无法自动粘贴",
      message: "Lite Paste 已复制该内容，但无法回到目标应用。你可以手动按 ⌘V 粘贴。"
    )
  }

  private func showPanelHotkeyRegistrationAlert(
    hotkey: String,
    result: GlobalHotkeyRegistrationResult,
    restoredPreviousHotkey: String?
  ) {
    let requestedHotkey = PanelHotkeyCatalog.displayName(for: hotkey)
    let restoredMessage = restoredPreviousHotkey.map {
      "已恢复为之前可用的快捷键 \(PanelHotkeyCatalog.displayName(for: $0))。"
    } ?? "当前没有可用的面板快捷键，请在设置中选择其他组合。"

    showAlert(
      title: "无法注册面板快捷键",
      message: "\(requestedHotkey) 无法注册。\(panelHotkeyFailureReason(for: result)) \(restoredMessage)"
    )
  }

  private func panelHotkeyFailureReason(for result: GlobalHotkeyRegistrationResult) -> String {
    switch result {
    case .registered:
      "快捷键已注册。"
    case .invalidHotkey:
      "该快捷键格式无效。"
    case let .registrationFailed(status):
      "可能已被其他应用或系统快捷键占用。系统状态码：\(status)。"
    case let .handlerFailed(status):
      "快捷键事件监听无法启动。系统状态码：\(status)。"
    }
  }

  private func showPinnedHotkeyRegistrationAlert(_ issues: [PinnedHotkeyRegistrationIssue]) {
    let details = issues
      .prefix(5)
      .map { issue in
        "\(PinShortcutCatalog.displayName(for: issue.shortcut)) “\(issue.recordTitle)”：\(pinnedHotkeyIssueReasonDescription(issue.reason))"
      }
      .joined(separator: "\n")
    let remainingCount = issues.count - min(issues.count, 5)
    let remainingMessage = remainingCount > 0 ? "\n另有 \(remainingCount) 个置顶快捷键未注册。" : ""

    showAlert(
      title: "部分置顶快捷键不可用",
      message: "\(details)\(remainingMessage)\n请在条目中改用其他置顶快捷键。"
    )
  }

  private func pinnedHotkeyIssueReasonDescription(_ reason: PinnedHotkeyRegistrationIssueReason) -> String {
    switch reason {
    case .invalidShortcut:
      "快捷键格式无效"
    case let .registrationFailed(status):
      "可能已被系统或其他应用占用（\(status)）"
    case let .handlerFailed(status):
      "快捷键事件监听无法启动（\(status)）"
    }
  }

  private func showAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: "好")
    alert.alertStyle = .informational
    alert.runModal()
  }
}

extension AppDelegate: NSMenuDelegate {
  func menuWillOpen(_ menu: NSMenu) {
    updateStatusMenuState()
  }
}
