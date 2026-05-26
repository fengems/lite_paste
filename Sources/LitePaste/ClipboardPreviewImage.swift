import AppKit
import SwiftUI

struct ClipboardPreviewImage: View {
  let path: String
  let style: ClipboardPreviewStyle

  var body: some View {
    if let image = NSImage(contentsOfFile: path) {
      switch style {
      case .card:
        Image(nsImage: image)
          .resizable()
          .scaledToFit()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      case .thumbnail:
        Image(nsImage: image)
          .resizable()
          .scaledToFill()
      }
    } else {
      MissingImagePreview(style: style)
    }
  }
}

private struct MissingImagePreview: View {
  let style: ClipboardPreviewStyle

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: style == .card ? 8 : 6)
        .fill(Color.secondary.opacity(0.11))

      VStack(spacing: style == .card ? 6 : 0) {
        Image(systemName: "photo.badge.exclamationmark")
          .font(.system(size: style == .card ? 30 : 16, weight: .light))
          .foregroundStyle(.secondary)

        if style == .card {
          Text("图片已缺失")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
