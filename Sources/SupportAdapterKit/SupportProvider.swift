import Foundation

public enum SupportProviderEvent: Equatable, Sendable {
  case messengerPresented
  case messengerDismissed
  case unreadCountChanged(Int)
  case authenticationExpired
  case conversationStarted(id: String?)
  case failure(SupportProviderFailure)
}

@MainActor
public protocol SupportProviderDelegate: AnyObject {
  func supportProvider(_ provider: any SupportProvider, didEmit event: SupportProviderEvent)
}

@MainActor
public protocol SupportProvider: AnyObject {
  var id: SupportProviderID { get }
  var displayName: String { get }
  var capabilities: Set<SupportCapability> { get }
  var delegate: (any SupportProviderDelegate)? { get set }

  func authenticate(_ session: SupportSession) async throws
  func present() async throws
  func dismiss() async
  func logout() async
  func track(event: String, properties: [String: SupportValue]) async throws
  func setUserAttributes(_ attributes: [String: SupportValue]) async throws
  func setPushToken(_ token: Data) async throws
  func receiveHandoff(_ context: SupportHandoffContext) async throws
}

extension SupportProvider {
  public func track(event _: String, properties _: [String: SupportValue]) async throws {
    throw SupportAdapterError.unsupportedCapability(provider: id, capability: .eventTracking)
  }

  public func setUserAttributes(_: [String: SupportValue]) async throws {
    throw SupportAdapterError.unsupportedCapability(provider: id, capability: .userAttributes)
  }

  public func setPushToken(_: Data) async throws {
    throw SupportAdapterError.unsupportedCapability(provider: id, capability: .pushNotifications)
  }

  public func receiveHandoff(_: SupportHandoffContext) async throws {
    throw SupportAdapterError.unsupportedCapability(provider: id, capability: .handoffContext)
  }
}
