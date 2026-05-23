import Foundation

public enum SettingsNotificationUserInfoKey {
  public static let errorMessage = "errorMessage"
}

public extension Notification.Name {
  static let litePasteSettingsSaveFailed = Notification.Name("LitePasteSettingsSaveFailed")
}
