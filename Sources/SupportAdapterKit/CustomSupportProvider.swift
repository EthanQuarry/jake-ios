import Foundation

public struct CustomSupportProviderHandlers {
  public var authenticate: @MainActor (SupportSession) async throws -> Void
  public var present: @MainActor () async throws -> Void
  public var dismiss: @MainActor () async -> Void
  public var logout: @MainActor () async -> Void
  public var track: @MainActor (String, [String: SupportValue]) async throws -> Void
  public var setUserAttributes: @MainActor ([String: SupportValue]) async throws -> Void
  public var setPushToken: @MainActor (Data) async throws -> Void
  public var receiveHandoff: @MainActor (SupportHandoffContext) async throws -> Void

  public init(
    authenticate: @escaping @MainActor (SupportSession) async throws -> Void = { _ in },
    present: @escaping @MainActor () async throws -> Void,
    dismiss: @escaping @MainActor () async -> Void = {},
    logout: @escaping @MainActor () async -> Void = {},
    track: @escaping @MainActor (String, [String: SupportValue]) async throws -> Void = { _, _ in },
    setUserAttributes: @escaping @MainActor ([String: SupportValue]) async throws -> Void = { _ in },
    setPushToken: @escaping @MainActor (Data) async throws -> Void = { _ in },
    receiveHandoff: @escaping @MainActor (SupportHandoffContext) async throws -> Void = { _ in }
  ) {
    self.authenticate = authenticate
    self.present = present
    self.dismiss = dismiss
    self.logout = logout
    self.track = track
    self.setUserAttributes = setUserAttributes
    self.setPushToken = setPushToken
    self.receiveHandoff = receiveHandoff
  }
}

@MainActor
public final class CustomSupportProvider: SupportProvider {
  public let id: SupportProviderID
  public let displayName: String
  public let capabilities: Set<SupportCapability>
  public weak var delegate: (any SupportProviderDelegate)?

  private let handlers: CustomSupportProviderHandlers

  public init(
    id: SupportProviderID,
    displayName: String,
    capabilities: Set<SupportCapability> = [.messenger],
    handlers: CustomSupportProviderHandlers
  ) {
    self.id = id
    self.displayName = displayName
    self.capabilities = capabilities
    self.handlers = handlers
  }

  public func authenticate(_ session: SupportSession) async throws {
    try await handlers.authenticate(session)
  }

  public func present() async throws {
    try await handlers.present()
  }

  public func dismiss() async {
    await handlers.dismiss()
  }

  public func logout() async {
    await handlers.logout()
  }

  public func track(event: String, properties: [String: SupportValue]) async throws {
    try await handlers.track(event, properties)
  }

  public func setUserAttributes(_ attributes: [String: SupportValue]) async throws {
    try await handlers.setUserAttributes(attributes)
  }

  public func setPushToken(_ token: Data) async throws {
    try await handlers.setPushToken(token)
  }

  public func receiveHandoff(_ context: SupportHandoffContext) async throws {
    try await handlers.receiveHandoff(context)
  }

  public func emit(_ event: SupportProviderEvent) {
    delegate?.supportProvider(self, didEmit: event)
  }
}
