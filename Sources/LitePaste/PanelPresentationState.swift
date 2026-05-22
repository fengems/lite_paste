import Combine
import Foundation

@MainActor
final class PanelPresentationState: ObservableObject {
  @Published private(set) var openRevision = 0

  func markOpened() {
    openRevision += 1
  }
}

