import Foundation

enum JakeWebMessage: Equatable {
  case ready
  case close
  case openExternalURL(URL)
  case unreadCountChanged(Int)
  case messageReceived
  case authenticationExpired

  init?(body: Any) {
    if let type = body as? String {
      self.init(type: type, payload: nil)
      return
    }
    guard let object = body as? [String: Any], let type = object["type"] as? String else {
      return nil
    }
    self.init(type: type, payload: object["payload"])
  }

  private init?(type: String, payload: Any?) {
    switch type {
    case "messengerReady":
      self = .ready
    case "closeMessenger":
      self = .close
    case "openExternalURL":
      let string = (payload as? String) ?? (payload as? [String: Any])?["url"] as? String
      guard let string, let url = URL(string: string) else { return nil }
      self = .openExternalURL(url)
    case "unreadCountChanged":
      let value = (payload as? Int) ?? (payload as? [String: Any])?["count"] as? Int
      guard let value else { return nil }
      self = .unreadCountChanged(max(0, value))
    case "messageReceived":
      self = .messageReceived
    case "authenticationExpired":
      self = .authenticationExpired
    default:
      return nil
    }
  }
}
