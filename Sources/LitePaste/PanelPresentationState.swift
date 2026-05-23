import Combine
import Foundation

@MainActor
final class PanelPresentationState: ObservableObject {
  @Published private(set) var openRevision = 0
  @Published private(set) var actionMessage: String?

  private var actionMessageRevision = 0

  func markOpened() {
    openRevision += 1
    clearActionMessage()
  }

  func showActionMessage(_ message: String) {
    actionMessageRevision += 1
    let revision = actionMessageRevision

    actionMessage = message

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
      Task { @MainActor in
        guard let self, self.actionMessageRevision == revision else {
          return
        }

        self.actionMessage = nil
      }
    }
  }

  private func clearActionMessage() {
    actionMessageRevision += 1
    actionMessage = nil
  }
}
