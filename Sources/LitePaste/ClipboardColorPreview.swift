import LitePasteCore
import SwiftUI

struct ColorClipboardPreview: View {
  let record: ClipboardRecord
  let style: ClipboardPreviewStyle

  var body: some View {
    let parsedColor = ParsedHexColor(text: record.plainText ?? record.title)

    switch style {
    case .card:
      VStack(alignment: .leading, spacing: 10) {
        RoundedRectangle(cornerRadius: 10)
          .fill(parsedColor?.color ?? Color.secondary.opacity(0.18))
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(.white.opacity(0.18), lineWidth: 1)
          )
          .frame(height: 58)

        Text(parsedColor?.normalizedText ?? record.title)
          .font(.system(size: 16, weight: .semibold))
          .textSelection(.enabled)

        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

    case .thumbnail:
      RoundedRectangle(cornerRadius: 8)
        .fill(parsedColor?.color ?? Color.secondary.opacity(0.18))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .padding(3)
    }
  }
}

private struct ParsedHexColor {
  let normalizedText: String
  let color: Color

  init?(text: String) {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let hex = value.hasPrefix("#") ? String(value.dropFirst()) : value

    guard [3, 6, 8].contains(hex.count),
          let number = UInt64(hex, radix: 16) else {
      return nil
    }

    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    if hex.count == 3 {
      red = Double((number >> 8) & 0xF) / 15
      green = Double((number >> 4) & 0xF) / 15
      blue = Double(number & 0xF) / 15
      alpha = 1
    } else if hex.count == 6 {
      red = Double((number >> 16) & 0xFF) / 255
      green = Double((number >> 8) & 0xFF) / 255
      blue = Double(number & 0xFF) / 255
      alpha = 1
    } else {
      red = Double((number >> 24) & 0xFF) / 255
      green = Double((number >> 16) & 0xFF) / 255
      blue = Double((number >> 8) & 0xFF) / 255
      alpha = Double(number & 0xFF) / 255
    }

    normalizedText = "#\(hex.uppercased())"
    color = Color(red: red, green: green, blue: blue, opacity: alpha)
  }
}
