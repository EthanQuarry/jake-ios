import Foundation
import JakeSDK
import SupportKitCore

@MainActor
public final class JakeChannelAdapter: SupportChannelAdapter, JakeDelegate {
  public let id: SupportChannelID
  public let displayName: String
  public let aiDisclosure: String?
  public let capabilities = SupportChannelCapabilities(
    presentation: .opaqueVendorMessenger,
    programmaticMessaging: false,
    unreadCount: true,
    pushNotifications: true,
    attachments: false,
    externalAgentRouting: false
  )
  public weak var delegate: (any SupportChannelAdapterDelegate)?
  private let configuration: JakeConfiguration

  public init(
    configuration: JakeConfiguration,
    id: SupportChannelID = .jakeMessenger,
    displayName: String = "Jake",
    aiDisclosure: String? = "AI agent"
  ) {
    self.configuration = configuration
    self.id = id
    self.displayName = displayName
    self.aiDisclosure = aiDisclosure
  }

  public func identify(_ session: SupportChannelSession) async throws {
    guard let token = session.credential(for: id), !token.isEmpty else {
      throw SupportChannelError.missingCredential(id)
    }
    Jake.configure(
      workspaceId: configuration.workspaceId,
      publicKey: configuration.publicKey,
      messengerURL: configuration.messengerURL
    )
    Jake.delegate = self
    try await Jake.authenticate(userId: session.customer.externalID, token: token)
  }

  public func present() async throws {
    #if canImport(UIKit)
      Jake.present()
      delegate?.supportChannel(self, didEmit: .presented)
    #else
      throw SupportChannelError.unsupported(channel: id, operation: "Messenger presentation")
    #endif
  }

  public func dismiss() async {
    #if canImport(UIKit)
      Jake.dismiss()
      delegate?.supportChannel(self, didEmit: .dismissed)
    #endif
  }

  public func setPushToken(_ token: Data) async throws { Jake.setPushToken(token) }
  public func logout() async { Jake.logout() }
  public func jakeDidUpdateUnreadCount(_ count: Int) {
    delegate?.supportChannel(self, didEmit: .unreadCountChanged(count))
  }
  public func jakeAuthenticationDidExpire() {
    delegate?.supportChannel(self, didEmit: .authenticationExpired)
  }
  public func jakeDidFail(with error: JakeError) {
    delegate?.supportChannel(
      self,
      didEmit: .failure(code: "jake_error", message: error.localizedDescription)
    )
  }
}
