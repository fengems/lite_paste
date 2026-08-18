import AppKit
import Combine
import LitePasteCore
import SwiftUI

@MainActor
final class PanelCoordinator {
  private let store: HistoryStore
  private let writer: PasteboardWriter
  private let openSettingsAction: () -> Void
  private let settingsStore = AppSettingsStore.shared
  private let presentationState = PanelPresentationState()
  private lazy var imageTextResolver = PanelImageTextResolver(
    store: store,
    presentationState: presentationState
  )
  private var panel: NSPanel?
  private var previousApplication: NSRunningApplication?
  private let edgePanelThickness = ClipboardPanelMetrics.edgePanelThickness
  private var cancellables = Set<AnyCancellable>()

  init(store: HistoryStore, writer: PasteboardWriter, openSettingsAction: @escaping () -> Void) {
    self.store = store
    self.writer = writer
    self.openSettingsAction = openSettingsAction
    observeAppDeactivation()
    observePanelSettings()
  }

  func toggle() {
    if let panel, panel.isVisible {
      panel.orderOut(nil)
      return
    }

    show()
  }

  func show() {
    let panel = panel ?? makePanel()
    self.panel = panel
    previousApplication = NSWorkspace.shared.frontmostApplication

    position(panel)

    NSApp.activate(ignoringOtherApps: true)
    presentationState.markOpened()
    panel.makeKeyAndOrderFront(nil)
  }

  func hide() {
    hidePanel()
  }

  private func makePanel() -> NSPanel {
    let panel = ClipboardPanelWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1120, height: edgePanelThickness),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    let rootView = ClipboardPanelView(
      store: store,
      presentationState: presentationState,
      copyAction: { [weak self] record in
        self?.copy(record, asPlainText: self?.settingsStore.settings.copyPlainTextByDefault ?? false)
      },
      copyPlainTextAction: { [weak self] record in
        self?.copy(record, asPlainText: true)
      },
      pasteAction: { [weak self] record in
        self?.paste(record, asPlainText: self?.settingsStore.settings.pastePlainTextByDefault ?? false)
      },
      pastePlainTextAction: { [weak self] record in
        self?.paste(record, asPlainText: true)
      },
      openSettingsAction: { [weak self] in
        self?.openSettingsAction()
      },
      closeAction: { [weak panel] in
        panel?.orderOut(nil)
      }
    )
    let hostingController = NSHostingController(rootView: rootView)
    applyRoundedContentMask(to: hostingController.view)

    panel.title = AppMetadata.displayName
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isFloatingPanel = true
    PanelPlacement.applyLevel(to: panel, settings: settingsStore.settings)
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.isReleasedWhenClosed = false
    panel.contentViewController = hostingController
    applyRoundedContentMask(to: panel.contentView)
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = true
    panel.isMovableByWindowBackground = false

    return panel
  }

  private func applyRoundedContentMask(to view: NSView?) {
    view?.wantsLayer = true
    view?.layer?.cornerRadius = ClipboardPanelMetrics.cornerRadius
    view?.layer?.masksToBounds = true
  }

  private func observeAppDeactivation() {
    NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
      .sink { [weak self] _ in
        Task { @MainActor in
          self?.hidePanel()
        }
      }
      .store(in: &cancellables)
  }

  private func observePanelSettings() {
    settingsStore.settingsPublisher
      .sink { [weak self] _ in
        Task { @MainActor in
          guard let self, let panel = self.panel, panel.isVisible else {
            return
          }
          self.position(panel)
        }
      }
      .store(in: &cancellables)
  }

  private func position(_ panel: NSPanel) {
    PanelPlacement.position(
      panel,
      settings: settingsStore.settings,
      presentationState: presentationState,
      edgePanelThickness: edgePanelThickness
    )
  }

  private func paste(_ record: ClipboardRecord) {
    paste(record, asPlainText: false)
  }

  private func copy(_ record: ClipboardRecord, asPlainText: Bool = false) {
    if asPlainText, imageTextResolver.needsRecognition(record) {
      resolveImageText(for: record) { [weak self] updatedRecord in
        guard let self else {
          return
        }
        let result = writer.copy(updatedRecord, asPlainText: true)
        handleActionResult(result)
      }
      return
    }

    let result = writer.copy(record, asPlainText: asPlainText)
    handleActionResult(result)
  }

  private func paste(_ record: ClipboardRecord, asPlainText: Bool) {
    if asPlainText, imageTextResolver.needsRecognition(record) {
      resolveImageText(for: record) { [weak self] updatedRecord in
        guard let self else {
          return
        }
        let result = writer.paste(
          updatedRecord,
          targetApplication: previousApplication,
          asPlainText: true,
          restorePreviousClipboard: settingsStore.settings.restoreClipboardAfterPaste
        )
        handleActionResult(result, closesPanelOnSuccess: true)
      }
      return
    }

    let result = writer.paste(
      record,
      targetApplication: previousApplication,
      asPlainText: asPlainText,
      restorePreviousClipboard: settingsStore.settings.restoreClipboardAfterPaste
    )

    handleActionResult(result, closesPanelOnSuccess: true)
  }

  private func resolveImageText(
    for record: ClipboardRecord,
    completion: @escaping @MainActor (ClipboardRecord) -> Void
  ) {
    imageTextResolver.resolve(
      for: record,
      isPanelVisible: { [weak self] in self?.panel?.isVisible == true },
      missingContent: { [weak self] in self?.showMissingContentAlert() },
      completion: completion
    )
  }

  private func handleActionResult(_ result: PasteActionResult, closesPanelOnSuccess: Bool = false) {
    switch result {
    case .copied:
      presentationState.showActionMessage(AppText.value("已复制", "Copied"))
    case .pasted:
      if closesPanelOnSuccess {
        hidePanel()
      }
    case .accessibilityPermissionRequired:
      if closesPanelOnSuccess {
        hidePanel()
      }
      showAccessibilityPermissionAlert()
    case .missingContent:
      showMissingContentAlert()
    case .targetApplicationUnavailable:
      if closesPanelOnSuccess {
        hidePanel()
      }
      showTargetApplicationUnavailableAlert()
    }
  }

  private func showAccessibilityPermissionAlert() {
    UserAlerts.showAccessibilityPermissionRequired(
      message: AppText.value(
        "Lite Paste 已复制该内容。授予辅助功能权限后，可以自动粘贴到上一个应用。",
        "Lite Paste copied the content. Grant Accessibility permission to paste into the previous app automatically."
      )
    )
  }

  private func showMissingContentAlert() {
    UserAlerts.showMessage(
      title: AppText.value("无法恢复该内容", "Unable To Restore This Content"),
      message: AppText.value(
        "该历史记录引用的文件或媒体数据已经不存在。你可以删除这条记录，或从备份恢复缺失的 Blobs 数据。",
        "The file or media data referenced by this history item no longer exists. Delete the item or restore the missing Blobs data from a backup."
      ),
      style: .warning
    )
  }

  private func showTargetApplicationUnavailableAlert() {
    UserAlerts.showMessage(
      title: AppText.value("无法自动粘贴", "Unable To Auto Paste"),
      message: AppText.value(
        "Lite Paste 已复制该内容，但无法回到原来的目标应用。你可以手动按 ⌘V 粘贴。",
        "Lite Paste copied the content, but could not return to the original target app. Press ⌘V manually to paste."
      )
    )
  }

  private func hidePanel() {
    imageTextResolver.cancelPendingActions()
    panel?.orderOut(nil)
    presentationState.updateTopObstruction(nil)
  }
}
