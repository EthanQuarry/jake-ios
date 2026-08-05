import Foundation

public enum JakeError: LocalizedError, Equatable, Sendable {
  case notConfigured
  case invalidConfiguration(String)
  case invalidAuthentication(String)
  case authenticationRequired
  case authenticationExpired
  case tokenStorageFailed
  case presentationUnavailable
  case messengerLoadFailed(String)

  public var errorDescription: String? {
    switch self {
    case .notConfigured:
      return "Jake has not been configured. Call Jake.configure before using the SDK."
    case .invalidConfiguration(let message), .invalidAuthentication(let message):
      return message
    case .authenticationRequired:
      return "Authenticate a user before presenting Jake Messenger."
    case .authenticationExpired:
      return "The current Jake session has expired. Authenticate again."
    case .tokenStorageFailed:
      return "Jake could not securely store the user session."
    case .presentationUnavailable:
      return "Jake could not find a view controller from which to present Messenger."
    case .messengerLoadFailed(let message):
      return "Jake Messenger could not load: \(message)"
    }
  }
}
