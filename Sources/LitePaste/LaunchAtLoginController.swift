import AppKit
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController {
  func setEnabled(_ enabled: Bool) throws {
    if isAlreadyInDesiredState(enabled) {
      return
    }

    if enabled {
      try SMAppService.mainApp.register()
    } else {
      try SMAppService.mainApp.unregister()
    }
  }

  func sync(with enabled: Bool) {
    do {
      try setEnabled(enabled)
    } catch {
      NSLog("Unable to update Lite Paste launch at login: \(error)")
    }
  }

  private func isAlreadyInDesiredState(_ enabled: Bool) -> Bool {
    let status = SMAppService.mainApp.status

    if enabled {
      return status == .enabled
    }

    switch status {
    case .notRegistered, .notFound:
      return true
    case .enabled, .requiresApproval:
      return false
    @unknown default:
      return false
    }
  }
}
