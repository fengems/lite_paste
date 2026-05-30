import AppKit
import Foundation
import LitePasteCore

@MainActor
final class BackupCoordinator {
  private let service = ImportExportService()
  private let iCloudService = ICloudBackupService()

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

  func iCloudBackupStatusText() async -> String {
    do {
      let summary = try await iCloudService.summary()
      guard let latestBackupURL = summary.latestBackupURL else {
        return "iCloud 可用，暂无备份"
      }

      return "已发现 \(summary.backupCount) 个备份，最新：\(latestBackupURL.lastPathComponent)"
    } catch {
      return errorMessage(for: error)
    }
  }

  func exportICloudBackup() async {
    do {
      let backupURL = try await iCloudService.exportBackup()
      showAlert(title: "iCloud 备份完成", message: "已保存到：\(backupURL.lastPathComponent)")
    } catch {
      showAlert(title: "iCloud 备份失败", message: errorMessage(for: error), style: .warning)
    }
  }

  func importLatestICloudBackup(mode: BackupImportMode) async {
    do {
      let backupURL = try await latestICloudBackupURLForImport(mode: mode)
      try await iCloudService.importLatestBackup(mode: mode)
      NotificationCenter.default.post(name: .litePasteBackupImported, object: nil)
      showAlert(title: "iCloud 导入完成", message: "\(successMessage(for: mode))\n\n来源：\(backupURL.lastPathComponent)")
    } catch BackupCoordinatorError.cancelled {
      return
    } catch {
      showAlert(title: "iCloud 导入失败", message: errorMessage(for: error), style: .warning)
    }
  }

  func revealICloudBackupsDirectory() async {
    do {
      let directory = try await iCloudService.backupsDirectoryURL()
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      NSWorkspace.shared.activateFileViewerSelecting([directory])
    } catch {
      showAlert(title: "无法打开 iCloud 备份目录", message: errorMessage(for: error), style: .warning)
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

  private func latestICloudBackupURLForImport(mode: BackupImportMode) async throws -> URL {
    let summary = try await iCloudService.summary()
    guard let backupURL = summary.latestBackupURL else {
      throw ICloudBackupError.noBackups
    }

    guard mode != .replace || confirmReplaceImport(from: backupURL) else {
      throw BackupCoordinatorError.cancelled
    }

    return backupURL
  }

  private func successMessage(for mode: BackupImportMode) -> String {
    switch mode {
    case .merge:
      "备份历史已合并导入。当前已有设置会保留；如果本机没有设置文件，会使用备份中的设置。"
    case .replace:
      "备份已覆盖导入，历史、设置和媒体文件已按备份替换；备份缺少设置时会使用默认设置。"
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

private enum BackupCoordinatorError: Error, LocalizedError {
  case cancelled

  var errorDescription: String? {
    "操作已取消。"
  }
}
