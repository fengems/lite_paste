import AppKit
import LitePasteCore
import QuickLookThumbnailing
import SwiftUI

struct FileClipboardPreview: View {
  let record: ClipboardRecord
  let style: ClipboardPreviewStyle

  var body: some View {
    let items = fileItems

    switch style {
    case .card:
      fileGrid(for: items)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

    case .thumbnail:
      if let firstItem = items.first {
        fileIcon(for: firstItem, size: 34)
          .padding(2)
      } else {
        FallbackClipboardPreview(record: record, style: style)
      }
    }
  }

  private func fileIcon(for item: FilePreviewItem, size: CGFloat) -> some View {
    FileThumbnailPreview(item: item, size: size)
      .opacity(item.exists ? 1 : 0.46)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
      .overlay(alignment: .bottomTrailing) {
        if !item.exists {
          Image(systemName: "exclamationmark.circle.fill")
            .font(.system(size: 11, weight: .bold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .orange)
            .padding(1)
        }
      }
  }

  private func fileGrid(for items: [FilePreviewItem]) -> some View {
    let visibleItems = items.count > 4 ? Array(items.prefix(3)) : Array(items.prefix(4))

    return LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2),
      alignment: .leading,
      spacing: 6
    ) {
      ForEach(visibleItems, id: \.url) { item in
        fileIcon(for: item, size: 50)
      }

      if items.count > visibleItems.count {
        Text("+\(items.count - visibleItems.count)")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.secondary)
          .frame(width: 50, height: 50)
          .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
      }
    }
  }

  private var fileURLs: [URL] {
    record.contents
      .sorted { $0.displayOrder < $1.displayOrder }
      .compactMap { snapshot -> URL? in
        guard let data = snapshot.inlineData,
              let path = String(data: data, encoding: .utf8),
              !path.isEmpty else {
          return nil
        }
        return URL(fileURLWithPath: path)
      }
  }

  private var fileItems: [FilePreviewItem] {
    fileURLs.map(FilePreviewItem.init(url:))
  }
}

private struct FilePreviewItem {
  let url: URL
  let exists: Bool
  let isDirectory: Bool

  init(url: URL) {
    self.url = url
    var isDirectoryValue: ObjCBool = false
    exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectoryValue)
    isDirectory = isDirectoryValue.boolValue
  }
}

private struct FileThumbnailPreview: View {
  let item: FilePreviewItem
  let size: CGFloat
  @State private var thumbnail: NSImage?

  var body: some View {
    ZStack {
      if let thumbnail {
        Image(nsImage: thumbnail)
          .resizable()
          .scaledToFill()
      } else {
        Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
          .resizable()
          .scaledToFit()
          .padding(size * 0.14)
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(alignment: .bottomLeading) {
      if item.isDirectory {
        Image(systemName: "folder.fill")
          .font(.system(size: max(9, size * 0.24), weight: .semibold))
          .foregroundStyle(.blue)
          .padding(3)
      }
    }
    .task(id: item.url.path) {
      if let data = await loadThumbnailData(for: item.url, size: size) {
        thumbnail = NSImage(data: data)
      } else {
        thumbnail = nil
      }
    }
  }

  private func loadThumbnailData(for url: URL, size: CGFloat) async -> Data? {
    guard item.exists else {
      return nil
    }

    let request = QLThumbnailGenerator.Request(
      fileAt: url,
      size: CGSize(width: size * 2, height: size * 2),
      scale: NSScreen.main?.backingScaleFactor ?? 2,
      representationTypes: [.thumbnail, .icon]
    )

    return await withCheckedContinuation { continuation in
      QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
        continuation.resume(returning: representation?.nsImage.tiffRepresentation)
      }
    }
  }
}
