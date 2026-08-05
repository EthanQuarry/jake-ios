# Cross-platform SDKs

## Shared contract

Swift, Kotlin, Flutter, and React Native expose:

- `configure(workspaceId, publicKey, conversationApiUrl?)`
- `authenticate(userId, shortLivedToken)`
- `present`, `dismiss`, and `logout`
- `track`, `setUserAttributes`, and `setPushToken`
- `getUnreadCount`
- unread-count, authentication-expiry, and error events

The app obtains the customer token from its authenticated backend. Application secrets and
long-lived credentials never belong in a mobile bundle.

## Packaging

| Consumer | Package | Native implementation |
| --- | --- | --- |
| Swift/iOS | `JakeSDK` Swift package or CocoaPod `0.1.0` | `Sources/JakeSDK` |
| Kotlin/Android | Maven Central `ai.tryjake:jake-sdk:0.1.0` | `android/jake-sdk` |
| Flutter | Git package `packages/jake_flutter` (not yet on pub.dev) | `JakeSDK` on iOS, Kotlin SDK on Android |
| React Native | npm `@tryjakeai/react-native@0.2.2` | `JakeSDK` on iOS, Kotlin SDK on Android |

The Android library is published on Maven Central. During monorepo development, include
`:jake-sdk` in the Gradle build and both bridge packages will select the local project. Published
bridge packages resolve the `ai.tryjake:jake-sdk` artifact from Maven Central.

The iOS bridge packages use CocoaPods and resolve the published `JakeSDK` pod. The Swift package
remains available to native applications through the Git repository.

## Installation

### Swift Package Manager

Add `https://github.com/EthanQuarry/jake-ios.git` in Xcode, select version `0.1.0` or later, and
link the `JakeSDK` product.

### CocoaPods

```ruby
pod 'JakeSDK', '~> 0.1'
```

### Android

```kotlin
repositories {
    mavenCentral()
}

dependencies {
    implementation("ai.tryjake:jake-sdk:0.1.0")
}
```

### React Native

```bash
npm install @tryjakeai/react-native
cd ios && pod install
```

The React Native public API is JavaScript with bundled TypeScript declarations in `src/index.d.ts`.
It supports TypeScript consumers but is not currently authored or compiled from TypeScript.

### Flutter

Until the plugin is published on pub.dev, use its tagged Git package:

```yaml
dependencies:
  jake_flutter:
    git:
      url: https://github.com/EthanQuarry/jake-ios.git
      ref: 0.1.0
      path: packages/jake_flutter
```

## Push tokens

On iOS, pass the hexadecimal APNs device token. On Android, pass the FCM registration token. The
native SDK labels the provider before sending the command to Messenger.

## Scope

These packages present the hosted Jake Messenger and keep its UI aligned across platforms. They do
not reproduce the SwiftUI `SupportKitUI` portable conversation screen. Flutter or React Native
applications that need the neutral router channel can implement a framework-native conversation
screen against `docs/backend-contract.md`.

## Verification

Run:

```bash
swift test
node scripts/validate-cross-platform.mjs
(cd packages/react-native-jake && npm test)
(cd packages/jake_flutter && flutter test)
(cd android && gradle :jake-sdk:test)
```

Flutter and Android compilation require their respective SDK toolchains.
