// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "JakeSDK",
  platforms: [
    .iOS(.v15)
  ],
  products: [
    .library(name: "JakeSDK", targets: ["JakeSDK"])
  ],
  targets: [
    .target(name: "JakeSDK"),
    .testTarget(name: "JakeSDKTests", dependencies: ["JakeSDK"]),
  ]
)
