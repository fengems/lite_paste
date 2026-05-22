import SwiftUI

struct EmptyHistoryView: View {
  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "doc.on.clipboard")
        .font(.system(size: 42, weight: .light))
        .foregroundStyle(.secondary)

      Text("暂无剪贴板历史")
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

