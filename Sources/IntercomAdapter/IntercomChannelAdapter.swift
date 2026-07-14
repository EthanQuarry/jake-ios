#if canImport(UIKit)
  import Foundation
  import Intercom
  import SupportKitCore
  import UIKit

  public struct IntercomChannelConfiguration: Equatable, Sendable {
    public let apiKey: String
    public let appID: String
    public init(apiKey: String, appID: String) {
      self.apiKey = apiKey
      self.appID = appID
    }
  }

  @MainActor
  public final class IntercomChannelAdapter: NSObject, SupportChannelAdapter {
    public let id: SupportChannelID
    public let displayName: String
    public let capabilities = SupportChannelCapabilities(
      presentation: .opaqueVendorMessenger,
      programmaticMessaging: false,
      unreadCount: true,
      pushNotifications: true,
      attachments: false,
      externalAgentRouting: false
    )
    public weak var delegate: (any SupportChannelAdapterDelegate)?

    public init(
      configuration: IntercomChannelConfiguration,
      id: SupportChannelID = .intercomMessenger,
      displayName: String = "Intercom"
    ) {
      self.id = id
      self.displayName = displayName
      super.init()
      Intercom.setApiKey(configuration.apiKey, forAppId: configuration.appID)
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(unreadChanged),
        name: Notification.Name(rawValue: IntercomUnreadConversationCountDidChangeNotification),
        object: nil
      )
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    public func identify(_ session: SupportChannelSession) async throws {
      if let jwt = session.credential(for: id), !jwt.isEmpty { Intercom.setUserJwt(jwt) }
      let attributes = ICMUserAttributes()
      attributes.userId = session.customer.externalID
      attributes.email = session.customer.email
      attributes.name = session.customer.name
      try await withCheckedThrowingContinuation { continuation in
        Intercom.loginUser(with: attributes) { result in continuation.resume(with: result) }
      }
    }

    public func present() async throws { Intercom.presentIntercom() }
    public func dismiss() async { Intercom.hideIntercom() }
    public func setPushToken(_ token: Data) async throws {
      try await withCheckedThrowingContinuation { continuation in
        Intercom.setDeviceToken(token) { result in continuation.resume(with: result) }
      }
    }
    public func logout() async { Intercom.logout() }

    @objc private func unreadChanged() {
      delegate?.supportChannel(
        self,
        didEmit: .unreadCountChanged(Int(Intercom.unreadConversationCount()))
      )
    }
  }
#endif
