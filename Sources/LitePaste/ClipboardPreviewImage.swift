import AppKit
import ImageIO
import SwiftUI

struct ClipboardPreviewImage: View {
  let path: String
  let style: ClipboardPreviewStyle
  @State private var image: CGImage?
  @State private var didFailLoading = false

  var body: some View {
    Group {
      if let image {
        renderedImage(image)
      } else if didFailLoading {
        MissingImagePreview(style: style)
      } else {
        LoadingImagePreview(style: style)
      }
    }
    .task(id: loadingKey) {
      await loadImage()
    }
  }

  private var loadingKey: String {
    "\(path)|\(style.previewImageCacheKey)"
  }

  @ViewBuilder
  private func renderedImage(_ image: CGImage) -> some View {
    switch style {
    case .card:
      Image(decorative: image, scale: 1, orientation: .up)
        .resizable()
        .scaledToFit()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .thumbnail:
      Image(decorative: image, scale: 1, orientation: .up)
        .resizable()
        .scaledToFill()
    }
  }

  @MainActor
  private func loadImage() async {
    image = nil
    didFailLoading = false

    let path = path
    let maxPixelSize = style.previewImageMaxPixelSize
    let loadedImage = await Task.detached(priority: .utility) {
      ClipboardPreviewImageLoader.load(path: path, maxPixelSize: maxPixelSize)
    }.value

    guard !Task.isCancelled else {
      return
    }

    image = loadedImage
    didFailLoading = loadedImage == nil
  }
}

private enum ClipboardPreviewImageLoader {
  static func load(path: String, maxPixelSize: Int) -> CGImage? {
    let url = URL(fileURLWithPath: path)
    let sourceOptions: [CFString: Any] = [
      kCGImageSourceShouldCache: false
    ]
    guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
      return nil
    }

    let thumbnailOptions: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
    ]

    return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
  }
}

private extension ClipboardPreviewStyle {
  var previewImageCacheKey: String {
    switch self {
    case .card:
      "card"
    case .thumbnail:
      "thumbnail"
    }
  }

  var previewImageMaxPixelSize: Int {
    switch self {
    case .card:
      720
    case .thumbnail:
      128
    }
  }
}

private struct LoadingImagePreview: View {
  let style: ClipboardPreviewStyle

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: style == .card ? 8 : 6)
        .fill(Color.secondary.opacity(0.09))

      ProgressView()
        .controlSize(style == .card ? .small : .mini)
        .opacity(0.7)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
