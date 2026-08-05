import XCTest

@testable import JakeSDK

final class JakeConfigurationTests: XCTestCase {
  func testUsesTheProductionConversationAPIByDefault() {
    XCTAssertEqual(
      JakeConfiguration.hostedConversationAPIURL.absoluteString,
      "https://app.tryjake.ai"
    )
  }

  func testTrimsIdentifiers() throws {
    let configuration = JakeConfiguration(
      workspaceId: "  workspace_123 ",
      publicKey: " pk_live_123\n"
    )

    XCTAssertEqual(configuration.workspaceId, "workspace_123")
    XCTAssertEqual(configuration.publicKey, "pk_live_123")
    XCTAssertNoThrow(try configuration.validate())
  }

  func testRejectsEmptyIdentifiers() {
    let configuration = JakeConfiguration(workspaceId: " ", publicKey: "pk_live_123")
    XCTAssertThrowsError(try configuration.validate())
  }
}
