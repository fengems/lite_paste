@preconcurrency import AppKit
import SwiftUI

struct PanelKeyboardBridge: NSViewRepresentable {
  var handleKeyDown: (NSEvent) -> Bool

  func makeCoordinator() -> Coordinator {
    Coordinator(handleKeyDown: handleKeyDown)
  }

  func makeNSView(context: Context) -> NSView {
    let view = KeyboardBridgeView(frame: .zero)
    view.windowDidChange = { [weak coordinator = context.coordinator] window in
      coordinator?.targetWindow = window
    }
    context.coordinator.targetWindow = view.window
    context.coordinator.install()
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    context.coordinator.handleKeyDown = handleKeyDown
  }

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    coordinator.uninstall()
  }

  final class Coordinator {
    weak var targetWindow: NSWindow?
    var handleKeyDown: (NSEvent) -> Bool
    private var monitor: Any?

    init(handleKeyDown: @escaping (NSEvent) -> Bool) {
      self.handleKeyDown = handleKeyDown
    }

    func install() {
      guard monitor == nil else {
        return
      }

      monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        guard let self, event.window === self.targetWindow else {
          return event
        }

        return self.handleKeyDown(event) ? nil : event
      }
    }

    func uninstall() {
      if let monitor {
        NSEvent.removeMonitor(monitor)
      }
      monitor = nil
    }

    deinit {
      if let monitor {
        NSEvent.removeMonitor(monitor)
      }
    }
  }
}

private final class KeyboardBridgeView: NSView {
  var windowDidChange: ((NSWindow?) -> Void)?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    windowDidChange?(window)
  }
}
