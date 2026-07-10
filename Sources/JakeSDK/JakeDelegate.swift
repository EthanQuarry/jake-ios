import Foundation

@MainActor
public protocol JakeDelegate: AnyObject {
  func jakeDidUpdateUnreadCount(_ count: Int)
  func jakeAuthenticationDidExpire()
  func jakeDidFail(with error: JakeError)
}

extension JakeDelegate {
  public func jakeDidUpdateUnreadCount(_: Int) {}
  public func jakeAuthenticationDidExpire() {}
  public func jakeDidFail(with _: JakeError) {}
}

extension Notification.Name {
  public static let jakeUnreadCountDidChange = Notification.Name(
    "ai.tryjake.JakeSDK.unreadCountDidChange")
  public static let jakeAuthenticationDidExpire = Notification.Name(
    "ai.tryjake.JakeSDK.authenticationDidExpire")
}

public enum JakeNotificationUserInfoKey {
  public static let unreadCount = "unreadCount"
}
