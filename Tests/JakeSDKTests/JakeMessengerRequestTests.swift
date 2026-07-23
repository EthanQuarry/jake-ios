import Foundation
import XCTest

@testable import JakeSDK

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

final class JakeMessengerRequestTests: XCTestCase {
  func testBuildsSecureRequest() throws {
    let configuration = JakeConfiguration(
      workspaceId: "workspace_123",
      publicKey: "pk_live_123",
      messengerURL: URL(string: "https://messenger.example.test/embed?theme=dark")!
    )
    let session = JakeSession(
      userId: "user_456",
      token: "secret.jwt.token",
      authenticatedAt: .now
    )

    let request = try JakeMessengerRequest.make(configuration: configuration, session: session)
    let url = try XCTUnwrap(request.url)
    let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let query = Dictionary(
      uniqueKeysWithValues: (components.queryItems ?? []).map {
        ($0.name, $0.value)
      })

    XCTAssertEqual(query["theme"], "dark")
    XCTAssertEqual(query["workspace_id"], "workspace_123")
    XCTAssertFalse(query.keys.contains("user_id"))
    XCTAssertEqual(query["platform"], "ios")
    XCTAssertFalse(url.absoluteString.contains("secret.jwt.token"))
    XCTAssertFalse(url.absoluteString.contains("user_456"))
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret.jwt.token")
    XCTAssertEqual(request.value(forHTTPHeaderField: "X-Jake-User-ID"), "user_456")
    XCTAssertEqual(request.value(forHTTPHeaderField: "X-Jake-Public-Key"), "pk_live_123")
  }
}
