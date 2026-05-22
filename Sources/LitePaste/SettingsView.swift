import LitePasteCore
import SwiftUI

struct SettingsView: View {
  @ObservedObject private var store = AppSettingsStore.shared
  @ObservedObject private var activeApplicationTracker = ActiveApplicationTracker.shared
  @State private var backupCoordinator = BackupCoordinator()
  @State private var launchAtLoginController = LaunchAtLoginController()

  var body: some View {
    Form {
      Section("通用") {
        Toggle("开机启动", isOn: launchAtLogin)
        LabeledContent("打开面板快捷键", value: store.settings.hotkey)

        Picker("默认视图", selection: viewMode) {
          Text("卡片").tag(ClipboardPanelViewMode.card)
          Text("列表").tag(ClipboardPanelViewMode.list)
        }

        Toggle("打开面板时清空搜索", isOn: clearSearchOnOpen)
      }

      Section("剪贴板") {
        Toggle("默认纯文本粘贴", isOn: pastePlainByDefault)
        Toggle("自动粘贴后恢复原剪贴板", isOn: restoreClipboardAfterPaste)

        Picker("默认操作", selection: autoPasteMode) {
          Text("仅复制").tag(AutoPasteMode.copyOnly)
          Text("自动粘贴").tag(AutoPasteMode.paste)
        }

        Toggle("重复复制时移到顶部", isOn: moveDuplicatesToTop)

        Stepper("最大历史数量: \(store.settings.maxHistoryCount)", value: maxHistoryCount, in: 50...10_000, step: 50)
        Stepper(retentionDaysLabel, value: retentionDays, in: 0...365, step: 1)

        VStack(alignment: .leading, spacing: 8) {
          Text("记录类型")
            .font(.headline)

          ForEach(recordableKinds) { kind in
            Toggle(kind.displayName, isOn: enabledTypeBinding(kind))
          }
        }
      }

      Section("隐私") {
        Toggle("私密模式", isOn: privacyMode)

        Button {
          addLastExternalApplicationToIgnoredApps()
        } label: {
          Label(addCurrentApplicationLabel, systemImage: "app.badge")
        }
        .disabled(activeApplicationTracker.lastExternalApplication == nil)

        EditableStringList(
          title: "忽略应用 Bundle ID",
          placeholder: "com.example.SecretApp",
          values: ignoredApps
        )

        EditableStringList(
          title: "忽略剪贴板类型",
          placeholder: "org.nspasteboard.TransientType",
          values: ignoredPasteboardTypes
        )

        Button {
          resetIgnoredPasteboardTypes()
        } label: {
          Label("恢复默认忽略类型", systemImage: "arrow.counterclockwise")
        }
      }

      Section("备份") {
        HStack {
          Button {
            backupCoordinator.exportBackup()
          } label: {
            Label("导出", systemImage: "square.and.arrow.up")
          }

          Button {
            backupCoordinator.importBackup(mode: .merge)
          } label: {
            Label("合并导入", systemImage: "arrow.triangle.merge")
          }

          Button {
            backupCoordinator.importBackup(mode: .replace)
          } label: {
            Label("覆盖导入", systemImage: "arrow.down.doc")
          }
        }
      }

      Section("关于") {
        LabeledContent("应用", value: AppMetadata.displayName)
        LabeledContent("版本", value: AppMetadata.versionSummary)
        LabeledContent("Bundle ID", value: AppMetadata.bundleIdentifier)
        LabeledContent("最低系统", value: "macOS \(AppMetadata.minimumMacOSVersion)+")
      }
    }
    .padding(24)
    .frame(width: 520)
  }

  private var launchAtLogin: Binding<Bool> {
    Binding {
      store.settings.launchAtLogin
    } set: { value in
      do {
        try launchAtLoginController.setEnabled(value)
        store.update { $0.launchAtLogin = value }
      } catch {
        showAlert(title: "无法更新开机启动", message: error.localizedDescription)
      }
    }
  }

  private var pastePlainByDefault: Binding<Bool> {
    Binding {
      store.settings.pastePlainByDefault
    } set: { value in
      store.update { $0.pastePlainByDefault = value }
    }
  }

  private var restoreClipboardAfterPaste: Binding<Bool> {
    Binding {
      store.settings.restoreClipboardAfterPaste
    } set: { value in
      store.update { $0.restoreClipboardAfterPaste = value }
    }
  }

  private var clearSearchOnOpen: Binding<Bool> {
    Binding {
      store.settings.clearSearchOnOpen
    } set: { value in
      store.update { $0.clearSearchOnOpen = value }
    }
  }

  private var moveDuplicatesToTop: Binding<Bool> {
    Binding {
      store.settings.moveDuplicatesToTop
    } set: { value in
      store.update { $0.moveDuplicatesToTop = value }
    }
  }

  private var viewMode: Binding<ClipboardPanelViewMode> {
    Binding {
      store.settings.viewMode
    } set: { value in
      store.update { $0.viewMode = value }
    }
  }

  private var maxHistoryCount: Binding<Int> {
    Binding {
      store.settings.maxHistoryCount
    } set: { value in
      store.update { $0.maxHistoryCount = value }
    }
  }

  private var retentionDays: Binding<Int> {
    Binding {
      store.settings.retentionDays
    } set: { value in
      store.update { $0.retentionDays = value }
    }
  }

  private var retentionDaysLabel: String {
    if store.settings.retentionDays == 0 {
      "历史保留: 永久"
    } else {
      "历史保留: \(store.settings.retentionDays) 天"
    }
  }

  private var privacyMode: Binding<Bool> {
    Binding {
      store.settings.privacyMode
    } set: { value in
      store.update { $0.privacyMode = value }
    }
  }

  private var ignoredApps: Binding<Set<String>> {
    Binding {
      store.settings.ignoredApps
    } set: { value in
      store.update { $0.ignoredApps = value }
    }
  }

  private var ignoredPasteboardTypes: Binding<Set<String>> {
    Binding {
      store.settings.ignoredPasteboardTypes
    } set: { value in
      store.update { $0.ignoredPasteboardTypes = value }
    }
  }

  private var autoPasteMode: Binding<AutoPasteMode> {
    Binding {
      store.settings.autoPasteMode
    } set: { value in
      store.update { $0.autoPasteMode = value }
    }
  }

  private var recordableKinds: [ClipboardKind] {
    [.text, .richText, .html, .image, .files, .url, .email, .color]
  }

  private func enabledTypeBinding(_ kind: ClipboardKind) -> Binding<Bool> {
    Binding {
      store.settings.enabledTypes.contains(kind)
    } set: { enabled in
      store.update { settings in
        if enabled {
          settings.enabledTypes.insert(kind)
        } else {
          settings.enabledTypes.remove(kind)
        }
      }
    }
  }

  private func resetIgnoredPasteboardTypes() {
    store.update { $0.ignoredPasteboardTypes = PrivacyFilter.defaultIgnoredPasteboardTypes }
  }

  private var addCurrentApplicationLabel: String {
    guard let application = activeApplicationTracker.lastExternalApplication else {
      return "添加最近使用的应用"
    }

    return "忽略 \(application.name)"
  }

  private func addLastExternalApplicationToIgnoredApps() {
    guard let application = activeApplicationTracker.lastExternalApplication else {
      return
    }

    store.update { $0.ignoredApps.insert(application.bundleIdentifier) }
  }

  private func showAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: "好")
    alert.alertStyle = .warning
    alert.runModal()
  }
}
