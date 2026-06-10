import Foundation

public struct ClipboardCaptureGate: Sendable {
  public var privacyFilter: PrivacyFilter

  public init(
    privacyFilter: PrivacyFilter = PrivacyFilter()
  ) {
    self.privacyFilter = privacyFilter
  }

  public func shouldRecord(payload _: ClipboardPayload) -> Bool {
    privacyFilter.shouldRecord()
  }
}
