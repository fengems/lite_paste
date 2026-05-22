import AppKit
import Foundation
import LitePasteCore

@MainActor
final class ActiveApplicationTracker: ObservableObject {
  static let shared = ActiveApplicationTracker()

  @Published private(set) var lastExternalApplication: TrackedApplication?

  private var observer: NSObjectProtocol?

  private init() {}

  func start() {
    stop()
    capture(NSWorkspace.shared.frontmostApplication)
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
        return
      }

      Task { @MainActor in
        self?.capture(application)
      }
    }
  }

  func stop() {
    if let observer {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
      self.observer = nil
    }
  }

  private func capture(_ application: NSRunningApplication?) {
    guard let application,
          let bundleIdentifier = application.bundleIdentifier,
          !isLitePaste(bundleIdentifier: bundleIdentifier, name: application.localizedName) else {
      return
    }

    lastExternalApplication = TrackedApplication(
      bundleIdentifier: bundleIdentifier,
      name: application.localizedName ?? bundleIdentifier
    )
  }

  private func isLitePaste(bundleIdentifier: String, name: String?) -> Bool {
    bundleIdentifier == AppMetadata.bundleIdentifier || name == AppMetadata.displayName
  }
}

struct TrackedApplication: Equatable {
  var bundleIdentifier: String
  var name: String
}

