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
        .font(.system(size: 14, weight: .semibold))

      HStack(spacing: 8) {
        TextField(placeholder, text: $draft)
          .textFieldStyle(.plain)
          .font(.system(size: 13))
          .padding(.horizontal, 10)
          .frame(height: 30)
          .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
          .onSubmit(addDraft)

        Button {
          addDraft()
        } label: {
          Image(systemName: "plus")
        }
        .buttonStyle(.bordered)
        .disabled(normalizedDraft.isEmpty)
        .accessibilityLabel("添加")
      }

      if sortedValues.isEmpty {
        Text("暂无")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        VStack(spacing: 6) {
          ForEach(sortedValues, id: \.self) { value in
            HStack(spacing: 8) {
              Text(value)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)

              Spacer()

              Button {
                values.remove(value)
              } label: {
                Image(systemName: "minus.circle")
              }
              .buttonStyle(.plain)
              .accessibilityLabel("删除")
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
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
