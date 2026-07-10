import Foundation
import XCTest

@testable import JakeSDK

final class JakeWebMessageTests: XCTestCase {
  func testParsesSupportedEvents() {
    XCTAssertEqual(JakeWebMessage(body: ["type": "messengerReady"]), .ready)
    XCTAssertEqual(JakeWebMessage(body: ["type": "closeMessenger"]), .close)
    XCTAssertEqual(
      JakeWebMessage(body: ["type": "unreadCountChanged", "payload": ["count": 7]]),
      .unreadCountChanged(7)
    )
    XCTAssertEqual(
      JakeWebMessage(
        body: ["type": "openExternalURL", "payload": ["url": "https://tryjake.ai"]]
      ),
      .openExternalURL(URL(string: "https://tryjake.ai")!)
    )
  }

  func testRejectsUnsupportedEvents() {
    XCTAssertNil(JakeWebMessage(body: ["payload": 1]))
    XCTAssertNil(JakeWebMessage(body: ["type": "unknown"]))
    XCTAssertNil(JakeWebMessage(body: ["type": "unreadCountChanged", "payload": [:]]))
  }
}
