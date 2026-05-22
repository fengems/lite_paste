import AppKit
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController {
  func setEnabled(_ enabled: Bool) throws {
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
      print("Unable to update launch at login: \(error)")
    }
  }
}

