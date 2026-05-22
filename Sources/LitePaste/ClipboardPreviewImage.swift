import AppKit
import SwiftUI

struct ClipboardPreviewImage: View {
  let path: String

  var body: some View {
    if let image = NSImage(contentsOfFile: path) {
      Image(nsImage: image)
        .resizable()
        .scaledToFill()
    } else {
      Image(systemName: "photo")
        .font(.system(size: 34, weight: .light))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

