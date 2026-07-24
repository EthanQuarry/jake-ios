Pod::Spec.new do |spec|
  spec.name = "jake_flutter"
  spec.version = "0.1.0"
  spec.summary = "Flutter bridge for Jake Messenger."
  spec.homepage = "https://tryjake.ai"
  spec.license = { type: "MIT" }
  spec.author = "Jake"
  spec.source = { path: "." }
  spec.source_files = "Classes/**/*"
  spec.platform = :ios, "15.0"
  spec.swift_version = "6.0"
  spec.dependency "Flutter"
  spec.dependency "JakeSDK", "~> 0.1"
end
