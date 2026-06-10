import Foundation

public struct PrivacyFilter: Sendable {
  public var isMonitoringPaused: Bool

  public init(
    isMonitoringPaused: Bool = false
  ) {
    self.isMonitoringPaused = isMonitoringPaused
  }

  public func shouldRecord() -> Bool {
    !isMonitoringPaused
  }
}
