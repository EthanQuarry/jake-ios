# Jake for React Native

```sh
npm install @tryjakeai/react-native
cd ios && pod install
```

```ts
import { Jake, JakeEvent } from '@tryjakeai/react-native';

await Jake.configure({ workspaceId: 'workspace_123', publicKey: 'jake_pk_123' });
await Jake.authenticate(userId, shortLivedToken);
await Jake.present();

const subscription = Jake.addEventListener(
  JakeEvent.unreadCountChanged,
  ({ count }) => console.log(count),
);
```

The token must come from your authenticated backend. Never put an application secret in the app.
On iOS, pass the hexadecimal APNs device token to `setPushToken`; on Android, pass the FCM token.

The package requires the `JakeSDK` CocoaPod and `ai.tryjake:jake-sdk` Android artifact. In this
monorepo, Android builds can include the local `:jake-sdk` Gradle project instead.
