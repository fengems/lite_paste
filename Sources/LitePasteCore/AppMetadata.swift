import Foundation

public enum AppMetadata {
  public static let displayName = "Lite Paste"
  public static let bundleIdentifier = "com.fengems.LitePaste"
  public static let version = "0.1.1"
  public static let build = "1"
  public static let minimumMacOSVersion = "15.0"
  public static let licenseName = "Private / All rights reserved"
  public static let repositoryURL = URL(string: "https://github.com/fengems/lite_paste")!

  public static var versionSummary: String {
    "\(version) (\(build))"
  }
}
