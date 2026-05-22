import SwiftUI

struct EmptyHistoryView: View {
  var systemName = "doc.on.clipboard"
  var title = "暂无剪贴板历史"
  var message: String?

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: systemName)
        .font(.system(size: 42, weight: .light))
        .foregroundStyle(.secondary)

      Text(title)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(.secondary)

      if let message {
        Text(message)
          .font(.system(size: 13))
          .foregroundStyle(.tertiary)
          .multilineTextAlignment(.center)
      }
    }
    .padding(.horizontal, 32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
