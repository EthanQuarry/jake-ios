import Foundation
import XCTest

@testable import JakeSDK

final class JakeValueTests: XCTestCase {
  func testValuesRoundTripThroughJSON() throws {
    let values: [JakeValue] = [
      .string("pro"),
      .integer(42),
      .double(4.2),
      .boolean(true),
      .null,
    ]

    for value in values {
      let data = try JSONEncoder().encode(value)
      XCTAssertEqual(try JSONDecoder().decode(JakeValue.self, from: data), value)
    }
  }
}
