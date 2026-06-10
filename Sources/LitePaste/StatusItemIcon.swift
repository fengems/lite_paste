import AppKit

enum StatusItemIcon {
  static func makeImage() -> NSImage {
    let symbolName = SettingsPage.clipboard.systemImage
    let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: AppText.value("剪贴板", "Clipboard"))
      ?? NSImage(size: NSSize(width: 18, height: 18))
    let configuredImage = image.withSymbolConfiguration(.init(pointSize: 16, weight: .regular)) ?? image
    configuredImage.isTemplate = true
    configuredImage.size = NSSize(width: 18, height: 18)
    return configuredImage
  }
}
