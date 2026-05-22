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

    guard mode != .replace || confirmReplaceImport(from: backupURL) else {
      return
    }

    do {
      try service.importBackup(from: backupURL, mode: mode)
      NotificationCenter.default.post(name: .litePasteBackupImported, object: nil)
      showAlert(title: "导入完成", message: successMessage(for: mode))
    } catch {
      showAlert(title: "导入失败", message: errorMessage(for: error), style: .warning)
    }
  }

  private func confirmReplaceImport(from backupURL: URL) -> Bool {
    let alert = NSAlert()
    alert.messageText = "覆盖导入备份？"
    alert.informativeText = "将用“\(backupURL.lastPathComponent)”替换当前历史、设置和媒体文件。当前未导出的历史会被覆盖，此操作无法撤销。"
    alert.alertStyle = .warning
    alert.addButton(withTitle: "覆盖导入")
    alert.addButton(withTitle: "取消")
    return alert.runModal() == .alertFirstButtonReturn
  }

  private func successMessage(for mode: BackupImportMode) -> String {
    switch mode {
    case .merge:
      "备份已合并导入，历史和设置已刷新。"
    case .replace:
      "备份已覆盖导入，历史和设置已刷新。"
    }
  }

  private func errorMessage(for error: Error) -> String {
    let nsError = error as NSError
    guard let recoverySuggestion = nsError.localizedRecoverySuggestion,
          !recoverySuggestion.isEmpty else {
      return nsError.localizedDescription
    }

    return "\(nsError.localizedDescription)\n\n\(recoverySuggestion)"
  }

  private func showAlert(title: String, message: String, style: NSAlert.Style = .informational) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: "好")
    alert.alertStyle = style
    alert.runModal()
  }
}
