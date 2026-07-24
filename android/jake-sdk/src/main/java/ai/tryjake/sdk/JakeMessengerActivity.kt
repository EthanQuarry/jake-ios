package ai.tryjake.sdk

import android.annotation.SuppressLint
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.ComponentActivity
import org.json.JSONArray
import org.json.JSONObject
import java.net.URLEncoder

class JakeMessengerActivity : ComponentActivity() {
  private lateinit var webView: WebView
  private var isReady = false
  private val pendingCommands = mutableListOf<Pair<String, Map<String, Any?>>>()

  @SuppressLint("SetJavaScriptEnabled")
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    val config = Jake.configuration
    val session = Jake.session
    if (config == null || session == null) {
      finish()
      return
    }

    Jake.attach(this)
    webView = WebView(this).apply {
      settings.javaScriptEnabled = true
      settings.domStorageEnabled = true
      settings.allowFileAccess = false
      settings.allowContentAccess = false
      webChromeClient = WebChromeClient()
      webViewClient = MessengerWebViewClient(config.messengerUrl)
      addJavascriptInterface(NativeBridge(), "JakeAndroid")
    }
    setContentView(webView)

    val separator = if (config.messengerUrl.contains("?")) "&" else "?"
    val url = config.messengerUrl +
      separator +
      "workspace_id=${encode(config.workspaceId)}&platform=android&sdk_version=${Jake.SDK_VERSION}"
    webView.loadUrl(
      url,
      mapOf(
        "Authorization" to "Bearer ${session.token}",
        "X-Jake-User-ID" to session.userId,
        "X-Jake-Public-Key" to config.publicKey,
        "X-Jake-Workspace-ID" to config.workspaceId,
        "X-Jake-SDK-Version" to Jake.SDK_VERSION,
      ),
    )
  }

  override fun onDestroy() {
    Jake.detach(this)
    if (::webView.isInitialized) {
      webView.removeJavascriptInterface("JakeAndroid")
      webView.destroy()
    }
    super.onDestroy()
  }

  @Deprecated("Deprecated in Java")
  override fun onBackPressed() {
    if (::webView.isInitialized && webView.canGoBack()) webView.goBack() else super.onBackPressed()
  }

  internal fun sendCommand(type: String, payload: Map<String, Any?>) {
    runOnUiThread {
      if (!isReady) {
        pendingCommands += type to payload
      } else {
        evaluate(type, payload)
      }
    }
  }

  private fun evaluate(type: String, payload: Map<String, Any?>) {
    val message = JSONObject()
      .put("type", type)
      .put("payload", toJson(payload))
      .toString()
    webView.evaluateJavascript(
      "window.JakeNative && window.JakeNative.receive($message);",
      null,
    )
  }

  private fun handleMessage(raw: String) {
    runCatching {
      val objectValue = if (raw.trimStart().startsWith("{")) JSONObject(raw) else null
      val type = objectValue?.optString("type") ?: raw
      val payload = objectValue?.opt("payload")
      when (type) {
        "messengerReady" -> {
          isReady = true
          evaluate(
            "deviceContext",
            mapOf(
              "app" to mapOf(
                "bundleId" to packageName,
                "version" to packageManager.getPackageInfo(packageName, 0).versionName,
              ),
              "device" to mapOf(
                "model" to android.os.Build.MODEL,
                "systemName" to "Android",
                "systemVersion" to android.os.Build.VERSION.RELEASE,
              ),
              "locale" to resources.configuration.locales[0].toLanguageTag(),
              "timeZone" to java.util.TimeZone.getDefault().id,
            ),
          )
          pendingCommands.forEach { evaluate(it.first, it.second) }
          pendingCommands.clear()
        }
        "closeMessenger" -> finish()
        "unreadCountChanged" -> {
          val count = when (payload) {
            is Number -> payload.toInt()
            is JSONObject -> payload.optInt("count", 0)
            else -> 0
          }
          Jake.updateUnreadCount(count)
        }
        "authenticationExpired" -> Jake.expireAuthentication()
        "openExternalURL" -> {
          val url = when (payload) {
            is String -> payload
            is JSONObject -> payload.optString("url")
            else -> ""
          }
          openExternal(url)
        }
      }
    }.onFailure {
      Jake.report("invalid_message", "Messenger sent an invalid native message.")
    }
  }

  private fun openExternal(value: String) {
    val uri = runCatching { Uri.parse(value) }.getOrNull() ?: return
    if (uri.scheme?.lowercase() in setOf("http", "https", "mailto", "tel")) {
      startActivity(Intent(Intent.ACTION_VIEW, uri))
    }
  }

  private inner class NativeBridge {
    @JavascriptInterface
    fun postMessage(message: String) {
      runOnUiThread { handleMessage(message) }
    }
  }

  private inner class MessengerWebViewClient(
    private val messengerUrl: String,
  ) : WebViewClient() {
    override fun onPageStarted(view: WebView, url: String, favicon: android.graphics.Bitmap?) {
      view.evaluateJavascript(
        """
        window.webkit = window.webkit || {};
        window.webkit.messageHandlers = window.webkit.messageHandlers || {};
        window.webkit.messageHandlers.jake = {
          postMessage: function(value) {
            JakeAndroid.postMessage(
              typeof value === 'string' ? value : JSON.stringify(value)
            );
          }
        };
        """.trimIndent(),
        null,
      )
    }

    override fun shouldOverrideUrlLoading(
      view: WebView,
      request: WebResourceRequest,
    ): Boolean {
      val expectedHost = Uri.parse(messengerUrl).host
      if (request.isForMainFrame && request.url.host != expectedHost) {
        openExternal(request.url.toString())
        return true
      }
      return false
    }

    override fun onReceivedError(
      view: WebView,
      request: WebResourceRequest,
      error: android.webkit.WebResourceError,
    ) {
      if (request.isForMainFrame) {
        Jake.report("messenger_load_failed", error.description.toString())
      }
    }
  }

  private fun encode(value: String) = URLEncoder.encode(value, Charsets.UTF_8.name())

  private fun toJson(value: Any?): Any = when (value) {
    null -> JSONObject.NULL
    is Map<*, *> -> JSONObject().also { objectValue ->
      value.forEach { (key, child) -> objectValue.put(key.toString(), toJson(child)) }
    }
    is Iterable<*> -> JSONArray().also { array -> value.forEach { array.put(toJson(it)) } }
    is Array<*> -> JSONArray().also { array -> value.forEach { array.put(toJson(it)) } }
    else -> value
  }
}
