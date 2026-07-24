package ai.tryjake.sdk

sealed interface JakeEvent {
  data class UnreadCountChanged(val count: Int) : JakeEvent
  data object AuthenticationExpired : JakeEvent
  data class Error(val code: String, val message: String) : JakeEvent
}

fun interface JakeEventListener {
  fun onEvent(event: JakeEvent)
}
