import Foundation
import LitePasteCore

Task { @MainActor in
  exit(runChecks())
}

RunLoop.main.run()
