import AppKit
import Combine
import LitePasteCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let settingsStore = AppSettingsStore.shared
  lazy var store = HistoryStore(maxHistoryCount: settingsStore.settings.maxHistoryCount)

  private var statusItem: NSStatusItem?
  private var monitor: ClipboardMonitor?
  private var writer: PasteboardWriter?
  private var panelCoordinator: PanelCoordinator?
  private var hotkeyController: GlobalHotkeyController?
  private let launchAtLoginController = LaunchAtLoginController()
  private var cancellables = Set<AnyCancellable>()

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)

    let writer = PasteboardWriter(store: store)
    let panelCoordinator = PanelCoordinator(store: store, writer: writer)
    let monitor = ClipboardMonitor(
      store: store,
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
    observeSettings()
    launchAtLoginController.sync(with: settingsStore.settings.launchAtLogin)
    monitor.start()
  }

  func applicationWillTerminate(_ notification: Notification) {
    monitor?.stop()
    hotkeyController?.unregister()
  }

  private func configureStatusItem() {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.button?.image = NSImage(
      systemSymbolName: "doc.on.clipboard",
      accessibilityDescription: "Lite Paste"
    )
    statusItem.button?.target = self
    statusItem.button?.action = #selector(togglePanel)
    self.statusItem = statusItem
  }

  private func configureHotkey() {
    let hotkeyController = GlobalHotkeyController { [weak self] in
      self?.togglePanel()
    }
    hotkeyController.registerDefaultHotkey()
    self.hotkeyController = hotkeyController
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
      }
      .store(in: &cancellables)
  }

  @objc private func togglePanel() {
    panelCoordinator?.toggle(relativeTo: statusItem?.button)
  }
}
