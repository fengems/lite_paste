import AppKit
import SwiftUI

struct ClipboardPreviewImage: View {
  let path: String
  let style: ClipboardPreviewStyle

  var body: some View {
    if let image = NSImage(contentsOfFile: path) {
      Image(nsImage: image)
        .resizable()
        .scaledToFill()
        .overlay(alignment: .bottomTrailing) {
          if style == .card, let sizeText = imageSizeText(for: image) {
            Text(sizeText)
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(.white)
              .padding(.horizontal, 7)
              .padding(.vertical, 4)
              .background(.black.opacity(0.42), in: Capsule())
              .padding(7)
          }
        }
    } else {
      MissingImagePreview(style: style)
    }
  }

  private func imageSizeText(for image: NSImage) -> String? {
    let width = Int(image.size.width.rounded())
    let height = Int(image.size.height.rounded())
    guard width > 0, height > 0 else {
      return nil
    }

    return "\(width)x\(height)"
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
