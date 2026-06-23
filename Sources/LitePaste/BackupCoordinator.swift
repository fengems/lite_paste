import AppKit
import Foundation
import LitePasteCore

@MainActor
final class BackupCoordinator {
  private let service = ImportExportService()
  private let iCloudService = ICloudBackupService()

  func exportBackup() {
    let panel = makeExportPanel()

    guard panel.runModal() == .OK, let directory = panel.url else {
      return
    }

    do {
      let backupURL = try service.exportBackup(to: directory)
      NSWorkspace.shared.activateFileViewerSelecting([backupURL])
    } catch {
      UserAlerts.showMessage(
        title: AppText.value("导出失败", "Export Failed"),
        message: error.localizedDescription
      )
    }
  }

  func importBackup(mode: BackupImportMode) {
    let panel = makeImportPanel()

    guard panel.runModal() == .OK, let backupURL = panel.url else {
      return
    }

    guard mode != .replace || confirmReplaceImport(from: backupURL) else {
      return
    }

    do {
      try service.importBackup(from: backupURL, mode: mode)
      notifyBackupImported()
      UserAlerts.showMessage(
        title: AppText.value("导入完成", "Import Complete"),
        message: successMessage(for: mode)
      )
    } catch {
      UserAlerts.showMessage(
        title: AppText.value("导入失败", "Import Failed"),
        message: errorMessage(for: error),
        style: .warning
      )
    }
  }

  func iCloudBackupStatusText() async -> String {
    do {
      let summary = try await iCloudService.summary()
      guard let latestBackupURL = summary.latestBackupURL else {
        return AppText.value("iCloud 可用，暂无备份", "iCloud is available. No backups yet.")
      }

      return AppText.value(
        "已发现 \(summary.backupCount) 个备份，最新：\(latestBackupURL.lastPathComponent)",
        "Found \(summary.backupCount) backups. Latest: \(latestBackupURL.lastPathComponent)"
      )
    } catch {
      return errorMessage(for: error)
    }
  }

  func exportICloudBackup() async {
    do {
      let backupURL = try await iCloudService.exportBackup()
      UserAlerts.showMessage(
        title: AppText.value("iCloud 备份完成", "iCloud Backup Complete"),
        message: AppText.value(
          "已保存到：\(backupURL.lastPathComponent)",
          "Saved to: \(backupURL.lastPathComponent)"
        )
      )
    } catch {
      UserAlerts.showMessage(
        title: AppText.value("iCloud 备份失败", "iCloud Backup Failed"),
        message: errorMessage(for: error),
        style: .warning
      )
    }
  }

  func importLatestICloudBackup(mode: BackupImportMode) async {
    do {
      let backupURL = try await latestICloudBackupURLForImport(mode: mode)
      try await iCloudService.importLatestBackup(mode: mode)
      notifyBackupImported()
      UserAlerts.showMessage(
        title: AppText.value("iCloud 导入完成", "iCloud Import Complete"),
        message: AppText.value(
          "\(successMessage(for: mode))\n\n来源：\(backupURL.lastPathComponent)",
          "\(successMessage(for: mode))\n\nSource: \(backupURL.lastPathComponent)"
        )
      )
    } catch BackupCoordinatorError.cancelled {
      return
    } catch {
      UserAlerts.showMessage(
        title: AppText.value("iCloud 导入失败", "iCloud Import Failed"),
        message: errorMessage(for: error),
        style: .warning
      )
    }
  }

  func revealICloudBackupsDirectory() async {
    do {
      let directory = try await iCloudService.backupsDirectoryURL()
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      NSWorkspace.shared.activateFileViewerSelecting([directory])
    } catch {
      UserAlerts.showMessage(
        title: AppText.value("无法打开 iCloud 备份目录", "Unable To Open iCloud Backup Folder"),
        message: errorMessage(for: error),
        style: .warning
      )
    }
  }

  private func confirmReplaceImport(from backupURL: URL) -> Bool {
    UserAlerts.confirm(
      title: AppText.value("覆盖导入备份？", "Replace Current Data With Backup?"),
      message: AppText.value(
        "将用“\(backupURL.lastPathComponent)”替换当前历史、设置和媒体文件。当前未导出的历史会被覆盖，此操作无法撤销。",
        "\"\(backupURL.lastPathComponent)\" will replace current history, settings, and media files. Unsaved local history will be overwritten. This cannot be undone."
      ),
      confirmTitle: AppText.value("覆盖导入", "Replace Import")
    )
  }

  private func makeExportPanel() -> NSOpenPanel {
    let panel = NSOpenPanel()
    panel.title = AppText.value("选择备份保存位置", "Choose Backup Location")
    panel.prompt = AppText.value("导出", "Export")
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    return panel
  }

  private func makeImportPanel() -> NSOpenPanel {
    let panel = NSOpenPanel()
    panel.title = AppText.value("选择 Lite Paste 备份", "Choose Lite Paste Backup")
    panel.prompt = AppText.value("导入", "Import")
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    return panel
  }

  private func notifyBackupImported() {
    NotificationCenter.default.post(name: .litePasteBackupImported, object: nil)
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
      AppText.value(
        "备份历史已合并导入。当前已有设置会保留；如果本机没有设置文件，会使用备份中的设置。",
        "Backup history was merged. Existing settings are kept; backup settings are used only when no local settings file exists."
      )
    case .replace:
      AppText.value(
        "备份已覆盖导入，历史、设置和媒体文件已按备份替换；备份缺少设置时会使用默认设置。",
        "Backup was imported by replacement. History, settings, and media files now match the backup; default settings are used if the backup has no settings file."
      )
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

}

private enum BackupCoordinatorError: Error, LocalizedError {
  case cancelled

  var errorDescription: String? {
    AppText.value("操作已取消。", "Operation cancelled.")
  }
}
