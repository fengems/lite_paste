public enum SQLiteRepositoryError: Error, Equatable, Sendable {
  case openFailed(String)
  case operationFailed(String)
  case invalidRecord
}
