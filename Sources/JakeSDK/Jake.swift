import Foundation

#if canImport(UIKit)
  import UIKit
#endif

@MainActor
public enum Jake {
  private static let client = JakeClient()

  public static weak var delegate: (any JakeDelegate)? {
    get { client.delegate }
    set { client.delegate = newValue }
  }

  public static var unreadCount: Int { client.unreadCount }

  public static func configure(
    workspaceId: String,
    publicKey: String,
    messengerURL: URL = JakeConfiguration.hostedMessengerURL
  ) {
    client.configure(
      JakeConfiguration(
        workspaceId: workspaceId,
        publicKey: publicKey,
        messengerURL: messengerURL
      )
    )
  }

  public static func authenticate(userId: String, token: String) async throws {
    try client.authenticate(userId: userId, token: token)
  }

  public static func login(userId: String, token: String) async throws {
    try await authenticate(userId: userId, token: token)
  }

  public static func logout() {
    client.logout()
  }

  public static func track(_ event: String, properties: [String: JakeValue] = [:]) {
    client.track(event, properties: properties)
  }

  public static func setUserAttributes(_ attributes: [String: JakeValue]) {
    client.setUserAttributes(attributes)
  }

  public static func setPushToken(_ token: Data) {
    client.setPushToken(token.map { String(format: "%02x", $0) }.joined())
  }

  #if canImport(UIKit)
    public static func present() {
      client.present()
    }

    public static func present(from viewController: UIViewController) {
      client.present(from: viewController)
    }

    public static func dismiss() {
      client.dismiss()
    }
  #endif
}
