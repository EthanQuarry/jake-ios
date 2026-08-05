import Foundation
import SupportAdapterKit

@MainActor
public final class JakeSupportProvider: SupportProvider, JakeDelegate {
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

  private let configuration: JakeConfiguration

  public init(
    configuration: JakeConfiguration,
    id: SupportProviderID = .jake,
    displayName: String = "Jake"
  ) {
    self.configuration = configuration
    self.id = id
    self.displayName = displayName
  }

  public func authenticate(_ session: SupportSession) async throws {
    guard let token = session.credential(for: id)?.token, !token.isEmpty else {
      throw SupportAdapterError.missingCredential(id)
    }

    Jake.configure(
      workspaceId: configuration.workspaceId,
      publicKey: configuration.publicKey,
      conversationAPIURL: configuration.conversationAPIURL
    )
    Jake.delegate = self
    try await Jake.authenticate(userId: session.user.id, token: token)

    var attributes = session.user.attributes.mapValues(Self.jakeValue)
    if let email = session.user.email { attributes["email"] = .string(email) }
    if let name = session.user.name { attributes["name"] = .string(name) }
    if !attributes.isEmpty {
      Jake.setUserAttributes(attributes)
    }
  }

  public func present() async throws {
    #if canImport(UIKit)
      try Jake.presentForAdapter()
      delegate?.supportProvider(self, didEmit: .messengerPresented)
    #else
      throw JakeError.presentationUnavailable
    #endif
  }

  public func dismiss() async {
    #if canImport(UIKit)
      Jake.dismiss()
      delegate?.supportProvider(self, didEmit: .messengerDismissed)
    #endif
  }

  public func logout() async {
    Jake.logout()
  }

  public func track(event: String, properties: [String: SupportValue]) async throws {
    Jake.track(event, properties: properties.mapValues(Self.jakeValue))
  }

  public func setUserAttributes(_ attributes: [String: SupportValue]) async throws {
    Jake.setUserAttributes(attributes.mapValues(Self.jakeValue))
  }

  public func setPushToken(_ token: Data) async throws {
    Jake.setPushToken(token)
  }

  public func jakeDidUpdateUnreadCount(_ count: Int) {
    delegate?.supportProvider(self, didEmit: .unreadCountChanged(count))
  }

  public func jakeAuthenticationDidExpire() {
    delegate?.supportProvider(self, didEmit: .authenticationExpired)
  }

  public func jakeDidFail(with error: JakeError) {
    delegate?.supportProvider(
      self,
      didEmit: .failure(
        SupportProviderFailure(
          code: Self.errorCode(error),
          message: error.localizedDescription
        )
      )
    )
  }

  private static func jakeValue(_ value: SupportValue) -> JakeValue {
    switch value {
    case .string(let value): .string(value)
    case .integer(let value): .integer(value)
    case .double(let value): .double(value)
    case .boolean(let value): .boolean(value)
    case .null: .null
    }
  }

  private static func errorCode(_ error: JakeError) -> String {
    switch error {
    case .notConfigured: "not_configured"
    case .invalidConfiguration: "invalid_configuration"
    case .invalidAuthentication: "invalid_authentication"
    case .authenticationRequired: "authentication_required"
    case .authenticationExpired: "authentication_expired"
    case .tokenStorageFailed: "token_storage_failed"
    case .presentationUnavailable: "presentation_unavailable"
    case .messengerLoadFailed: "messenger_load_failed"
    }
  }
}
