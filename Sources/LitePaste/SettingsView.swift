import LitePasteCore
import SwiftUI

struct SettingsView: View {
  @ObservedObject private var store = AppSettingsStore.shared
  @State private var backupCoordinator = BackupCoordinator()

  var body: some View {
    Form {
      Section("通用") {
        Toggle("开机启动", isOn: launchAtLogin)
        LabeledContent("打开面板快捷键", value: store.settings.hotkey)
      }

      Section("剪贴板") {
        Toggle("默认纯文本粘贴", isOn: pastePlainByDefault)

        Picker("默认操作", selection: autoPasteMode) {
          Text("仅复制").tag(AutoPasteMode.copyOnly)
          Text("自动粘贴").tag(AutoPasteMode.paste)
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
      store.update { $0.launchAtLogin = value }
    }
  }

  private var pastePlainByDefault: Binding<Bool> {
    Binding {
      store.settings.pastePlainByDefault
    } set: { value in
      store.update { $0.pastePlainByDefault = value }
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
}
