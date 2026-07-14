import Foundation

public enum SupportAdapterError: LocalizedError, Equatable, Sendable {
  case duplicateProvider(SupportProviderID)
  case providerNotRegistered(SupportProviderID)
  case noProviderSelected
  case noActiveSession
  case sessionAlreadyActive(SupportProviderID)
  case cannotUnregisterActiveProvider(SupportProviderID)
  case activeSessionPinned(active: SupportProviderID, requested: SupportProviderID)
  case missingCredential(SupportProviderID)
  case unsupportedCapability(provider: SupportProviderID, capability: SupportCapability)
  case invalidSelectionResponse(String)
  case selectionRequestFailed(statusCode: Int)

  public var errorDescription: String? {
    switch self {
    case .duplicateProvider(let provider):
      return "A support provider with ID '\(provider)' is already registered."
    case .providerNotRegistered(let provider):
      return "Support provider '\(provider)' is not registered."
    case .noProviderSelected:
      return "No support provider is selected."
    case .noActiveSession:
      return "There is no active support session."
    case .sessionAlreadyActive(let provider):
      return "A support session is already active on '\(provider)'."
    case .cannotUnregisterActiveProvider(let provider):
      return "Support provider '\(provider)' cannot be unregistered while its session is active."
    case .activeSessionPinned(let active, let requested):
      return "The active session is pinned to '\(active)' and cannot switch to '\(requested)' without an explicit handoff or endSession()."
    case .missingCredential(let provider):
      return "No credential was supplied for support provider '\(provider)'."
    case .unsupportedCapability(let provider, let capability):
      return "Support provider '\(provider)' does not support '\(capability.rawValue)'."
    case .invalidSelectionResponse(let message):
      return "The support provider selection response is invalid: \(message)"
    case .selectionRequestFailed(let statusCode):
      return "The support provider selection request failed with HTTP \(statusCode)."
    }
  }
}

public struct SupportProviderFailure: Codable, Equatable, Sendable {
  public let code: String
  public let message: String

  public init(code: String, message: String) {
    self.code = code
    self.message = message
  }
}
