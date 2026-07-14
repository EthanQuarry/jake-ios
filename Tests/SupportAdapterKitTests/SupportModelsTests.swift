import Foundation
import XCTest

@testable import SupportAdapterKit

final class SupportModelsTests: XCTestCase {
  func testProviderSelectionUsesPortableJSONShape() throws {
    let selection = SupportProviderSelection(
      provider: .jake,
      reason: "workspace default",
      ttlSeconds: 300
    )

    let data = try JSONEncoder().encode(selection)
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

    XCTAssertEqual(json["provider"] as? String, "jake")
    XCTAssertEqual(try JSONDecoder().decode(SupportProviderSelection.self, from: data), selection)
  }

  func testProviderSpecificCredentialsRoundTrip() throws {
    let session = SupportSession(
      user: SupportUser(id: "customer-1", email: "customer@example.com"),
      credentials: [
        .jake: SupportCredential(token: "jake-token"),
        .intercom: SupportCredential(token: "intercom-jwt"),
      ]
    )

    let data = try JSONEncoder().encode(session)
    let decoded = try JSONDecoder().decode(SupportSession.self, from: data)

    XCTAssertEqual(decoded, session)
    XCTAssertEqual(decoded.credential(for: .jake)?.token, "jake-token")
    XCTAssertEqual(decoded.credential(for: .intercom)?.token, "intercom-jwt")
  }
}
