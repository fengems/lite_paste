import Foundation
import LitePasteCore

func checkAppPathsEnvironmentOverride() {
  let override = "/tmp/LitePaste Isolated Data"
  let overriddenURL = AppPaths.applicationSupportDirectory(
    environment: [AppPaths.applicationSupportDirectoryOverrideEnvironmentKey: override]
  )
  expect(
    overriddenURL.path == override,
    "AppPaths should honor isolated application support directory overrides"
  )

  let defaultURL = AppPaths.applicationSupportDirectory(environment: [:])
  expect(
    defaultURL.lastPathComponent == "LitePaste",
    "AppPaths should default to the LitePaste application support directory"
  )

  let devURL = AppPaths.applicationSupportDirectory(
    environment: [AppFlavor.environmentKey: "dev"]
  )
  expect(
    devURL.lastPathComponent == "LitePaste-Dev",
    "AppPaths should isolate the dev flavor application support directory"
  )

  expect(
    AppFlavor.current(environment: [AppFlavor.environmentKey: "dev"]) == .dev,
    "AppFlavor should read the dev flavor from environment"
  )
  expect(
    AppFlavor.current(environment: [:], bundleIdentifier: "com.fengems.LitePaste.dev") == .dev,
    "AppFlavor should infer dev flavor from bundle identifier"
  )
}
