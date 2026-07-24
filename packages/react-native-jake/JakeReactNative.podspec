require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |spec|
  spec.name = "JakeReactNative"
  spec.version = package["version"]
  spec.summary = package["description"]
  spec.homepage = "https://tryjake.ai"
  spec.license = "MIT"
  spec.author = "Jake"
  spec.platforms = { ios: "15.0" }
  spec.source = { git: "https://github.com/EthanQuarry/jake-ios.git", tag: spec.version.to_s }
  spec.source_files = "ios/**/*.{h,m,mm,swift}"
  spec.swift_version = "6.0"
  spec.dependency "React-Core"
  spec.dependency "JakeSDK", "~> 0.1"
end
