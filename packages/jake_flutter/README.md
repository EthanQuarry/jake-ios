# Jake for Flutter

```yaml
dependencies:
  jake_flutter: ^0.1.0
```

```dart
await Jake.configure(
  workspaceId: 'workspace_123',
  publicKey: 'jake_pk_123',
);
await Jake.authenticate(userId: userId, token: shortLivedToken);
await Jake.present();

final subscription = Jake.events.listen((event) {
  if (event case JakeUnreadCountChanged(:final count)) {
    print(count);
  }
});
```

The token must come from your authenticated backend. Never put an application secret in the app.
On iOS, pass the hexadecimal APNs device token to `setPushToken`; on Android, pass the FCM token.

The plugin requires the `JakeSDK` CocoaPod and `ai.tryjake:jake-sdk` Android artifact. In this
monorepo, Android builds can include the local `:jake-sdk` Gradle project instead.
