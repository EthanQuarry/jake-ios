# Jake SDK for Android

The Android SDK presents the same hosted Messenger used by the Swift SDK.

```kotlin
Jake.configure(
  context = applicationContext,
  workspaceId = "workspace_123",
  publicKey = "jake_pk_123",
)
Jake.authenticate(userId, shortLivedToken)
Jake.present(this)
```

Observe unread count, authentication expiry, and errors with `Jake.addListener`. Pass FCM
registration tokens to `Jake.setPushToken`.

The library uses encrypted shared preferences for the short-lived customer session and never puts
the token into an Activity intent. Application secrets must remain on your backend.

For local monorepo use, include `:jake-sdk` from this Gradle build. The library is configured for
publication as `ai.tryjake:jake-sdk:0.1.0`.

## Maven Central release

Install Gradle 8.x, JReleaser, the Android SDK, and GPG. Generate a signing key and publish its
public key to a public keyserver. Keep the private key and Portal token outside the repository.

JReleaser reads these environment variables:

- `JRELEASER_MAVENCENTRAL_APP_USERNAME`
- `JRELEASER_MAVENCENTRAL_APP_PASSWORD`
- `JRELEASER_GPG_KEYNAME`
- `JRELEASER_GPG_PASSPHRASE`

Stage, validate, and deploy from `android/`:

```bash
./gradlew clean :jake-sdk:publishReleasePublicationToStagingRepository
jreleaser config --git-root-search
jreleaser deploy --git-root-search
```

The deployment is uploaded to the Central Portal for validation and publication.
