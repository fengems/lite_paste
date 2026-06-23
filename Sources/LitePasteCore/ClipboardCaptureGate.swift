import Foundation

public struct ClipboardCaptureGate: Sendable {
  public var monitoringPolicy: ClipboardMonitoringPolicy

  public init(
    monitoringPolicy: ClipboardMonitoringPolicy = ClipboardMonitoringPolicy()
  ) {
    self.monitoringPolicy = monitoringPolicy
  }

  public func shouldRecord(payload _: ClipboardPayload) -> Bool {
    monitoringPolicy.shouldRecord()
  }
}
