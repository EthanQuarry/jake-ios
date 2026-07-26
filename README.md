# SupportKit for iOS

A vendor-neutral iOS support channel that can use Jake, Intercom Fin, or a company-owned agent
without putting agent logic or secrets in the app.

## Architecture

The visible channel and the answering agent are deliberately different choices:

| Product | Responsibility |
| --- | --- |
| `SupportKitCore` | Identity, channel contract, capability model, and pinned-channel coordinator |
| `SupportKitUI` | Native SwiftUI conversation interface |
| `CustomAgentAdapter` | Router-backed native channel for Jake, Fin, or internal agents |
| `JakeSupportAdapter` | Optional opaque Jake hosted Messenger channel |
| `IntercomAdapter` | Optional opaque Intercom Messenger channel |

`JakeSDK`, `SupportAdapterKit`, and `IntercomSupportAdapter` remain available as compatibility
products during migration.

The universal path is `SupportKitUI` → `RouterChannelAdapter` → canonical router → selected agent.
That path supports agent hot-swapping through a normalized server-side handoff. Vendor Messenger
SDKs remain useful channels, but their iOS APIs do not make them arbitrary-agent transports; their
adapters therefore advertise `externalAgentRouting == false`.

## Install

Add this Swift package in Xcode. For the portable native experience, link:

- `SupportKitCore`
- `SupportKitUI`
- `CustomAgentAdapter`

Link `JakeSupportAdapter` or `IntercomAdapter` only when you intentionally want that vendor's
hosted Messenger UI.

### Flutter and React Native

The hosted Jake Messenger SDK is also exposed through:

- [`packages/jake_flutter`](packages/jake_flutter) for Flutter on iOS and Android
- [`packages/react-native-jake`](packages/react-native-jake) for React Native on iOS and Android
- [`android/jake-sdk`](android/jake-sdk) for native Kotlin/Android applications

All three integrations expose the same lifecycle: configure, authenticate with a short-lived
customer token, present/dismiss, logout, analytics, user attributes, push tokens, unread count,
authentication-expiry events, and errors. The Flutter and React Native packages bridge to this
Swift SDK on iOS and the native Kotlin SDK on Android.

The cross-platform packages currently wrap the hosted Messenger experience. The portable
`SupportKitUI`/router channel remains a native Swift implementation; cross-platform native
conversation widgets would be a separate UI layer over the documented router contract.

### Install the hosted Messenger SDK

Swift Package Manager:

1. In Xcode, choose **File → Add Package Dependencies**.
2. Enter `https://github.com/EthanQuarry/jake-ios.git`.
3. Select version `0.1.0` or later and add the `JakeSDK` product.

CocoaPods:

```ruby
pod 'JakeSDK', '~> 0.1'
```

Android:

```kotlin
repositories {
    mavenCentral()
}

dependencies {
    implementation("ai.tryjake:jake-sdk:0.1.0")
}
```

React Native:

```bash
npm install @tryjakeai/react-native
cd ios && pod install
```

The React Native package is implemented in JavaScript with bundled TypeScript declarations, so
TypeScript applications receive type checking and editor completion without additional `@types`
packages.

The Flutter plugin is not on pub.dev yet. Install the tagged package directly from Git:

```yaml
dependencies:
  jake_flutter:
    git:
      url: https://github.com/EthanQuarry/jake-ios.git
      ref: 0.1.0
      path: packages/jake_flutter
```

Published packages:

- [React Native on npm](https://www.npmjs.com/package/@tryjakeai/react-native)
- [JakeSDK on CocoaPods](https://cocoapods.org/pods/JakeSDK)
- [SupportAdapterKit on CocoaPods](https://cocoapods.org/pods/SupportAdapterKit)
- [Jake SDK for Android on Maven Central](https://central.sonatype.com/artifact/ai.tryjake/jake-sdk/0.1.0)

## Native channel with any agent

```swift
import CustomAgentAdapter
import SupportKitCore
import SupportKitUI

let channel = RouterChannelAdapter(
  configuration: SupportRouterConfiguration(
    baseURL: URL(string: "https://support-api.example.com")!,
    agentProviderID: "jake", // or "intercom-fin" / "internal"
    sessionToken: { try await applicationBackend.shortLivedSupportToken() }
  )
)

let coordinator = SupportChannelCoordinator()
try coordinator.register(channel)
try coordinator.select(.native)
try await coordinator.startSession(
  SupportChannelSession(
    customer: SupportCustomer(
      id: currentUser.databaseID,
      externalID: currentUser.id,
      name: currentUser.name,
      email: currentUser.email
    )
  )
)

let model = SupportConversationModel(channel: channel)
let view = SupportConversationView(model: model)
```

The native header shows the channel name with a quiet, persistent `AI agent` disclosure before the
first message. Router channels use that disclosure by default. Pass `aiDisclosure: nil` to
`SupportRouterConfiguration` only for a channel that never connects the customer to an AI system.

For remote routing, call `SupportSelectionClient.select` first and pass its `agentProvider` into
`SupportRouterConfiguration`. The selection endpoint derives rollout attributes server-side and
returns both the visible channel and agent. Cache it only for `ttlSeconds`, and never apply a new
selection to an active conversation.

The session token proves the customer identity. The router ignores client-supplied identity when
authorizing existing conversations.

## Explicit agent handoff

```swift
try await channel.requestAgentHandoff(
  to: "intercom-fin",
  conversationID: conversationID,
  currentIntent: "refund invoice INV-42",
  reason: "Fin rollout cohort"
)
```

The server prepares the target first and commits the assignment atomically. If import fails, the
source agent remains pinned. Configuration changes never silently move an active conversation.

## Opaque Messenger channels

```swift
import JakeSupportAdapter

try coordinator.register(
  JakeChannelAdapter(
    configuration: JakeConfiguration(
      workspaceId: "workspace_123",
      publicKey: "jake_pk_123"
    )
  )
)
```

Intercom works the same way with `IntercomChannelAdapter`. Supply only short-lived user tokens or
JWTs from your backend. Never ship a Jake secret, Intercom API secret, Fin access token, MCP token,
or provider signing key in the application.

## Hosted widget in Xcode

Use `JakeSDK` when the iOS experience must be the production web widget rather than a SwiftUI
recreation:

```swift
import JakeSDK

Jake.configure(
  workspaceId: session.workspaceId,
  publicKey: session.publicKey
)
try await Jake.authenticate(userId: currentUser.id, token: session.token)
Jake.present()
```

To run the included simulator app, open
`Examples/JakeDemo/JakeDemo.xcodeproj`, select the `JakeDemo` scheme and an iOS Simulator, then
press Run. Opening the repository's `Package.swift` directly exposes library and command-line
schemes, but does not create an installable iOS app.

The default Messenger URL is `https://widget.tryjake.ai/messenger`. `Jake.present()` mounts that
hosted widget directly in a native sheet, so its branding, conversation UI, composer, and behavior
stay aligned with the web widget.

For local simulator development, the example server includes a session-token bridge. It keeps the
application secret on the Mac and returns only a short-lived customer session to the app:

```bash
cd Examples/SelectionServer
cp .env.example .env.local
# Add the application's public key and secret to .env.local.
./run-local.sh
```

The launcher also accepts `.env` when that is your existing local convention. Both local
environment filenames are ignored by git.

The bridge listens on `http://127.0.0.1:8787/mobile/support-token`. A production application must
implement the same server-side responsibility in its own authenticated backend; it must never put
the Jake application secret in the iOS bundle.

## Configuration repository

`Templates/customer-config` is the optional per-customer repository. Schema v2 selects
`defaultChannel` independently from `defaultAgentProvider`, includes reviewed routing/evaluation
files, and references secret names rather than values. Git is the review/history layer; production
uses a validated immutable imported version, not a live checkout.

See [architecture](docs/architecture.md), [backend contract](docs/backend-contract.md),
[migration](docs/migration.md), and [security](SECURITY.md).

## Verification

```bash
swift test
node --test Examples/SelectionServer/selection.test.mjs
node scripts/validate-cross-platform.mjs
(cd packages/react-native-jake && npm test)
```

Requires iOS 15+, Swift 6, and Xcode 16+. MIT licensed; Jake's proprietary runtime is not included.
