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
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.headline)

      HStack(spacing: 8) {
        TextField(placeholder, text: $draft)
          .textFieldStyle(.roundedBorder)
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
        ForEach(sortedValues, id: \.self) { value in
          HStack(spacing: 8) {
            Text(value)
              .font(.system(.caption, design: .monospaced))
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
          .padding(.vertical, 2)
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

