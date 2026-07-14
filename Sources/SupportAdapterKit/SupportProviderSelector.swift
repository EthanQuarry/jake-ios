import Foundation

@MainActor
public protocol SupportProviderSelecting: AnyObject {
  func selectProvider(for context: SupportRoutingContext) async throws -> SupportProviderSelection
}

@MainActor
public final class StaticSupportProviderSelector: SupportProviderSelecting {
  public var selection: SupportProviderSelection

  public init(provider: SupportProviderID, reason: String? = nil) {
    selection = SupportProviderSelection(provider: provider, reason: reason)
  }

  public func selectProvider(for _: SupportRoutingContext) async throws -> SupportProviderSelection {
    selection
  }
}

@MainActor
public final class HTTPProviderSelector: SupportProviderSelecting {
  private let endpoint: URL
  private let headers: [String: String]
  private let session: URLSession
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  public init(
    endpoint: URL,
    headers: [String: String] = [:],
    session: URLSession = .shared
  ) {
    self.endpoint = endpoint
    self.headers = headers
    self.session = session
    encoder = JSONEncoder()
    decoder = JSONDecoder()
  }

  public func selectProvider(
    for context: SupportRoutingContext
  ) async throws -> SupportProviderSelection {
    guard endpoint.scheme?.lowercased() == "https" || endpoint.isLoopbackHTTP else {
      throw SupportAdapterError.invalidSelectionResponse(
        "the endpoint must use HTTPS outside local development"
      )
    }
    guard endpoint.user == nil, endpoint.password == nil else {
      throw SupportAdapterError.invalidSelectionResponse(
        "credentials must be supplied in headers, not embedded in the URL"
      )
    }

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
    request.httpBody = try encoder.encode(context)

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw SupportAdapterError.invalidSelectionResponse("the server did not return HTTP")
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      throw SupportAdapterError.selectionRequestFailed(statusCode: httpResponse.statusCode)
    }
    guard data.count <= 1_048_576 else {
      throw SupportAdapterError.invalidSelectionResponse("the response exceeds 1 MB")
    }

    let selection = try decoder.decode(SupportProviderSelection.self, from: data)
    guard !selection.provider.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw SupportAdapterError.invalidSelectionResponse("provider is empty")
    }
    if let ttlSeconds = selection.ttlSeconds, ttlSeconds < 0 {
      throw SupportAdapterError.invalidSelectionResponse("ttlSeconds cannot be negative")
    }
    return selection
  }
}

extension URL {
  fileprivate var isLoopbackHTTP: Bool {
    guard scheme?.lowercased() == "http" else { return false }
    return ["localhost", "127.0.0.1", "::1"].contains(host?.lowercased() ?? "")
  }
}
