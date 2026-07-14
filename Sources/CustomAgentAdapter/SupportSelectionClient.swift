import Foundation
import SupportKitCore

public struct SupportExperienceSelection: Codable, Equatable, Sendable {
  public let channel: SupportChannelID
  public let agentProvider: String
  public let humanHandoffAdapter: String?
  public let reason: String
  public let ttlSeconds: Int
}

public struct SupportSelectionContext: Codable, Equatable, Sendable {
  public let userID: String
  public let locale: String?
  public let appVersion: String?

  public init(userID: String, locale: String? = nil, appVersion: String? = nil) {
    self.userID = userID
    self.locale = locale
    self.appVersion = appVersion
  }
}

public final class SupportSelectionClient: Sendable {
  private let endpoint: URL
  private let publicKey: String
  private let session: URLSession

  public init(baseURL: URL, publicKey: String, session: URLSession = .shared) throws {
    let loopback = ["localhost", "127.0.0.1", "::1"].contains(baseURL.host?.lowercased() ?? "")
    guard baseURL.scheme == "https" || (baseURL.scheme == "http" && loopback) else {
      throw SupportChannelError.invalidServerResponse(
        "selection URL must use HTTPS outside local development"
      )
    }
    guard baseURL.user == nil, baseURL.password == nil else {
      throw SupportChannelError.invalidServerResponse(
        "credentials cannot be embedded in the selection URL"
      )
    }
    self.endpoint = URL(string: "/v1/sdk/support-selection", relativeTo: baseURL)!.absoluteURL
    self.publicKey = publicKey
    self.session = session
  }

  public func select(
    token: String,
    context: SupportSelectionContext
  ) async throws -> SupportExperienceSelection {
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue(publicKey, forHTTPHeaderField: "X-Jake-Public-Key")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(context)
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw SupportChannelError.invalidServerResponse("selection server did not return HTTP")
    }
    guard (200...299).contains(http.statusCode) else {
      throw SupportChannelError.requestFailed(statusCode: http.statusCode)
    }
    let result = try JSONDecoder().decode(SupportExperienceSelection.self, from: data)
    guard result.ttlSeconds >= 0, !result.agentProvider.isEmpty else {
      throw SupportChannelError.invalidServerResponse("selection has invalid provider or TTL")
    }
    return result
  }
}
