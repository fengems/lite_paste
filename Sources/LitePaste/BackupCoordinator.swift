import AppKit
import Foundation
import LitePasteCore

@MainActor
final class BackupCoordinator {
  private let service = ImportExportService()

  func exportBackup() {
    let panel = NSOpenPanel()
    panel.title = "选择备份保存位置"
    panel.prompt = "导出"
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false

    guard panel.runModal() == .OK, let directory = panel.url else {
      return
    }

    do {
      let backupURL = try service.exportBackup(to: directory)
      NSWorkspace.shared.activateFileViewerSelecting([backupURL])
    } catch {
      showAlert(title: "导出失败", message: error.localizedDescription)
    }
  }

  func importBackup(mode: BackupImportMode) {
    let panel = NSOpenPanel()
    panel.title = "选择 Lite Paste 备份"
    panel.prompt = "导入"
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false

    guard panel.runModal() == .OK, let backupURL = panel.url else {
      return
    }

    do {
      try service.importBackup(from: backupURL, mode: mode)
      NotificationCenter.default.post(name: .litePasteBackupImported, object: nil)
      showAlert(title: "导入完成", message: "备份已导入，历史和设置已刷新。")
    } catch {
      showAlert(title: "导入失败", message: error.localizedDescription)
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
