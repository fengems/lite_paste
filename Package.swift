// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "LitePaste",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .executable(name: "LitePaste", targets: ["LitePaste"]),
    .executable(name: "LitePasteCoreChecks", targets: ["LitePasteCoreChecks"]),
    .executable(name: "LitePasteRuntimeRestoreChecks", targets: ["LitePasteRuntimeRestoreChecks"]),
    .library(name: "LitePasteCore", targets: ["LitePasteCore"])
  ],
  targets: [
    .executableTarget(
      name: "LitePaste",
      dependencies: ["LitePasteCore"]
    ),
    .executableTarget(
      name: "LitePasteCoreChecks",
      dependencies: ["LitePasteCore"]
    ),
    .executableTarget(
      name: "LitePasteRuntimeRestoreChecks",
      dependencies: ["LitePasteCore"]
    ),
    .target(
      name: "LitePasteCore",
      linkerSettings: [
        .linkedLibrary("sqlite3")
      ]
    )
  ]
)
