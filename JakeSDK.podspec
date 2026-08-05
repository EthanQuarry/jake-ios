Pod::Spec.new do |spec|
  spec.name = "JakeSDK"
  spec.version = "0.3.0"
  spec.summary = "Jake hosted support Messenger for iOS."
  spec.homepage = "https://tryjake.ai"
  spec.license = { type: "MIT", file: "LICENSE" }
  spec.author = { "Jake" => "support@tryjake.ai" }
  spec.source = { git: "https://github.com/EthanQuarry/jake-ios.git", tag: spec.version.to_s }
  spec.ios.deployment_target = "15.0"
  spec.swift_version = "6.0"
  spec.frameworks = ["Security", "UIKit", "SwiftUI"]

  spec.source_files = [
    "Sources/JakeSDK/**/*.swift",
    "Sources/SupportKitCore/**/*.swift",
    "Sources/SupportKitUI/**/*.swift",
    "Sources/SupportAdapterKit/**/*.swift",
    "Sources/CustomAgentAdapter/**/*.swift",
    "Sources/JakeSupportAdapter/**/*.swift"
  ]
end
