import AppKit

enum PanelRowBoundary {
  case leading
  case trailing
}

enum PanelNavigationKey {
  case left
  case right
  case up
  case down
  case home
  case end
}

enum PanelKeyboardCommand {
  case close
  case copySelected
  case copySelectedPlainText
  case deleteSelected
  case focusSearch
  case navigate(PanelNavigationKey)
  case pasteNumber(Int)
  case pasteSelected
  case pasteSelectedPlainText
  case rowBoundary(PanelRowBoundary)

  /// Converts raw AppKit key events into panel-level commands; the view owns command execution.
  static func from(_ event: NSEvent) -> PanelKeyboardCommand? {
    let event = PanelKeyboardEvent(event)

    if event.isCommandOnly, let number = commandNumber(from: event) {
      return .pasteNumber(number)
    }
    if event.isCommandOnly, let boundary = commandLineBoundary(from: event) {
      return .rowBoundary(boundary)
    }
    if event.isControlLineBoundaryOnly, let boundary = controlLineBoundary(from: event) {
      return .rowBoundary(boundary)
    }
    if event.isCommandOnly, event.characters == "f" {
      return .focusSearch
    }
    if event.isCommandOnly, event.characters == "c" {
      return .copySelected
    }
    if event.modifiers == [.command, .shift], event.characters == "c" {
      return .copySelectedPlainText
    }
    if event.isCommandOnly, event.keyCode == PanelKeyCode.delete.rawValue {
      return .deleteSelected
    }
    if event.modifiers == [.command, .shift], PanelKeyCode.confirmKeys.contains(event.keyCode) {
      return .pasteSelectedPlainText
    }
    guard event.modifiers.isEmpty else {
      return nil
    }

    switch PanelKeyCode(rawValue: event.keyCode) {
    case .escape:
      return .close
    case .returnKey, .keypadEnter:
      return .pasteSelected
    case .forwardDelete:
      return .deleteSelected
    default:
      break
    }

    return navigationKey(from: event).map(PanelKeyboardCommand.navigate)
  }

  private static func commandNumber(from event: PanelKeyboardEvent) -> Int? {
    guard let characters = event.characters,
          characters.count == 1,
          let number = Int(characters),
          (1...9).contains(number) else {
      return nil
    }

    return number
  }

  private static func controlLineBoundary(from event: PanelKeyboardEvent) -> PanelRowBoundary? {
    switch event.characters {
    case "a":
      return .leading
    case "e":
      return .trailing
    default:
      return nil
    }
  }

  private static func commandLineBoundary(from event: PanelKeyboardEvent) -> PanelRowBoundary? {
    switch navigationKey(from: event) {
    case .left, .home:
      return .leading
    case .right, .end:
      return .trailing
    case .up, .down, nil:
      return nil
    }
  }

  private static func navigationKey(from event: PanelKeyboardEvent) -> PanelNavigationKey? {
    if let key = navigationKey(from: event.charactersIgnoringModifiers) {
      return key
    }

    switch PanelKeyCode(rawValue: event.keyCode) {
    case .leftArrow:
      return .left
    case .rightArrow:
      return .right
    case .upArrow:
      return .up
    case .downArrow:
      return .down
    case .home:
      return .home
    case .end:
      return .end
    default:
      return nil
    }
  }

  private static func navigationKey(from characters: String?) -> PanelNavigationKey? {
    guard let characters,
          characters.unicodeScalars.count == 1,
          let scalar = characters.unicodeScalars.first else {
      return nil
    }

    switch scalar.value {
    case 0xF702:
      return .left
    case 0xF703:
      return .right
    case 0xF700:
      return .up
    case 0xF701:
      return .down
    case 0xF729:
      return .home
    case 0xF72B:
      return .end
    default:
      return nil
    }
  }
}

private enum PanelKeyCode: UInt16 {
  case returnKey = 36
  case keypadEnter = 76
  case delete = 51
  case escape = 53
  case home = 115
  case forwardDelete = 117
  case end = 119
  case leftArrow = 123
  case rightArrow = 124
  case downArrow = 125
  case upArrow = 126

  static let confirmKeys: Set<UInt16> = [
    returnKey.rawValue,
    keypadEnter.rawValue
  ]
}

private struct PanelKeyboardEvent {
  let modifiers: NSEvent.ModifierFlags
  let keyCode: UInt16
  let characters: String?
  let charactersIgnoringModifiers: String?

  init(_ event: NSEvent) {
    modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
    keyCode = event.keyCode
    characters = event.charactersIgnoringModifiers?.lowercased()
    charactersIgnoringModifiers = event.charactersIgnoringModifiers
  }

  var isCommandOnly: Bool {
    modifiers == .command
  }

  var isControlLineBoundaryOnly: Bool {
    modifiers == .control || modifiers == [.control, .shift]
  }
}
