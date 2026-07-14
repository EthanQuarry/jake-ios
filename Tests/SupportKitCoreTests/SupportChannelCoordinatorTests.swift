import SupportKitCore
import XCTest

@MainActor
private final class FakeChannel: SupportChannelAdapter {
  let id: SupportChannelID
  let displayName = "Fake"
  let capabilities = SupportChannelCapabilities(
    presentation: .headless,
    programmaticMessaging: true,
    unreadCount: false,
    pushNotifications: false,
    attachments: true,
    externalAgentRouting: true
  )
  weak var delegate: (any SupportChannelAdapterDelegate)?
  var sent: [OutgoingSupportMessage] = []

  init(id: SupportChannelID) { self.id = id }
  func identify(_: SupportChannelSession) async throws {}
  func present() async throws {}
  func dismiss() async {}
  func logout() async {}
  func send(_ message: OutgoingSupportMessage, in _: String?) async throws { sent.append(message) }
}

final class SupportChannelCoordinatorTests: XCTestCase {
  func testChannelIDUsesPortableStringEncoding() throws {
    let encoded = try JSONEncoder().encode(SupportChannelID.native)
    XCTAssertEqual(String(decoding: encoded, as: UTF8.self), "\"supportkit-native\"")
    XCTAssertEqual(try JSONDecoder().decode(SupportChannelID.self, from: encoded), .native)
  }

  @MainActor
  func testActiveConversationPinsChannel() async throws {
    let first = FakeChannel(id: "first")
    let second = FakeChannel(id: "second")
    let coordinator = SupportChannelCoordinator()
    try coordinator.register(first)
    try coordinator.register(second)
    try coordinator.select(first.id)
    try await coordinator.startSession(
      SupportChannelSession(customer: SupportCustomer(id: "1", externalID: "ext-1"))
    )
    try coordinator.pinConversation("conversation-1")

    XCTAssertThrowsError(try coordinator.select(second.id))
    try await coordinator.send(OutgoingSupportMessage(body: "hello"))
    XCTAssertEqual(first.sent.count, 1)
  }
}
