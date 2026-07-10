# Jake iOS SDK

`JakeSDK` presents Jake Messenger inside any UIKit or SwiftUI app. The first release is deliberately small: configure a workspace, authenticate a customer, and open the Messenger as a native sheet.

## Requirements

- iOS 15 or later
- Swift 6 / Xcode 16 or later
- A Jake workspace, public key, and short-lived user token issued by your backend

## Install

In Xcode, choose **File → Add Package Dependencies**, enter this repository URL, and add the `JakeSDK` product to your app target.

## Configure

Configure Jake once during app launch:

```swift
import JakeSDK

Jake.configure(
    workspaceId: "workspace_123",
    publicKey: "pk_live_123"
)
```

Authenticate after your own sign-in flow. The token must come from your server; never ship a Jake private secret in an app:

```swift
try await Jake.authenticate(
    userId: currentUser.id,
    token: tokenFromYourBackend
)
```

Present Messenger from SwiftUI:

```swift
Button("Contact support") {
    Jake.present()
}
```

Or from UIKit:

```swift
Jake.present(from: self)
```

Clear the Jake session when the customer signs out:

```swift
Jake.logout()
```

See Openline's `docs/ios-integration.md` for the full integration, authentication, event, and Messenger bridge contracts.

## Development

Run the platform-independent test suite with:

```bash
swift test
```

The UIKit and WebKit presentation code is compiled for iOS. A full iOS build requires Xcode rather than the standalone Command Line Tools.
