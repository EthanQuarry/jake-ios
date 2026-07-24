<div align="center">

# Jake for React Native

### The hosted customer-support Messenger for React Native

One API for authentication, presentation, unread counts, events, analytics, user attributes, and
push tokens—backed by native Swift on iOS and Kotlin on Android.

[![npm version](https://img.shields.io/npm/v/@tryjakeai/react-native.svg)](https://www.npmjs.com/package/@tryjakeai/react-native)
[![license](https://img.shields.io/npm/l/@tryjakeai/react-native.svg)](https://github.com/EthanQuarry/jake-ios/blob/main/packages/react-native-jake/LICENSE)
[![React Native](https://img.shields.io/badge/React%20Native-%3E%3D0.72-61dafb.svg)](https://reactnative.dev/)

[Website](https://tryjake.ai) ·
[npm](https://www.npmjs.com/package/@tryjakeai/react-native) ·
[GitHub](https://github.com/EthanQuarry/jake-ios) ·
[Issues](https://github.com/EthanQuarry/jake-ios/issues)

</div>

## What is Jake?

Jake gives React Native applications a secure, hosted support Messenger without maintaining
separate JavaScript, iOS, and Android implementations. The bridge keeps the public API and event
names consistent while each platform uses its native Jake SDK.

```tsx
import { Jake } from '@tryjakeai/react-native';

await Jake.configure({
  workspaceId: 'workspace_123',
  publicKey: 'jake_pk_123',
});

await Jake.authenticate(currentUser.id, shortLivedToken);
await Jake.present();
```

## Features

- One API across iOS and Android
- Native Swift and Kotlin bridges
- JavaScript and TypeScript support with bundled declarations
- Short-lived, backend-issued customer authentication
- Hosted Messenger presentation and dismissal
- Unread-count and authentication-expiry events
- Analytics events and user attributes
- APNs and FCM push-token registration
- No Jake application secret in the mobile bundle

## Requirements

| Dependency | Supported version |
| --- | --- |
| React | 18 or later |
| React Native | 0.72 or later |
| iOS | 15.0 or later |
| Android | API 23 or later |
| Android toolchain | Java 17 |

The package contains native code. Rebuild the application after installation. It does not run
inside the standard Expo Go client; use an Expo development build or a bare React Native app.

## Installation

Choose your package manager:

```bash
npm install @tryjakeai/react-native
```

```bash
yarn add @tryjakeai/react-native
```

```bash
pnpm add @tryjakeai/react-native
```

Install the native iOS dependency:

```bash
cd ios
pod install
cd ..
```

Android resolves `ai.tryjake:jake-sdk` from Maven Central. Most React Native projects already
include `mavenCentral()`; add it to the dependency repositories if yours does not.

```kotlin
repositories {
    google()
    mavenCentral()
}
```

React Native autolinking registers the package on both platforms. Manual linking is not required.

## Quick start

Configure Jake once during application startup:

```tsx
import { Jake } from '@tryjakeai/react-native';

await Jake.configure({
  workspaceId: 'workspace_123',
  publicKey: 'jake_pk_123',
  // messengerUrl: 'https://widget.tryjake.ai/messenger',
});
```

Authenticate after obtaining a short-lived customer token from your backend:

```tsx
const response = await fetch('/api/support/session', {
  headers: {
    Authorization: `Bearer ${applicationSession}`,
  },
});

const session = await response.json();

await Jake.authenticate(session.userId, session.token);
await Jake.present();
```

Present Jake from your interface:

```tsx
import { Pressable, Text } from 'react-native';
import { Jake } from '@tryjakeai/react-native';

export function SupportButton() {
  return (
    <Pressable onPress={() => Jake.present()}>
      <Text>Contact support</Text>
    </Pressable>
  );
}
```

## Authentication

The `publicKey` identifies your Jake application and is safe to include in the client. Your Jake
application secret is not.

Your backend should authenticate the current application user, create a short-lived Jake customer
token, and return only that token and the corresponding user ID to the app.

```text
React Native app → your authenticated backend → Jake
                 ← short-lived customer token ←
```

Never ship a Jake application secret, provider credential, or long-lived signing key in an iOS or
Android bundle.

## Events

Subscribe to events after configuration and remove subscriptions when the owning component
unmounts.

```tsx
import { useEffect } from 'react';
import { Jake, JakeEvent } from '@tryjakeai/react-native';

export function JakeEvents() {
  useEffect(() => {
    const unread = Jake.addEventListener(
      JakeEvent.unreadCountChanged,
      ({ count }) => {
        console.log('Unread conversations:', count);
      },
    );

    const expired = Jake.addEventListener(
      JakeEvent.authenticationExpired,
      async () => {
        // Fetch a fresh short-lived token from your backend.
      },
    );

    const errors = Jake.addEventListener(
      JakeEvent.error,
      ({ code, message }) => {
        console.warn('Jake error:', code, message);
      },
    );

    return () => {
      unread.remove();
      expired.remove();
      errors.remove();
    };
  }, []);

  return null;
}
```

| Event | Payload |
| --- | --- |
| `JakeEvent.unreadCountChanged` | `{ count: number }` |
| `JakeEvent.authenticationExpired` | `{}` |
| `JakeEvent.error` | `{ code: string, message: string }` |

You can also request the current count directly:

```tsx
const unreadCount = await Jake.getUnreadCount();
```

## Analytics and customer context

Property values may be strings, numbers, booleans, or `null`.

```tsx
await Jake.track('subscription_viewed', {
  plan: 'pro',
  trial: false,
});

await Jake.setUserAttributes({
  name: currentUser.name,
  email: currentUser.email,
  plan: currentUser.plan,
});
```

## Push notifications

Pass the platform-native registration token:

- iOS: the hexadecimal APNs device token
- Android: the FCM registration token

```tsx
await Jake.setPushToken(pushToken);
```

Call this again whenever the operating system rotates the token.

## API

### `Jake.configure(options)`

Configures the native SDK. Call it before every other method.

| Option | Type | Required | Description |
| --- | --- | --- | --- |
| `workspaceId` | `string` | Yes | Jake workspace identifier |
| `publicKey` | `string` | Yes | Jake application public key |
| `messengerUrl` | `string` | No | Custom Messenger URL; defaults to Jake's hosted Messenger |

### `Jake.authenticate(userId, token)`

Authenticates the current customer with a short-lived token issued by your backend.

### `Jake.present()`

Presents the hosted Messenger. Configuration and authentication must already be complete.

### `Jake.dismiss()`

Dismisses the Messenger if it is visible.

### `Jake.logout()`

Dismisses the Messenger, clears the stored customer session, and resets the unread count.

### `Jake.track(event, properties?)`

Sends a named customer event with optional primitive properties.

### `Jake.setUserAttributes(attributes)`

Updates primitive customer attributes available to the support experience.

### `Jake.setPushToken(token)`

Registers an APNs token on iOS or an FCM token on Android.

### `Jake.getUnreadCount()`

Returns the current unread count as a promise.

### `Jake.addEventListener(event, listener)`

Registers a native event listener and returns a subscription with a `remove()` method.

## TypeScript

The runtime is implemented in JavaScript and ships first-party declarations from `src/index.d.ts`.
TypeScript users receive type checking and editor completion without installing an `@types`
package.

```tsx
import type {
  JakeConfiguration,
  JakeProperties,
  JakeSubscription,
} from '@tryjakeai/react-native';
```

## Troubleshooting

### “The Jake native module isn't linked”

Rebuild the native application after installing the package. On iOS, run `pod install` before
rebuilding. Expo users must create a development build rather than opening the project in Expo Go.

### `authentication_required`

Call `Jake.configure()`, obtain a fresh customer token from your backend, call
`Jake.authenticate()`, and only then call `Jake.present()`.

### `invalid_configuration`

Check that `workspaceId` and `publicKey` are non-empty. Custom Messenger URLs must use HTTPS outside
local development.

### Messenger presentation fails

Call `Jake.present()` from an active screen after the React Native root view is visible. Also check
the `JakeEvent.error` listener for a native error code and message.

### Authentication expires

Listen for `JakeEvent.authenticationExpired`, request a new short-lived token from your backend,
and call `Jake.authenticate()` again.

## Native dependencies

- iOS: [`JakeSDK`](https://cocoapods.org/pods/JakeSDK) through CocoaPods
- Android: [`ai.tryjake:jake-sdk`](https://central.sonatype.com/artifact/ai.tryjake/jake-sdk/0.1.0)

## License

MIT © Jake
