import Foundation
import LitePasteCore

func checkPermissionGuideState() {
  var state = PermissionGuideState()

  expect(
    state.missingItems(accessibilityTrusted: true).isEmpty,
    "Permission guide should not report missing items when accessibility is trusted"
  )
  expect(
    state.missingItems(accessibilityTrusted: false) == [.accessibility],
    "Permission guide should report accessibility when it is not trusted"
  )
  expect(
    !state.shouldPresent(accessibilityTrusted: true),
    "Permission guide should not present when all required permissions are trusted"
  )
  expect(
    state.shouldPresent(accessibilityTrusted: false),
    "Permission guide should present when required permissions are missing"
  )

  state.dismissForSession()
  expect(
    !state.shouldPresent(accessibilityTrusted: false),
    "Permission guide should not present again after being dismissed for the current session"
  )

  let freshState = PermissionGuideState()
  expect(
    freshState.shouldPresent(accessibilityTrusted: false),
    "Permission guide dismissal should not persist across fresh sessions"
  )
}
