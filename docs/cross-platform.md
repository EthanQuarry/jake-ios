# Cross-platform SDKs

## Shared contract

Swift, Kotlin, Flutter, and React Native expose:

- `configure(workspaceId, publicKey, messengerUrl?)`
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
| Swift/iOS | `JakeSDK` Swift package or CocoaPod | `Sources/JakeSDK` |
| Kotlin/Android | `ai.tryjake:jake-sdk:0.1.0` | `android/jake-sdk` |
| Flutter | `jake_flutter` | `JakeSDK` on iOS, Kotlin SDK on Android |
| React Native | `@tryjakeai/react-native` | `JakeSDK` on iOS, Kotlin SDK on Android |

The Android library is configured for Maven publication. During monorepo development, include
`:jake-sdk` in the Gradle build and both bridge packages will select the local project. Published
bridge packages resolve the `ai.tryjake:jake-sdk` artifact.

The iOS bridge packages use CocoaPods and depend on the root `JakeSDK.podspec`. The Swift package
remains available to native applications.

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
