package ai.tryjake.reactnative

import ai.tryjake.sdk.Jake
import ai.tryjake.sdk.JakeEvent
import ai.tryjake.sdk.JakeEventListener
import ai.tryjake.sdk.JakeException
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.modules.core.DeviceEventManagerModule

class JakeReactNativeModule(
  private val context: ReactApplicationContext,
) : ReactContextBaseJavaModule(context), JakeEventListener {
  private var listenerCount = 0

  override fun getName() = "JakeSdk"

  @ReactMethod
  fun configure(options: ReadableMap, promise: Promise) = resolve(promise) {
    Jake.configure(
      context,
      options.getString("workspaceId").orEmpty(),
      options.getString("publicKey").orEmpty(),
      if (options.hasKey("messengerUrl")) {
        options.getString("messengerUrl").orEmpty()
      } else {
        Jake.DEFAULT_MESSENGER_URL
      },
    )
  }

  @ReactMethod
  fun authenticate(userId: String, token: String, promise: Promise) = resolve(promise) {
    Jake.authenticate(userId, token)
  }

  @ReactMethod
  fun present(promise: Promise) = resolve(promise) {
    val activity = currentActivity
      ?: throw JakeException("presentation_unavailable", "No foreground Activity is available.")
    Jake.present(activity)
  }

  @ReactMethod
  fun dismiss(promise: Promise) = resolve(promise) { Jake.dismiss() }

  @ReactMethod
  fun logout(promise: Promise) = resolve(promise) { Jake.logout() }

  @ReactMethod
  fun track(event: String, properties: ReadableMap, promise: Promise) = resolve(promise) {
    Jake.track(event, properties.toHashMap())
  }

  @ReactMethod
  fun setUserAttributes(attributes: ReadableMap, promise: Promise) = resolve(promise) {
    Jake.setUserAttributes(attributes.toHashMap())
  }

  @ReactMethod
  fun setPushToken(token: String, promise: Promise) = resolve(promise) {
    Jake.setPushToken(token)
  }

  @ReactMethod
  fun getUnreadCount(promise: Promise) {
    promise.resolve(Jake.unreadCount)
  }

  @ReactMethod
  fun addListener(eventName: String) {
    if (listenerCount++ == 0) Jake.addListener(this)
  }

  @ReactMethod
  fun removeListeners(count: Int) {
    listenerCount = (listenerCount - count).coerceAtLeast(0)
    if (listenerCount == 0) Jake.removeListener(this)
  }

  override fun invalidate() {
    Jake.removeListener(this)
    super.invalidate()
  }

  override fun onEvent(event: JakeEvent) {
    when (event) {
      is JakeEvent.UnreadCountChanged -> emit(
        "jakeUnreadCountChanged",
        Arguments.createMap().apply { putInt("count", event.count) },
      )
      is JakeEvent.AuthenticationExpired -> emit(
        "jakeAuthenticationExpired",
        Arguments.createMap(),
      )
      is JakeEvent.Error -> emit(
        "jakeError",
        Arguments.createMap().apply {
          putString("code", event.code)
          putString("message", event.message)
        },
      )
    }
  }

  private fun emit(name: String, payload: Any) {
    context.runOnUiQueueThread {
      if (context.hasActiveReactInstance()) {
        context
          .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
          .emit(name, payload)
      }
    }
  }

  private inline fun resolve(promise: Promise, block: () -> Unit) {
    try {
      block()
      promise.resolve(null)
    } catch (error: JakeException) {
      promise.reject(error.code, error.message, error)
    } catch (error: Throwable) {
      promise.reject("jake_error", error.message, error)
    }
  }
}
