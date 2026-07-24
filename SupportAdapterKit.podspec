Pod::Spec.new do |spec|
  spec.name = "SupportAdapterKit"
  spec.version = "0.1.0"
  spec.summary = "Vendor-neutral support provider contracts used by JakeSDK."
  spec.homepage = "https://tryjake.ai"
  spec.license = { type: "MIT", file: "LICENSE" }
  spec.author = { "Jake" => "support@tryjake.ai" }
  spec.source = { git: "https://github.com/EthanQuarry/jake-ios.git", tag: spec.version.to_s }
  spec.ios.deployment_target = "15.0"
  spec.osx.deployment_target = "13.0"
  spec.swift_version = "6.0"
  spec.source_files = "Sources/SupportAdapterKit/**/*.swift"
end
