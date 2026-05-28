import Foundation

public enum PermissionGuideItem: String, CaseIterable, Codable, Equatable, Sendable {
  case accessibility
}

public struct PermissionGuideState: Equatable, Sendable {
  public private(set) var dismissedForSession: Bool

  public init(dismissedForSession: Bool = false) {
    self.dismissedForSession = dismissedForSession
  }

  public func missingItems(accessibilityTrusted: Bool) -> [PermissionGuideItem] {
    accessibilityTrusted ? [] : [.accessibility]
  }

  public func shouldPresent(accessibilityTrusted: Bool) -> Bool {
    !dismissedForSession && !missingItems(accessibilityTrusted: accessibilityTrusted).isEmpty
  }

  public mutating func dismissForSession() {
    dismissedForSession = true
  }
}
