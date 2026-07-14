import Foundation

public enum SupportProviderSelectionSource: String, Equatable, Sendable {
  case local
  case remote
  case handoff
}

@MainActor
public protocol SupportCoordinatorDelegate: AnyObject {
  func supportCoordinator(
    _ coordinator: SupportCoordinator,
    didSelect providerID: SupportProviderID,
    previousProviderID: SupportProviderID?,
    source: SupportProviderSelectionSource
  )

  func supportCoordinator(
    _ coordinator: SupportCoordinator,
    providerID: SupportProviderID,
    didEmit event: SupportProviderEvent
  )
}

extension SupportCoordinatorDelegate {
  public func supportCoordinator(
    _: SupportCoordinator,
    didSelect _: SupportProviderID,
    previousProviderID _: SupportProviderID?,
    source _: SupportProviderSelectionSource
  ) {}

  public func supportCoordinator(
    _: SupportCoordinator,
    providerID _: SupportProviderID,
    didEmit _: SupportProviderEvent
  ) {}
}

@MainActor
public final class SupportCoordinator: SupportProviderDelegate {
  public weak var delegate: (any SupportCoordinatorDelegate)?

  public private(set) var selectedProviderID: SupportProviderID?
  public private(set) var activeProviderID: SupportProviderID?
  public private(set) var activeSession: SupportSession?

  private var providers: [SupportProviderID: any SupportProvider] = [:]

  public init() {}

  public var availableProviderIDs: [SupportProviderID] {
    providers.keys.sorted { $0.rawValue < $1.rawValue }
  }

  public func register(_ provider: any SupportProvider) throws {
    guard providers[provider.id] == nil else {
      throw SupportAdapterError.duplicateProvider(provider.id)
    }
    provider.delegate = self
    providers[provider.id] = provider
  }

  public func unregister(providerID: SupportProviderID) throws {
    if activeProviderID == providerID {
      throw SupportAdapterError.cannotUnregisterActiveProvider(providerID)
    }
    providers[providerID]?.delegate = nil
    providers[providerID] = nil
    if selectedProviderID == providerID {
      selectedProviderID = nil
    }
  }

  public func provider(for providerID: SupportProviderID) throws -> any SupportProvider {
    guard let provider = providers[providerID] else {
      throw SupportAdapterError.providerNotRegistered(providerID)
    }
    return provider
  }

  public func selectProvider(
    _ providerID: SupportProviderID,
    source: SupportProviderSelectionSource = .local
  ) throws {
    _ = try provider(for: providerID)
    if let activeProviderID, activeProviderID != providerID {
      throw SupportAdapterError.activeSessionPinned(
        active: activeProviderID,
        requested: providerID
      )
    }

    let previous = selectedProviderID
    selectedProviderID = providerID
    guard previous != providerID else { return }
    delegate?.supportCoordinator(
      self,
      didSelect: providerID,
      previousProviderID: previous,
      source: source
    )
  }

  @discardableResult
  public func refreshSelection(
    using selector: any SupportProviderSelecting,
    context: SupportRoutingContext
  ) async throws -> SupportProviderSelection {
    let selection = try await selector.selectProvider(for: context)
    try selectProvider(selection.provider, source: .remote)
    return selection
  }

  public func startSession(_ session: SupportSession) async throws {
    if let activeProviderID {
      throw SupportAdapterError.sessionAlreadyActive(activeProviderID)
    }
    guard let selectedProviderID else {
      throw SupportAdapterError.noProviderSelected
    }
    let provider = try provider(for: selectedProviderID)
    try await provider.authenticate(session)
    activeProviderID = selectedProviderID
    activeSession = session
  }

  public func present() async throws {
    let provider = try activeProvider()
    try require(.messenger, from: provider)
    try await provider.present()
  }

  public func dismiss() async throws {
    let provider = try activeProvider()
    await provider.dismiss()
  }

  public func endSession() async {
    guard let activeProviderID, let provider = providers[activeProviderID] else { return }
    await provider.dismiss()
    await provider.logout()
    self.activeProviderID = nil
    activeSession = nil
  }

  @discardableResult
  public func handoff(
    to targetProviderID: SupportProviderID,
    context: SupportHandoffContext
  ) async throws -> SupportHandoffResult {
    let source = try activeProvider()
    guard let session = activeSession else {
      throw SupportAdapterError.noActiveSession
    }
    guard source.id != targetProviderID else {
      return SupportHandoffResult(
        sourceProviderID: source.id,
        targetProviderID: targetProviderID,
        contextTransferred: source.capabilities.contains(.handoffContext)
      )
    }

    let target = try provider(for: targetProviderID)
    try await target.authenticate(session)

    let transfersContext = target.capabilities.contains(.handoffContext)
    do {
      if transfersContext {
        try await target.receiveHandoff(context)
      }
    } catch {
      await target.logout()
      throw error
    }

    await source.dismiss()
    await source.logout()

    let previous = activeProviderID
    activeProviderID = targetProviderID
    selectedProviderID = targetProviderID
    delegate?.supportCoordinator(
      self,
      didSelect: targetProviderID,
      previousProviderID: previous,
      source: .handoff
    )

    return SupportHandoffResult(
      sourceProviderID: source.id,
      targetProviderID: targetProviderID,
      contextTransferred: transfersContext
    )
  }

  public func track(event: String, properties: [String: SupportValue] = [:]) async throws {
    let provider = try activeProvider()
    try require(.eventTracking, from: provider)
    try await provider.track(event: event, properties: properties)
  }

  public func setUserAttributes(_ attributes: [String: SupportValue]) async throws {
    let provider = try activeProvider()
    try require(.userAttributes, from: provider)
    try await provider.setUserAttributes(attributes)
  }

  public func setPushToken(_ token: Data) async throws {
    let provider = try activeProvider()
    try require(.pushNotifications, from: provider)
    try await provider.setPushToken(token)
  }

  public func supportProvider(
    _ provider: any SupportProvider,
    didEmit event: SupportProviderEvent
  ) {
    if provider.id == activeProviderID, event == .authenticationExpired {
      activeProviderID = nil
      activeSession = nil
    }
    delegate?.supportCoordinator(self, providerID: provider.id, didEmit: event)
  }

  private func activeProvider() throws -> any SupportProvider {
    guard let activeProviderID else {
      throw SupportAdapterError.noActiveSession
    }
    return try provider(for: activeProviderID)
  }

  private func require(_ capability: SupportCapability, from provider: any SupportProvider) throws {
    guard provider.capabilities.contains(capability) else {
      throw SupportAdapterError.unsupportedCapability(
        provider: provider.id,
        capability: capability
      )
    }
  }
}
