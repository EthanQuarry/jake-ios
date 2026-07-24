package ai.tryjake.sdk

import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import java.lang.ref.WeakReference
import java.net.URI
import java.util.concurrent.CopyOnWriteArraySet

object Jake {
  const val SDK_VERSION = "0.1.0"
  const val DEFAULT_MESSENGER_URL = "https://widget.tryjake.ai/messenger"

  internal data class Configuration(
    val workspaceId: String,
    val publicKey: String,
    val messengerUrl: String,
  )

  internal data class Session(val userId: String, val token: String)

  private const val PREFS = "ai.tryjake.sdk.session"
  private var appContext: Context? = null
  internal var configuration: Configuration? = null
    private set
  internal var session: Session? = null
    private set
  private var activity = WeakReference<JakeMessengerActivity>(null)
  private val listeners = CopyOnWriteArraySet<JakeEventListener>()

  var unreadCount: Int = 0
    private set

  @JvmStatic
  fun configure(
    context: Context,
    workspaceId: String,
    publicKey: String,
    messengerUrl: String = DEFAULT_MESSENGER_URL,
  ) {
    val normalizedWorkspace = workspaceId.trim()
    val normalizedKey = publicKey.trim()
    if (normalizedWorkspace.isEmpty()) {
      throw JakeException("invalid_configuration", "Jake workspaceId cannot be empty.")
    }
    if (normalizedKey.isEmpty()) {
      throw JakeException("invalid_configuration", "Jake publicKey cannot be empty.")
    }
    val uri = runCatching { URI(messengerUrl) }.getOrNull()
    val scheme = uri?.scheme?.lowercase()
    if (scheme != "https" && scheme != "http") {
      throw JakeException(
        "invalid_configuration",
        "Jake messengerUrl must use HTTP or HTTPS.",
      )
    }
    val host = uri?.host?.lowercase()
    if (scheme == "http" && host != "127.0.0.1" && host != "localhost" && host != "10.0.2.2") {
      throw JakeException(
        "invalid_configuration",
        "Jake messengerUrl must use HTTPS outside local development.",
      )
    }

    appContext = context.applicationContext
    configuration = Configuration(normalizedWorkspace, normalizedKey, messengerUrl)
    session = readSession(normalizedWorkspace)
    updateUnreadCount(0)
  }

  @JvmStatic
  fun authenticate(userId: String, token: String) {
    val config = configuration
      ?: throw JakeException("not_configured", "Call Jake.configure before authenticating.")
    val normalizedUser = userId.trim()
    val normalizedToken = token.trim()
    if (normalizedUser.isEmpty() || normalizedToken.isEmpty()) {
      throw JakeException(
        "invalid_authentication",
        "Jake userId and user token cannot be empty.",
      )
    }
    val authenticated = Session(normalizedUser, normalizedToken)
    session = authenticated
    preferences().edit()
      .putString("${config.workspaceId}.userId", authenticated.userId)
      .putString("${config.workspaceId}.token", authenticated.token)
      .apply()
  }

  @JvmStatic
  fun present(activity: Activity) {
    if (configuration == null) {
      throw JakeException("not_configured", "Call Jake.configure before presenting Messenger.")
    }
    if (session == null) {
      throw JakeException(
        "authentication_required",
        "Authenticate a user before presenting Messenger.",
      )
    }
    activity.startActivity(Intent(activity, JakeMessengerActivity::class.java))
  }

  @JvmStatic
  fun dismiss() {
    activity.get()?.finish()
  }

  @JvmStatic
  fun logout() {
    activity.get()?.finish()
    configuration?.workspaceId?.let { workspace ->
      preferences().edit()
        .remove("$workspace.userId")
        .remove("$workspace.token")
        .apply()
    }
    session = null
    updateUnreadCount(0)
  }

  @JvmStatic
  fun track(event: String, properties: Map<String, Any?> = emptyMap()) {
    requireAuthenticated()
    if (event.isNotBlank()) {
      activity.get()?.sendCommand(
        "track",
        mapOf("name" to event.trim(), "properties" to properties),
      )
    }
  }

  @JvmStatic
  fun setUserAttributes(attributes: Map<String, Any?>) {
    requireAuthenticated()
    activity.get()?.sendCommand("setUserAttributes", mapOf("attributes" to attributes))
  }

  @JvmStatic
  fun setPushToken(token: String) {
    requireAuthenticated()
    if (token.isNotBlank()) {
      activity.get()?.sendCommand(
        "setPushToken",
        mapOf("token" to token, "provider" to "fcm"),
      )
    }
  }

  @JvmStatic
  fun addListener(listener: JakeEventListener) {
    listeners.add(listener)
  }

  @JvmStatic
  fun removeListener(listener: JakeEventListener) {
    listeners.remove(listener)
  }

  internal fun attach(activity: JakeMessengerActivity) {
    this.activity = WeakReference(activity)
  }

  internal fun detach(activity: JakeMessengerActivity) {
    if (this.activity.get() === activity) this.activity.clear()
  }

  internal fun updateUnreadCount(value: Int) {
    val normalized = value.coerceAtLeast(0)
    if (normalized == unreadCount) return
    unreadCount = normalized
    emit(JakeEvent.UnreadCountChanged(normalized))
  }

  internal fun expireAuthentication() {
    configuration?.workspaceId?.let { workspace ->
      preferences().edit()
        .remove("$workspace.userId")
        .remove("$workspace.token")
        .apply()
    }
    session = null
    activity.get()?.finish()
    emit(JakeEvent.AuthenticationExpired)
  }

  internal fun report(code: String, message: String) {
    emit(JakeEvent.Error(code, message))
  }

  private fun requireAuthenticated() {
    if (session == null) {
      throw JakeException(
        "authentication_required",
        "Authenticate a user before using Messenger.",
      )
    }
  }

  private fun emit(event: JakeEvent) {
    listeners.forEach { it.onEvent(event) }
  }

  private fun preferences() = EncryptedSharedPreferences.create(
    requireNotNull(appContext) { "Call Jake.configure first." },
    PREFS,
    MasterKey.Builder(requireNotNull(appContext))
      .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
      .build(),
    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
  )

  private fun readSession(workspaceId: String): Session? {
    val prefs = preferences()
    val userId = prefs.getString("$workspaceId.userId", null) ?: return null
    val token = prefs.getString("$workspaceId.token", null) ?: return null
    return Session(userId, token)
  }
}
