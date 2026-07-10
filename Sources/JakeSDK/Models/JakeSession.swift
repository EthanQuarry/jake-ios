import Foundation

struct JakeSession: Codable, Equatable, Sendable {
  let userId: String
  let token: String
  let authenticatedAt: Date
}
