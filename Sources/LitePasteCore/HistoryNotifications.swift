import Foundation

public enum HistoryNotificationUserInfoKey {
  public static let errorMessage = "errorMessage"
  public static let operation = "operation"
}

public extension Notification.Name {
  static let litePasteHistoryChanged = Notification.Name("LitePasteHistoryChanged")
  static let litePasteHistoryPersistenceFailed = Notification.Name("LitePasteHistoryPersistenceFailed")
}
