package ai.tryjake.flutter

import android.app.Activity
import android.os.Handler
import android.os.Looper
import ai.tryjake.sdk.Jake
import ai.tryjake.sdk.JakeEvent
import ai.tryjake.sdk.JakeEventListener
import ai.tryjake.sdk.JakeException
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class JakeFlutterPlugin :
  FlutterPlugin,
  MethodChannel.MethodCallHandler,
  EventChannel.StreamHandler,
  ActivityAware,
  JakeEventListener {
  private lateinit var methods: MethodChannel
  private lateinit var events: EventChannel
  private lateinit var applicationContext: android.content.Context
  private var activity: Activity? = null
  private var eventSink: EventChannel.EventSink? = null
  private val mainHandler = Handler(Looper.getMainLooper())

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = binding.applicationContext
    methods = MethodChannel(binding.binaryMessenger, "ai.tryjake.sdk/methods")
    events = EventChannel(binding.binaryMessenger, "ai.tryjake.sdk/events")
    methods.setMethodCallHandler(this)
    events.setStreamHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methods.setMethodCallHandler(null)
    events.setStreamHandler(null)
    Jake.removeListener(this)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    try {
      when (call.method) {
        "configure" -> {
          val workspaceId = call.argument<String>("workspaceId").orEmpty()
          val publicKey = call.argument<String>("publicKey").orEmpty()
          Jake.configure(
            applicationContext,
            workspaceId,
            publicKey,
            call.argument<String>("messengerUrl") ?: Jake.DEFAULT_MESSENGER_URL,
          )
          result.success(null)
        }
        "authenticate" -> {
          Jake.authenticate(
            call.argument<String>("userId").orEmpty(),
            call.argument<String>("token").orEmpty(),
          )
          result.success(null)
        }
        "present" -> {
          Jake.present(
            activity ?: throw JakeException(
              "presentation_unavailable",
              "No foreground Activity is available.",
            ),
          )
          result.success(null)
        }
        "dismiss" -> {
          Jake.dismiss()
          result.success(null)
        }
        "logout" -> {
          Jake.logout()
          result.success(null)
        }
        "track" -> {
          Jake.track(
            call.argument<String>("event").orEmpty(),
            call.argument<Map<String, Any?>>("properties").orEmpty(),
          )
          result.success(null)
        }
        "setUserAttributes" -> {
          @Suppress("UNCHECKED_CAST")
          Jake.setUserAttributes(call.arguments as? Map<String, Any?> ?: emptyMap())
          result.success(null)
        }
        "setPushToken" -> {
          Jake.setPushToken(call.arguments as? String ?: "")
          result.success(null)
        }
        "getUnreadCount" -> result.success(Jake.unreadCount)
        else -> result.notImplemented()
      }
    } catch (error: JakeException) {
      result.error(error.code, error.message, null)
    } catch (error: Throwable) {
      result.error("jake_error", error.message, null)
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
    eventSink = events
    Jake.addListener(this)
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
    Jake.removeListener(this)
  }

  override fun onEvent(event: JakeEvent) {
    mainHandler.post {
      when (event) {
        is JakeEvent.UnreadCountChanged -> eventSink?.success(
          mapOf("type" to "unreadCountChanged", "count" to event.count),
        )
        is JakeEvent.AuthenticationExpired -> eventSink?.success(
          mapOf("type" to "authenticationExpired"),
        )
        is JakeEvent.Error -> eventSink?.success(
          mapOf("type" to "error", "code" to event.code, "message" to event.message),
        )
      }
    }
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }
}
