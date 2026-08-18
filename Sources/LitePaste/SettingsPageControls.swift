import LitePasteCore
import SwiftUI

struct QuickActionSettingsSheet: View {
  @Binding var visibleQuickActions: Set<ClipboardQuickAction>
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(AppText.value("操作按钮", "Action Buttons"))
        .font(.system(size: 18, weight: .bold))

      Text(AppText.value(
        "最多显示 4 个快捷按钮，更多操作始终保留在右键菜单中。",
        "Show up to 4 quick buttons. All actions remain available in the context menu."
      ))
      .font(.system(size: 12))
      .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 0) {
        ForEach(ClipboardQuickAction.displayOrder) { action in
          Toggle(isOn: binding(for: action)) {
            Label(action.localizedDisplayName, systemImage: action.iconName)
          }
          .toggleStyle(.checkbox)
          .disabled(!visibleQuickActions.contains(action) && visibleQuickActions.count >= 4)
          .padding(.vertical, 7)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      HStack {
        Spacer()
        Button(AppText.value("完成", "Done")) {
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(22)
    .frame(width: 360)
  }

  private func binding(for action: ClipboardQuickAction) -> Binding<Bool> {
    Binding {
      visibleQuickActions.contains(action)
    } set: { enabled in
      if enabled {
        visibleQuickActions.insert(action)
      } else {
        visibleQuickActions.remove(action)
      }
    }
  }
}

struct SettingsNumberStepperField: View {
  @Binding var value: Int
  let range: ClosedRange<Int>
  let step: Int
  let unit: String
  @State private var draftText = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(spacing: 8) {
      TextField("", text: $draftText)
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .multilineTextAlignment(.trailing)
        .textFieldStyle(.plain)
        .focused($isFocused)
        .frame(width: 58, height: 24)
        .padding(.horizontal, 7)
        .background(SettingsSurface.fieldBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(SettingsSurface.border.opacity(0.50), lineWidth: 1)
        )
        .onSubmit(commitDraft)
        .onAppear(perform: syncDraft)
        .onChange(of: draftText) { _, newText in
          keepDigitsOnly(newText)
        }
        .onChange(of: isFocused) { _, focused in
          if focused {
            syncDraft()
          } else {
            commitDraft()
          }
        }
        .onChange(of: value) {
          syncDraft()
        }

      Text(unit)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 14, alignment: .leading)

      Stepper("", value: clampedValue, in: range, step: step)
        .labelsHidden()
        .controlSize(.small)
    }
    .frame(maxWidth: .infinity, alignment: .trailing)
  }

  private var clampedValue: Binding<Int> {
    Binding {
      clamp(value)
    } set: { newValue in
      value = clamp(newValue)
    }
  }

  private func keepDigitsOnly(_ text: String) {
    let filtered = text.filter(\.isNumber)
    if filtered != text {
      draftText = String(filtered)
    }
  }

  private func commitDraft() {
    guard let parsedValue = Int(draftText) else {
      syncDraft()
      return
    }

    value = clamp(parsedValue)
    syncDraft()
  }

  private func syncDraft() {
    draftText = "\(clamp(value))"
  }

  private func clamp(_ candidate: Int) -> Int {
    min(max(candidate, range.lowerBound), range.upperBound)
  }
}

struct SettingsSymbolField: View {
  @Binding var text: String
  @State private var draftText = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    TextField("", text: $draftText)
      .font(.system(size: 12, weight: .medium))
      .multilineTextAlignment(.center)
      .textFieldStyle(.plain)
      .focused($isFocused)
      .frame(width: 96, height: 24)
      .padding(.horizontal, 7)
      .background(SettingsSurface.fieldBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .stroke(SettingsSurface.border.opacity(0.50), lineWidth: 1)
      )
      .onSubmit(commitDraft)
      .onAppear(perform: syncDraft)
      .onChange(of: draftText) { _, newText in
        keepSingleLine(newText)
      }
      .onChange(of: isFocused) { _, focused in
        if focused {
          syncDraft()
        } else {
          commitDraft()
        }
      }
      .onChange(of: text) {
        if !isFocused {
          syncDraft()
        }
      }
  }

  private func keepSingleLine(_ newText: String) {
    let filtered = newText.filter { !$0.isNewline }
    if filtered != newText {
      draftText = filtered
    }
  }

  private func commitDraft() {
    text = TablePlainTextFormatter.normalizedSeparator(draftText)
    syncDraft()
  }

  private func syncDraft() {
    draftText = text
  }
}
