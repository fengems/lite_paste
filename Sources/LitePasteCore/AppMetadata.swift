import Foundation

public enum AppMetadata {
  public static var displayName: String {
    guard isKnownAppBundle else {
      return AppFlavor.current.displayName
    }

    return Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? AppFlavor.current.displayName
  }

  public static var bundleIdentifier: String {
    guard let bundleIdentifier = Bundle.main.bundleIdentifier,
          isKnownBundleIdentifier(bundleIdentifier) else {
      return AppFlavor.current.bundleIdentifier
    }

    return bundleIdentifier
  }

  public static let version = "0.1.8"
  public static let build = "1"
  public static let minimumMacOSVersion = "15.0"
  public static let licenseName = "MIT License"
  public static let repositoryURL = URL(string: "https://github.com/fengems/lite_paste")!

  public static var versionSummary: String {
    "\(version) (\(build))"
  }

  private static var isKnownAppBundle: Bool {
    guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
      return false
    }

    return isKnownBundleIdentifier(bundleIdentifier)
  }

  private static func isKnownBundleIdentifier(_ bundleIdentifier: String) -> Bool {
    bundleIdentifier == AppFlavor.stable.bundleIdentifier ||
      bundleIdentifier == AppFlavor.dev.bundleIdentifier
  }
}
