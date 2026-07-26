import SupportKitCore
import XCTest

@testable import SupportKitUI

@MainActor
private final class ConversationChannel: SupportChannelAdapter {
  enum Failure: LocalizedError {
    case send

    var errorDescription: String? { "The message could not be sent." }
  }

  let id: SupportChannelID = .native
  let displayName = "Test"
  let aiDisclosure: String? = "AI agent"
  let capabilities = SupportChannelCapabilities(
    presentation: .nativeRouterUI,
    programmaticMessaging: true,
    unreadCount: false,
    pushNotifications: false,
    attachments: false,
    externalAgentRouting: true
  )
  weak var delegate: (any SupportChannelAdapterDelegate)?
  var shouldFail = false
  var sent: [OutgoingSupportMessage] = []

  func identify(_: SupportChannelSession) async throws {}
  func present() async throws {}
  func dismiss() async {}
  func setPushToken(_: Data) async throws {}
  func logout() async {}

  func send(_ message: OutgoingSupportMessage, in _: String?) async throws {
    sent.append(message)
    if shouldFail { throw Failure.send }
  }
}

final class SupportConversationModelTests: XCTestCase {
  @MainActor
  func testExposesChannelIdentityAndAIDisclosure() {
    let model = SupportConversationModel(channel: ConversationChannel())

    XCTAssertEqual(model.channelName, "Test")
    XCTAssertEqual(model.aiDisclosure, "AI agent")
  }

  @MainActor
  func testSendsTrimmedDraftAndAddsOptimisticMessage() async {
    let channel = ConversationChannel()
    let model = SupportConversationModel(channel: channel)
    model.draft = "  Hello Jake  "

    model.send()
    await Task.yield()

    XCTAssertEqual(channel.sent.map(\.body), ["Hello Jake"])
    XCTAssertEqual(model.messages.map(\.body), ["Hello Jake"])
    XCTAssertEqual(model.draft, "")
    XCTAssertNil(model.errorMessage)
  }

  @MainActor
  func testRestoresDraftAndRemovesOptimisticMessageWhenSendFails() async {
    let channel = ConversationChannel()
    channel.shouldFail = true
    let model = SupportConversationModel(channel: channel)
    model.draft = "Please try again"

    model.send()
    await Task.yield()
    await Task.yield()

    XCTAssertEqual(model.draft, "Please try again")
    XCTAssertTrue(model.messages.isEmpty)
    XCTAssertEqual(model.errorMessage, "The message could not be sent.")
    XCTAssertFalse(model.isSending)
  }
}
