import Foundation

@MainActor
public final class ClipboardWriteTracker {
  private var ignoredChangeCounts = Set<Int>()

  public init() {}

  public func markIgnoredChangeCount(_ changeCount: Int) {
    ignoredChangeCounts.insert(changeCount)
  }

  public func shouldIgnore(changeCount: Int) -> Bool {
    ignoredChangeCounts.remove(changeCount) != nil
  }
}
