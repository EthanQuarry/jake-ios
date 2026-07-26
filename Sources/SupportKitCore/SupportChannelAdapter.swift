import Foundation

public enum SupportChannelPresentation: String, Codable, Sendable {
  case nativeRouterUI
  case opaqueVendorMessenger
  case headless
}

public struct SupportChannelCapabilities: Equatable, Sendable {
  public let presentation: SupportChannelPresentation
  public let programmaticMessaging: Bool
  public let unreadCount: Bool
  public let pushNotifications: Bool
  public let attachments: Bool
  public let externalAgentRouting: Bool

  public init(
    presentation: SupportChannelPresentation,
    programmaticMessaging: Bool,
    unreadCount: Bool,
    pushNotifications: Bool,
    attachments: Bool,
    externalAgentRouting: Bool
  ) {
    self.presentation = presentation
    self.programmaticMessaging = programmaticMessaging
    self.unreadCount = unreadCount
    self.pushNotifications = pushNotifications
    self.attachments = attachments
    self.externalAgentRouting = externalAgentRouting
  }
}

public enum SupportChannelEvent: Equatable, Sendable {
  case presented
  case dismissed
  case unreadCountChanged(Int)
  case conversationStarted(String)
  case messageReceived(SupportMessage)
  case messageUpdated(SupportMessage)
  case citation(SupportCitation)
  case actionRequested(SupportActionRequest)
  case clarificationRequested(question: String, fields: [String])
  case handoffRequested(reason: String, targetHint: String?)
  case authenticationExpired
  case failure(code: String, message: String)
}

@MainActor
public protocol SupportChannelAdapterDelegate: AnyObject {
  func supportChannel(_ channel: any SupportChannelAdapter, didEmit event: SupportChannelEvent)
}

@MainActor
public protocol SupportChannelAdapter: AnyObject {
  var id: SupportChannelID { get }
  var displayName: String { get }
  var aiDisclosure: String? { get }
  var capabilities: SupportChannelCapabilities { get }
  var delegate: (any SupportChannelAdapterDelegate)? { get set }

  func identify(_ session: SupportChannelSession) async throws
  func present() async throws
  func dismiss() async
  func send(_ message: OutgoingSupportMessage, in conversationID: String?) async throws
  func setPushToken(_ token: Data) async throws
  func logout() async
}

extension SupportChannelAdapter {
  public var aiDisclosure: String? { nil }

  public func send(_: OutgoingSupportMessage, in _: String?) async throws {
    throw SupportChannelError.unsupported(channel: id, operation: "programmatic messaging")
  }

  public func setPushToken(_: Data) async throws {
    throw SupportChannelError.unsupported(channel: id, operation: "push notifications")
  }
}

public enum SupportChannelError: Error, Equatable, LocalizedError {
  case duplicateChannel(SupportChannelID)
  case channelNotRegistered(SupportChannelID)
  case noChannelSelected
  case noActiveSession
  case conversationPinned(active: SupportChannelID, requested: SupportChannelID)
  case unsupported(channel: SupportChannelID, operation: String)
  case missingCredential(SupportChannelID)
  case invalidServerResponse(String)
  case requestFailed(statusCode: Int)

  public var errorDescription: String? {
    switch self {
    case .duplicateChannel(let id): "Channel '\(id.rawValue)' is already registered."
    case .channelNotRegistered(let id): "Channel '\(id.rawValue)' is not registered."
    case .noChannelSelected: "Select a support channel before starting a session."
    case .noActiveSession: "Start a support session first."
    case .conversationPinned(let active, let requested):
      "The active conversation is pinned to '\(active.rawValue)', not '\(requested.rawValue)'."
    case .unsupported(let channel, let operation):
      "Channel '\(channel.rawValue)' does not support \(operation)."
    case .missingCredential(let channel): "No credential was supplied for '\(channel.rawValue)'."
    case .invalidServerResponse(let reason): "The support server response is invalid: \(reason)."
    case .requestFailed(let statusCode): "The support server returned HTTP \(statusCode)."
    }
  }
}
