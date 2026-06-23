import LitePasteCore

@MainActor
func checkClipboardCaptureGate() {
  let payload = ClipboardTextPayloadBuilder().payload(
    from: "hello",
    pasteboardTypes: [ClipboardTextPayloadBuilder.plainTextPasteboardType]
  )
  guard let payload else {
    fatalError("Capture gate check requires a text payload")
  }

  let defaultGate = ClipboardCaptureGate()
  expect(
    defaultGate.shouldRecord(payload: payload),
    "Capture gate should allow payloads while monitoring is active"
  )

  let pausedMonitoringGate = ClipboardCaptureGate(
    monitoringPolicy: ClipboardMonitoringPolicy(isMonitoringPaused: true)
  )
  expect(
    !pausedMonitoringGate.shouldRecord(payload: payload),
    "Capture gate should reject payloads while monitoring is paused"
  )

  let sensitivePayload = ClipboardPayload(
    kind: .text,
    title: "secret",
    searchText: "secret",
    plainText: "secret",
    pasteboardTypes: ["org.nspasteboard.ConcealedType"]
  )
  expect(
    defaultGate.shouldRecord(payload: sensitivePayload),
    "Capture gate should not filter pasteboard types while monitoring is active"
  )

  let tracker = ClipboardWriteTracker()
  tracker.markIgnoredChangeCount(100)
  let shouldSkipSelfWrite = tracker.shouldIgnore(changeCount: 100)
  let shouldRecordAfterSkip = !shouldSkipSelfWrite && defaultGate.shouldRecord(
    payload: payload
  )
  expect(shouldSkipSelfWrite, "Capture gate integration should skip Lite Paste self writes before payload checks")
  expect(!shouldRecordAfterSkip, "Self-write changes should not be recorded")
  expect(
    !tracker.shouldIgnore(changeCount: 100) && defaultGate.shouldRecord(payload: payload),
    "A consumed self-write marker should not block later captures"
  )
}
