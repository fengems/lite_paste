import Foundation

public enum AppFlavor: String, Sendable {
  case stable
  case dev

  public static let environmentKey = "LITEPASTE_FLAVOR"

  public static var current: AppFlavor {
    current(
      environment: ProcessInfo.processInfo.environment,
      bundleIdentifier: Bundle.main.bundleIdentifier
    )
  }

  public static func current(
    environment: [String: String],
    bundleIdentifier: String? = Bundle.main.bundleIdentifier
  ) -> AppFlavor {
    if let flavor = normalized(environment[environmentKey]) {
      return flavor
    }

    if bundleIdentifier == dev.bundleIdentifier {
      return .dev
    }

    return .stable
  }

  public var displayName: String {
    switch self {
    case .stable:
      "Lite Paste"
    case .dev:
      "Lite Paste Dev"
    }
  }

  public var bundleIdentifier: String {
    switch self {
    case .stable:
      "com.fengems.LitePaste"
    case .dev:
      "com.fengems.LitePaste.dev"
    }
  }

  public var applicationSupportDirectoryName: String {
    switch self {
    case .stable:
      "LitePaste"
    case .dev:
      "LitePaste-Dev"
    }
  }

  public var defaultPanelHotkey: String {
    switch self {
    case .stable:
      "command+shift+v"
    case .dev:
      "command+option+shift+v"
    }
  }

  private static func normalized(_ value: String?) -> AppFlavor? {
    guard let value = value?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased(),
      !value.isEmpty else {
      return nil
    }

    switch value {
    case "stable", "release", "production":
      return .stable
    case "dev", "development":
      return .dev
    default:
      return nil
    }
  }
}
