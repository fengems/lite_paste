import Foundation

public struct ClipboardCaptureGate: Sendable {
  public var enabledTypes: Set<ClipboardKind>
  public var privacyFilter: PrivacyFilter

  public init(
    enabledTypes: Set<ClipboardKind> = Set(ClipboardKind.allCases),
    privacyFilter: PrivacyFilter = PrivacyFilter()
  ) {
    self.enabledTypes = enabledTypes
    self.privacyFilter = privacyFilter
  }

  public func shouldRecord(
    payload: ClipboardPayload,
    sourceAppBundleId: String?
  ) -> Bool {
    guard enabledTypes.contains(payload.kind) else {
      return false
    }

    return privacyFilter.shouldRecord(
      sourceAppBundleId: sourceAppBundleId,
      pasteboardTypes: payload.pasteboardTypes
    )
  }
}
