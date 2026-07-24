# Jake for Flutter

The plugin is not published on pub.dev yet. Install version `0.1.0` from the tagged Git repository:

```yaml
dependencies:
  jake_flutter:
    git:
      url: https://github.com/EthanQuarry/jake-ios.git
      ref: 0.1.0
      path: packages/jake_flutter
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

The plugin resolves the published `JakeSDK` CocoaPod on iOS and
`ai.tryjake:jake-sdk:0.1.0` from Maven Central on Android. In this monorepo, Android builds can
include the local `:jake-sdk` Gradle project instead.
