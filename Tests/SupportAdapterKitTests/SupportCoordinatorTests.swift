import Foundation
import XCTest

@testable import SupportAdapterKit

@MainActor
final class SupportCoordinatorTests: XCTestCase {
  func testActiveSessionIsPinnedUntilExplicitHandoff() async throws {
    let coordinator = SupportCoordinator()
    let jake = MockSupportProvider(id: .jake)
    let intercom = MockSupportProvider(id: .intercom)
    try coordinator.register(jake)
    try coordinator.register(intercom)
    try coordinator.selectProvider(.jake)
    try await coordinator.startSession(Self.session)

    XCTAssertThrowsError(try coordinator.selectProvider(.intercom)) { error in
      XCTAssertEqual(
        error as? SupportAdapterError,
        .activeSessionPinned(active: .jake, requested: .intercom)
      )
    }
    XCTAssertEqual(coordinator.activeProviderID, .jake)
    XCTAssertEqual(jake.authenticateCount, 1)
    XCTAssertEqual(intercom.authenticateCount, 0)
  }

  func testHandoffAuthenticatesTargetBeforeEndingSource() async throws {
    let coordinator = SupportCoordinator()
    let source = MockSupportProvider(id: .jake)
    let target = MockSupportProvider(id: .internalAgent, capabilities: [.messenger, .handoffContext])
    try coordinator.register(source)
    try coordinator.register(target)
    try coordinator.selectProvider(.jake)
    try await coordinator.startSession(Self.session)

    let context = SupportHandoffContext(
      reason: "customer requested specialist",
      externalConversationID: "conversation-1",
      transcriptSummary: "Customer needs a billing correction."
    )
    let result = try await coordinator.handoff(to: .internalAgent, context: context)

    XCTAssertEqual(result.sourceProviderID, .jake)
    XCTAssertEqual(result.targetProviderID, .internalAgent)
    XCTAssertTrue(result.contextTransferred)
    XCTAssertEqual(target.receivedHandoff, context)
    XCTAssertEqual(source.dismissCount, 1)
    XCTAssertEqual(source.logoutCount, 1)
    XCTAssertEqual(coordinator.activeProviderID, .internalAgent)
    XCTAssertEqual(coordinator.selectedProviderID, .internalAgent)
  }

  func testFailedHandoffLeavesSourcePinned() async throws {
    let coordinator = SupportCoordinator()
    let source = MockSupportProvider(id: .jake)
    let target = MockSupportProvider(id: .internalAgent, capabilities: [.messenger, .handoffContext])
    target.handoffError = TestError.rejected
    try coordinator.register(source)
    try coordinator.register(target)
    try coordinator.selectProvider(.jake)
    try await coordinator.startSession(Self.session)

    do {
      _ = try await coordinator.handoff(
        to: .internalAgent,
        context: SupportHandoffContext(reason: "test")
      )
      XCTFail("Expected handoff to fail")
    } catch {
      XCTAssertEqual(error as? TestError, .rejected)
    }

    XCTAssertEqual(coordinator.activeProviderID, .jake)
    XCTAssertEqual(source.logoutCount, 0)
    XCTAssertEqual(target.logoutCount, 1)
  }

  func testRemoteSelectionCannotMoveLiveConversation() async throws {
    let coordinator = SupportCoordinator()
    try coordinator.register(MockSupportProvider(id: .jake))
    try coordinator.register(MockSupportProvider(id: .intercom))
    try coordinator.selectProvider(.jake)
    try await coordinator.startSession(Self.session)
    let selector = StaticSupportProviderSelector(provider: .intercom)

    do {
      _ = try await coordinator.refreshSelection(
        using: selector,
        context: SupportRoutingContext(userID: "customer-1")
      )
      XCTFail("Expected the live provider pin to reject remote selection")
    } catch {
      XCTAssertEqual(
        error as? SupportAdapterError,
        .activeSessionPinned(active: .jake, requested: .intercom)
      )
    }
  }

  func testAuthenticationExpiryClearsActiveSession() async throws {
    let coordinator = SupportCoordinator()
    let provider = MockSupportProvider(id: .jake)
    try coordinator.register(provider)
    try coordinator.selectProvider(.jake)
    try await coordinator.startSession(Self.session)

    provider.emit(.authenticationExpired)

    XCTAssertNil(coordinator.activeProviderID)
    XCTAssertNil(coordinator.activeSession)
  }

  private static let session = SupportSession(
    user: SupportUser(id: "customer-1"),
    credentials: [.jake: SupportCredential(token: "token")]
  )
}

private enum TestError: Error, Equatable {
  case rejected
}

@MainActor
private final class MockSupportProvider: SupportProvider {
  let id: SupportProviderID
  let displayName: String
  let capabilities: Set<SupportCapability>
  weak var delegate: (any SupportProviderDelegate)?

  var authenticateCount = 0
  var dismissCount = 0
  var logoutCount = 0
  var receivedHandoff: SupportHandoffContext?
  var handoffError: (any Error)?

  init(
    id: SupportProviderID,
    capabilities: Set<SupportCapability> = [.messenger]
  ) {
    self.id = id
    displayName = id.rawValue
    self.capabilities = capabilities
  }

  func authenticate(_: SupportSession) async throws {
    authenticateCount += 1
  }

  func present() async throws {}

  func dismiss() async {
    dismissCount += 1
  }

  func logout() async {
    logoutCount += 1
  }

  func receiveHandoff(_ context: SupportHandoffContext) async throws {
    if let handoffError { throw handoffError }
    receivedHandoff = context
  }

  func emit(_ event: SupportProviderEvent) {
    delegate?.supportProvider(self, didEmit: event)
  }
}
