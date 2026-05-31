import SwiftUI

struct EditableStringList: View {
  let title: String
  let placeholder: String
  @Binding var values: Set<String>

  @State private var draft = ""

  private var sortedValues: [String] {
    values.sorted()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.system(size: 13, weight: .semibold))

      HStack(spacing: 8) {
        TextField(placeholder, text: $draft)
          .textFieldStyle(.plain)
          .font(.system(size: 12))
          .padding(.horizontal, 9)
          .frame(height: 32)
          .background(SettingsSurface.fieldBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .stroke(SettingsSurface.border.opacity(0.55), lineWidth: 1)
          )
          .onSubmit(addDraft)

        Button {
          addDraft()
        } label: {
          Image(systemName: "plus")
        }
        .buttonStyle(.bordered)
        .controlSize(SettingsControlMetrics.actionButtonControlSize)
        .disabled(normalizedDraft.isEmpty)
        .accessibilityLabel(AppText.value("添加", "Add"))
      }

      if sortedValues.isEmpty {
        Text(AppText.value("暂无", "None"))
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        VStack(spacing: 6) {
          ForEach(sortedValues, id: \.self) { value in
            HStack(spacing: 8) {
              Text(value)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)

              Spacer()

              Button {
                values.remove(value)
              } label: {
                Image(systemName: "minus.circle")
              }
              .buttonStyle(.plain)
              .accessibilityLabel(AppText.value("删除", "Delete"))
            }
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(SettingsSurface.fieldBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(SettingsSurface.border.opacity(0.42), lineWidth: 1)
            )
          }
        }
      }
    }
  }

  private var normalizedDraft: String {
    draft.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func addDraft() {
    let value = normalizedDraft
    guard !value.isEmpty else {
      return
    }

    values.insert(value)
    draft = ""
  }
}
