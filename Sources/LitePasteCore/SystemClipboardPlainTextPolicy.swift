import Foundation

public struct SystemClipboardPlainTextPolicy: Sendable, Equatable {
  public var sanitizesSystemClipboardOnCopy: Bool
  public var copyPlainTextByDefault: Bool
  public var pastePlainTextByDefault: Bool

  public init(
    sanitizesSystemClipboardOnCopy: Bool = false,
    copyPlainTextByDefault: Bool = false,
    pastePlainTextByDefault: Bool = false
  ) {
    self.sanitizesSystemClipboardOnCopy = sanitizesSystemClipboardOnCopy
    self.copyPlainTextByDefault = copyPlainTextByDefault
    self.pastePlainTextByDefault = pastePlainTextByDefault
  }

  public func shouldRewrite(payload: ClipboardPayload) -> Bool {
    guard sanitizesSystemClipboardOnCopy,
          copyPlainTextByDefault || pastePlainTextByDefault,
          payload.kind == .richText || payload.kind == .html,
          let plainText = payload.plainText,
          !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return false
    }

    return true
  }
}
