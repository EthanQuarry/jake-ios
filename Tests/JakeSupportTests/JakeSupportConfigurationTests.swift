import XCTest

@testable import JakeSupport

@MainActor
final class JakeSupportConfigurationTests: XCTestCase {
  func testConfigurationTrimsValues() throws {
    let configuration = try JakeSupportRuntimeConfiguration(
      workspaceId: " workspace ",
      publicKey: " public-key ",
      intercom: JakeSupportIntercomConfiguration(apiKey: " api-key ", appId: " app-id "),
      selectionEndpoint: URL(string: "https://app.tryjake.ai/v1/sdk/provider-selection")!,
      messengerURL: URL(string: "https://widget.tryjake.ai/messenger")!
    )

    XCTAssertEqual(configuration.workspaceId, "workspace")
    XCTAssertEqual(configuration.publicKey, "public-key")
    XCTAssertEqual(configuration.intercom.apiKey, "api-key")
    XCTAssertEqual(configuration.intercom.appId, "app-id")
  }

  func testConfigurationRejectsInsecureRemoteEndpoints() {
    XCTAssertThrowsError(
      try JakeSupportRuntimeConfiguration(
        workspaceId: "workspace",
        publicKey: "public-key",
        intercom: JakeSupportIntercomConfiguration(apiKey: "api-key", appId: "app-id"),
        selectionEndpoint: URL(string: "http://example.com/v1/sdk/provider-selection")!,
        messengerURL: URL(string: "https://widget.tryjake.ai/messenger")!
      )
    ) { error in
      XCTAssertEqual(
        error as? JakeSupportError,
        .invalidConfiguration(
          "The selection endpoint must use HTTPS outside local development."
        )
      )
    }
  }

  func testConfigurationAllowsLoopbackHTTP() throws {
    XCTAssertNoThrow(
      try JakeSupportRuntimeConfiguration(
        workspaceId: "workspace",
        publicKey: "public-key",
        intercom: JakeSupportIntercomConfiguration(apiKey: "api-key", appId: "app-id"),
        selectionEndpoint: URL(string: "http://127.0.0.1:3000/v1/sdk/provider-selection")!,
        messengerURL: URL(string: "http://localhost:3001/messenger")!
      )
    )
  }

  func testLoginRequiresTheSecureIntercomFallbackCredential() async {
    do {
      try await JakeSupport.login(
        user: JakeSupportUser(id: "customer-1"),
        tokens: JakeSupportTokens(jake: "jake-token", intercom: "   ")
      )
      XCTFail("Expected an empty Intercom JWT to be rejected")
    } catch {
      XCTAssertEqual(
        error as? JakeSupportError,
        .invalidConfiguration("The Intercom user JWT cannot be empty.")
      )
    }
  }
}
