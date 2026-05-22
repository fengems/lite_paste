import LitePasteCore
import SwiftUI

struct SettingsView: View {
  @ObservedObject private var store = AppSettingsStore.shared
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

        Picker("默认操作", selection: autoPasteMode) {
          Text("仅复制").tag(AutoPasteMode.copyOnly)
          Text("自动粘贴").tag(AutoPasteMode.paste)
        }

        Stepper("最大历史数量: \(store.settings.maxHistoryCount)", value: maxHistoryCount, in: 50...10_000, step: 50)

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

  private var clearSearchOnOpen: Binding<Bool> {
    Binding {
      store.settings.clearSearchOnOpen
    } set: { value in
      store.update { $0.clearSearchOnOpen = value }
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

  private var privacyMode: Binding<Bool> {
    Binding {
      store.settings.privacyMode
    } set: { value in
      store.update { $0.privacyMode = value }
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

  private func showAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: "好")
    alert.alertStyle = .warning
    alert.runModal()
  }
}
