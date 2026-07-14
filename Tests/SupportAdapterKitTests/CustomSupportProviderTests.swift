import XCTest

@testable import SupportAdapterKit

@MainActor
final class CustomSupportProviderTests: XCTestCase {
  func testClosureBackedProviderAdaptsAnInternalMessenger() async throws {
    var authenticatedUserID: String?
    var presentationCount = 0
    let provider = CustomSupportProvider(
      id: .internalAgent,
      displayName: "Company support",
      handlers: CustomSupportProviderHandlers(
        authenticate: { session in authenticatedUserID = session.user.id },
        present: { presentationCount += 1 }
      )
    )

    try await provider.authenticate(
      SupportSession(user: SupportUser(id: "customer-42"))
    )
    try await provider.present()

    XCTAssertEqual(authenticatedUserID, "customer-42")
    XCTAssertEqual(presentationCount, 1)
  }
}
