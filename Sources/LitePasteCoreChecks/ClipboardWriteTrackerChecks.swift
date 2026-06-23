import LitePasteCore

@MainActor
func checkClipboardWriteTracker() {
  let tracker = ClipboardWriteTracker()
  tracker.markIgnoredChangeCount(42)

  expect(tracker.shouldIgnore(changeCount: 42), "ClipboardWriteTracker should ignore marked change count")
  expect(!tracker.shouldIgnore(changeCount: 42), "ClipboardWriteTracker should consume ignored change count once")
  expect(!tracker.shouldIgnore(changeCount: 43), "ClipboardWriteTracker should not ignore unmarked change count")
}
