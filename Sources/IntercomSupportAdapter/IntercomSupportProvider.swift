#if canImport(UIKit)
  import Foundation
  import Intercom
  import SupportAdapterKit
  import UIKit

  public struct IntercomSupportConfiguration: Equatable, Sendable {
    public let apiKey: String
    public let appID: String

    public init(apiKey: String, appID: String) {
      self.apiKey = apiKey
      self.appID = appID
    }
  }

  @MainActor
  public final class IntercomSupportProvider: NSObject, SupportProvider {
    public let id: SupportProviderID
    public let displayName: String
    public let capabilities: Set<SupportCapability> = [
      .messenger,
      .unreadCount,
      .eventTracking,
      .userAttributes,
      .pushNotifications,
    ]
    public weak var delegate: (any SupportProviderDelegate)?

    private let configuration: IntercomSupportConfiguration

    public init(
      configuration: IntercomSupportConfiguration,
      id: SupportProviderID = .intercom,
      displayName: String = "Intercom"
    ) {
      self.configuration = configuration
      self.id = id
      self.displayName = displayName
      super.init()
      Intercom.setApiKey(configuration.apiKey, forAppId: configuration.appID)
      observeIntercomEvents()
    }

    deinit {
      NotificationCenter.default.removeObserver(self)
    }

    public func authenticate(_ session: SupportSession) async throws {
      if let jwt = session.credential(for: id)?.token, !jwt.isEmpty {
        Intercom.setUserJwt(jwt)
      }

      let attributes = Self.userAttributes(from: session.user)
      try await withCheckedThrowingContinuation { continuation in
        Intercom.loginUser(with: attributes) { result in
          continuation.resume(with: result)
        }
      }
      delegate?.supportProvider(
        self,
        didEmit: .unreadCountChanged(Int(Intercom.unreadConversationCount()))
      )
    }

    public func present() async throws {
      Intercom.present()
    }

    public func dismiss() async {
      Intercom.hide()
    }

    public func logout() async {
      Intercom.logout()
    }

    public func track(event: String, properties: [String: SupportValue]) async throws {
      Intercom.logEvent(
        withName: event,
        metaData: properties.mapValues(Self.foundationValue)
      )
    }

    public func setUserAttributes(_ attributes: [String: SupportValue]) async throws {
      let userAttributes = ICMUserAttributes()
      userAttributes.customAttributes = attributes.mapValues(Self.foundationValue)
      try await withCheckedThrowingContinuation { continuation in
        Intercom.updateUser(with: userAttributes) { result in
          continuation.resume(with: result)
        }
      }
    }

    public func setPushToken(_ token: Data) async throws {
      try await withCheckedThrowingContinuation { continuation in
        Intercom.setDeviceToken(token) { result in
          continuation.resume(with: result)
        }
      }
    }

    @objc private func messengerDidShow() {
      delegate?.supportProvider(self, didEmit: .messengerPresented)
    }

    @objc private func messengerDidHide() {
      delegate?.supportProvider(self, didEmit: .messengerDismissed)
    }

    @objc private func unreadCountDidChange() {
      delegate?.supportProvider(
        self,
        didEmit: .unreadCountChanged(Int(Intercom.unreadConversationCount()))
      )
    }

    @objc private func conversationDidStart() {
      delegate?.supportProvider(self, didEmit: .conversationStarted(id: nil))
    }

    private func observeIntercomEvents() {
      let center = NotificationCenter.default
      center.addObserver(
        self,
        selector: #selector(messengerDidShow),
        name: .IntercomWindowDidShow,
        object: nil
      )
      center.addObserver(
        self,
        selector: #selector(messengerDidHide),
        name: .IntercomWindowDidHide,
        object: nil
      )
      center.addObserver(
        self,
        selector: #selector(unreadCountDidChange),
        name: .IntercomUnreadConversationCountDidChange,
        object: nil
      )
      center.addObserver(
        self,
        selector: #selector(conversationDidStart),
        name: .IntercomDidStartNewConversation,
        object: nil
      )
    }

    private static func userAttributes(from user: SupportUser) -> ICMUserAttributes {
      let attributes = ICMUserAttributes()
      attributes.userId = user.id
      attributes.email = user.email
      attributes.name = user.name
      attributes.customAttributes = user.attributes.mapValues(foundationValue)
      return attributes
    }

    private static func foundationValue(_ value: SupportValue) -> Any {
      switch value {
      case .string(let value): value
      case .integer(let value): value
      case .double(let value): value
      case .boolean(let value): value
      case .null: NSNull()
      }
    }
  }
#endif
