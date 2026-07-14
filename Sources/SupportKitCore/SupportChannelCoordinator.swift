import Foundation

@MainActor
public final class SupportChannelCoordinator: SupportChannelAdapterDelegate {
  public private(set) var selectedChannelID: SupportChannelID?
  public private(set) var activeChannelID: SupportChannelID?
  public private(set) var activeConversationID: String?
  public private(set) var activeSession: SupportChannelSession?
  public var onEvent: ((SupportChannelID, SupportChannelEvent) -> Void)?

  private var channels: [SupportChannelID: any SupportChannelAdapter] = [:]

  public init() {}

  public func register(_ channel: any SupportChannelAdapter) throws {
    guard channels[channel.id] == nil else {
      throw SupportChannelError.duplicateChannel(channel.id)
    }
    channel.delegate = self
    channels[channel.id] = channel
  }

  public func select(_ id: SupportChannelID) throws {
    guard channels[id] != nil else { throw SupportChannelError.channelNotRegistered(id) }
    if let activeChannelID, activeChannelID != id {
      throw SupportChannelError.conversationPinned(active: activeChannelID, requested: id)
    }
    selectedChannelID = id
  }

  public func startSession(_ session: SupportChannelSession) async throws {
    guard let selectedChannelID else { throw SupportChannelError.noChannelSelected }
    guard let channel = channels[selectedChannelID] else {
      throw SupportChannelError.channelNotRegistered(selectedChannelID)
    }
    try await channel.identify(session)
    activeChannelID = selectedChannelID
    activeSession = session
  }

  public func pinConversation(_ conversationID: String) throws {
    guard activeChannelID != nil else { throw SupportChannelError.noActiveSession }
    if let activeConversationID, activeConversationID != conversationID {
      throw SupportChannelError.invalidServerResponse("a different conversation is already active")
    }
    activeConversationID = conversationID
  }

  public func present() async throws { try await activeChannel().present() }
  public func dismiss() async throws {
    let channel = try activeChannel()
    await channel.dismiss()
  }

  public func send(_ message: OutgoingSupportMessage) async throws {
    let channel = try activeChannel()
    guard channel.capabilities.programmaticMessaging else {
      throw SupportChannelError.unsupported(
        channel: channel.id, operation: "programmatic messaging")
    }
    try await channel.send(message, in: activeConversationID)
  }

  public func endSession() async {
    guard let activeChannelID, let channel = channels[activeChannelID] else { return }
    await channel.dismiss()
    await channel.logout()
    self.activeChannelID = nil
    activeConversationID = nil
    activeSession = nil
  }

  public func supportChannel(
    _ channel: any SupportChannelAdapter,
    didEmit event: SupportChannelEvent
  ) {
    if case .conversationStarted(let id) = event { activeConversationID = id }
    if event == .authenticationExpired {
      activeChannelID = nil
      activeConversationID = nil
      activeSession = nil
    }
    onEvent?(channel.id, event)
  }

  private func activeChannel() throws -> any SupportChannelAdapter {
    guard let activeChannelID else { throw SupportChannelError.noActiveSession }
    guard let channel = channels[activeChannelID] else {
      throw SupportChannelError.channelNotRegistered(activeChannelID)
    }
    return channel
  }
}
