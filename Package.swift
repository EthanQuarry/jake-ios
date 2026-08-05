// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "JakeSDK",
  platforms: [
    .iOS(.v15),
    .macOS(.v13),
  ],
  products: [
    .library(name: "SupportKitCore", targets: ["SupportKitCore"]),
    .library(name: "SupportKitUI", targets: ["SupportKitUI"]),
    .library(name: "CustomAgentAdapter", targets: ["CustomAgentAdapter"]),
    .library(name: "JakeSupportAdapter", targets: ["JakeSupportAdapter"]),
    .library(name: "IntercomAdapter", targets: ["IntercomAdapter"]),
    .library(name: "SupportAdapterKit", targets: ["SupportAdapterKit"]),
    .library(name: "JakeSDK", targets: ["JakeSDK"]),
    .library(name: "IntercomSupportAdapter", targets: ["IntercomSupportAdapter"]),
    .library(name: "JakeSupport", targets: ["JakeSupport"]),
    .executable(name: "SupportSwitcherExample", targets: ["SupportSwitcherExample"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/intercom/intercom-ios-sp.git",
      .upToNextMajor(from: "19.6.5")
    )
  ],
  targets: [
    .target(name: "SupportKitCore"),
    .target(name: "SupportKitUI", dependencies: ["SupportKitCore"]),
    .target(name: "CustomAgentAdapter", dependencies: ["SupportKitCore"]),
    .target(name: "JakeSupportAdapter", dependencies: ["SupportKitCore", "JakeSDK"]),
    .target(
      name: "IntercomAdapter",
      dependencies: [
        "SupportKitCore",
        .product(name: "Intercom", package: "intercom-ios-sp"),
      ]
    ),
    .target(name: "SupportAdapterKit"),
    .target(name: "JakeSDK", dependencies: ["SupportAdapterKit", "SupportKitUI", "CustomAgentAdapter"]),
    .target(
      name: "IntercomSupportAdapter",
      dependencies: [
        "SupportAdapterKit",
        .product(name: "Intercom", package: "intercom-ios-sp"),
      ]
    ),
    .target(
      name: "JakeSupport",
      dependencies: ["SupportAdapterKit", "JakeSDK", "IntercomSupportAdapter"]
    ),
    .executableTarget(
      name: "SupportSwitcherExample",
      dependencies: ["SupportAdapterKit"],
      path: "Examples/SupportSwitcherCLI"
    ),
    .testTarget(name: "SupportAdapterKitTests", dependencies: ["SupportAdapterKit"]),
    .testTarget(name: "SupportKitCoreTests", dependencies: ["SupportKitCore"]),
    .testTarget(name: "SupportKitUITests", dependencies: ["SupportKitUI", "SupportKitCore"]),
    .testTarget(name: "JakeSDKTests", dependencies: ["JakeSDK", "SupportAdapterKit"]),
    .testTarget(name: "JakeSupportTests", dependencies: ["JakeSupport"]),
  ]
)
