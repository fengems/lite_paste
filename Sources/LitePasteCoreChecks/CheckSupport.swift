import Foundation
import LitePasteCore

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
  guard condition() else {
    fatalError(message)
  }
}

func withTemporaryDirectory<T>(
  prefix: String,
  _ operation: (URL) throws -> T
) throws -> T {
  let directory = FileManager.default.temporaryDirectory
    .appending(path: "\(prefix)-\(UUID().uuidString)", directoryHint: .isDirectory)

  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer {
    try? FileManager.default.removeItem(at: directory)
  }

  return try operation(directory)
}

final class NotificationCounter: @unchecked Sendable {
  var count = 0
}

final class NotificationMessageSink: @unchecked Sendable {
  var messages: [String] = []
}

func waitForAsync<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) throws -> T {
  let semaphore = DispatchSemaphore(value: 0)
  let resultBox = AsyncResultBox<T>()

  Task.detached {
    do {
      resultBox.result = .success(try await operation())
    } catch {
      resultBox.result = .failure(error)
    }
    semaphore.signal()
  }

  semaphore.wait()
  guard let result = resultBox.result else {
    throw ICloudBackupError.unavailable
  }

  return try result.get()
}

final class AsyncResultBox<T: Sendable>: @unchecked Sendable {
  var result: Result<T, Error>?
}
