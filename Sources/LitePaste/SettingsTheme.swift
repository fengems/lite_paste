import AppKit
import SwiftUI

enum SettingsSurface {
  static let windowBackground = dynamicColor(
    light: NSColor(calibratedWhite: 0.99, alpha: 1),
    dark: NSColor(calibratedWhite: 0.145, alpha: 1)
  )
  static let sidebarBackground = dynamicColor(
    light: NSColor(calibratedWhite: 0.985, alpha: 1),
    dark: NSColor(calibratedWhite: 0.13, alpha: 1)
  )
  static let cardBackground = dynamicColor(
    light: NSColor(calibratedWhite: 0.965, alpha: 1),
    dark: NSColor(calibratedWhite: 0.165, alpha: 1)
  )
  static let fieldBackground = dynamicColor(
    light: NSColor(calibratedWhite: 0.925, alpha: 1),
    dark: NSColor(calibratedWhite: 0.195, alpha: 1)
  )
  static let separator = dynamicColor(
    light: NSColor(calibratedWhite: 0.875, alpha: 1),
    dark: NSColor(calibratedWhite: 0.22, alpha: 1)
  )
  static let border = separator.opacity(0.48)

  private static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
      let mode = appearance.bestMatch(from: [.darkAqua, .aqua])
      return mode == .darkAqua ? dark : light
    })
  }
}

enum SettingsControlMetrics {
  static let columnWidth: CGFloat = 176
  static let menuWidth: CGFloat = columnWidth
  static let segmentedWidth: CGFloat = columnWidth
  static let actionButtonControlSize: ControlSize = .large
}
