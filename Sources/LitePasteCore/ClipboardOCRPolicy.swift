import Foundation

public enum ClipboardOCRPolicy {
  public static func shouldSkipImageOCR(
    pasteboardTypes: Set<String>,
    sourceAppBundleId: String?,
    plainText: String?
  ) -> Bool {
    if ClipboardPayloadResolver.isTabularPlainText(plainText) {
      return true
    }

    if isSpreadsheetSourceApp(sourceAppBundleId) {
      return true
    }

    return pasteboardTypes.contains(where: isSpreadsheetPasteboardType)
  }

  public static func isSpreadsheetSourceApp(_ bundleId: String?) -> Bool {
    guard let bundleId = bundleId?.lowercased() else {
      return false
    }

    return spreadsheetSourceAppMarkers.contains { bundleId.contains($0) }
  }

  public static func isSpreadsheetPasteboardType(_ pasteboardType: String) -> Bool {
    let type = pasteboardType.lowercased()
    return spreadsheetPasteboardTypeMarkers.contains { type.contains($0) }
  }

  private static let spreadsheetSourceAppMarkers = [
    "microsoft.excel",
    "apple.iwork.numbers",
    "apple.numbers",
    "kingsoft",
    "wpsoffice",
    ".wps"
  ]

  private static let spreadsheetPasteboardTypeMarkers = [
    "microsoft.excel",
    "spreadsheet",
    "worksheet",
    "apple.numbers",
    "kingsoft",
    "wpsoffice",
    ".wps"
  ]
}
