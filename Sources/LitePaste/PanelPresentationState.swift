import Combine
import CoreGraphics
import Foundation

struct PanelTopObstruction: Equatable {
  let minX: CGFloat
  let maxX: CGFloat

  func padded(by margin: CGFloat, in width: CGFloat) -> (leadingWidth: CGFloat, gapWidth: CGFloat, trailingWidth: CGFloat) {
    let paddedMinX = min(max(minX - margin, 0), width)
    let paddedMaxX = min(max(maxX + margin, paddedMinX), width)
    return (
      leadingWidth: paddedMinX,
      gapWidth: paddedMaxX - paddedMinX,
      trailingWidth: width - paddedMaxX
    )
  }
}

@MainActor
final class PanelPresentationState: ObservableObject {
  @Published private(set) var openRevision = 0
  @Published private(set) var actionMessage: String?
  @Published private(set) var topObstruction: PanelTopObstruction?

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

  func updateTopObstruction(_ obstruction: PanelTopObstruction?) {
    if topObstruction != obstruction {
      topObstruction = obstruction
    }
  }

  private func clearActionMessage() {
    actionMessageRevision += 1
    actionMessage = nil
  }
}
