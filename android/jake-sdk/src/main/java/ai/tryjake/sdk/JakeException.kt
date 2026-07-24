package ai.tryjake.sdk

class JakeException(
  val code: String,
  message: String,
  cause: Throwable? = null,
) : Exception(message, cause)
