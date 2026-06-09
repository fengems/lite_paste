import AppKit
import LitePasteCore
import SwiftUI

struct SourceAppIcon: View {
  let record: ClipboardRecord
  var size: CGFloat = 34
  var cornerRadius: CGFloat = 8
  var symbolSize: CGFloat = 15

  var body: some View {
    Group {
      if let image = appIcon {
        Image(nsImage: image)
          .resizable()
          .scaledToFill()
      } else {
        Image(systemName: record.kind.previewIconName)
          .font(.system(size: symbolSize, weight: .semibold))
          .foregroundStyle(record.kind.accentColor)
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    .shadow(color: record.kind.accentColor.opacity(0.12), radius: 8, y: 3)
    .accessibilityLabel(record.sourceAppName ?? AppText.value("来源应用", "Source App"))
  }

  private var appIcon: NSImage? {
    guard let bundleId = record.sourceAppBundleId,
          let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
      return nil
    }
    return NSWorkspace.shared.icon(forFile: url.path)
  }
}
