import XCTest
import SupportAdapterKit

@testable import JakeSDK

@MainActor
final class JakeSupportProviderTests: XCTestCase {
  func testRequiresProviderSpecificCredential() async {
    let provider = JakeSupportProvider(
      configuration: JakeConfiguration(workspaceId: "workspace", publicKey: "public-key")
    )

    do {
      try await provider.authenticate(
        SupportSession(user: SupportUser(id: "customer"))
      )
      XCTFail("Expected missing credential error")
    } catch {
      XCTAssertEqual(error as? SupportAdapterError, .missingCredential(.jake))
    }
  }

  func testAdvertisesOnlyImplementedCapabilities() {
    let provider = JakeSupportProvider(
      configuration: JakeConfiguration(workspaceId: "workspace", publicKey: "public-key")
    )

    XCTAssertTrue(provider.capabilities.contains(.messenger))
    XCTAssertTrue(provider.capabilities.contains(.eventTracking))
    XCTAssertFalse(provider.capabilities.contains(.handoffContext))
  }
}
