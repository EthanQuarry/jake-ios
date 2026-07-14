import Foundation
import SupportKitCore

public struct SupportRouterConfiguration: Sendable {
  public let baseURL: URL
  public let agentProviderID: String
  public let sessionToken: @MainActor @Sendable () async throws -> String

  public init(
    baseURL: URL,
    agentProviderID: String,
    sessionToken: @escaping @MainActor @Sendable () async throws -> String
  ) {
    self.baseURL = baseURL
    self.agentProviderID = agentProviderID
    self.sessionToken = sessionToken
  }
}

@MainActor
public final class RouterChannelAdapter: SupportChannelAdapter {
  public let id: SupportChannelID
  public let displayName: String
  public let capabilities = SupportChannelCapabilities(
    presentation: .nativeRouterUI,
    programmaticMessaging: true,
    unreadCount: false,
    pushNotifications: false,
    attachments: true,
    externalAgentRouting: true
  )
  public weak var delegate: (any SupportChannelAdapterDelegate)?

  private let configuration: SupportRouterConfiguration
  private let session: URLSession
  private var supportSession: SupportChannelSession?
  private var activeConversationID: String?
  private var partialBodies: [String: String] = [:]

  public init(
    configuration: SupportRouterConfiguration,
    id: SupportChannelID = .native,
    displayName: String = "Support",
    session: URLSession = .shared
  ) {
    self.configuration = configuration
    self.id = id
    self.displayName = displayName
    self.session = session
  }

  public func identify(_ session: SupportChannelSession) async throws {
    try Self.validate(configuration.baseURL)
    _ = try await configuration.sessionToken()
    supportSession = session
  }

  public func present() async throws {
    guard supportSession != nil else { throw SupportChannelError.noActiveSession }
    delegate?.supportChannel(self, didEmit: .presented)
  }

  public func dismiss() async { delegate?.supportChannel(self, didEmit: .dismissed) }

  public func send(_ message: OutgoingSupportMessage, in conversationID: String?) async throws {
    guard supportSession != nil else { throw SupportChannelError.noActiveSession }
    let resolvedConversationID: String
    if let existing = conversationID ?? activeConversationID {
      resolvedConversationID = existing
    } else {
      resolvedConversationID = try await startConversation()
    }
    activeConversationID = resolvedConversationID
    delegate?.supportChannel(self, didEmit: .conversationStarted(resolvedConversationID))

    let body: [String: Any] = [
      "clientMessageId": message.clientMessageID,
      "content": ["body": message.body, "format": "plain"],
      "attachments": message.attachments.map { attachment in
        var value: [String: Any] = ["id": attachment.id, "type": attachment.type]
        if let name = attachment.name { value["name"] = name }
        if let contentType = attachment.contentType { value["contentType"] = contentType }
        if let sizeBytes = attachment.sizeBytes { value["sizeBytes"] = sizeBytes }
        if let url = attachment.url { value["url"] = url.absoluteString }
        return value
      },
    ]
    var request = try await authorizedRequest(
      path: "/v1/router/conversations/\(resolvedConversationID)/turns",
      method: "POST"
    )
    request.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (bytes, response) = try await session.bytes(for: request)
    try Self.requireSuccess(response)
    for try await line in bytes.lines where !line.isEmpty {
      try receive(line: line, conversationID: resolvedConversationID)
    }
  }

  public func requestAgentHandoff(
    to targetProviderID: String,
    conversationID: String,
    currentIntent: String,
    reason: String
  ) async throws {
    var request = try await authorizedRequest(
      path: "/v1/router/conversations/\(conversationID)/agent-handoffs",
      method: "POST"
    )
    request.httpBody = try JSONSerialization.data(
      withJSONObject: [
        "targetProviderId": targetProviderID,
        "currentIntent": currentIntent,
        "reason": reason,
      ]
    )
    let (_, response) = try await session.data(for: request)
    try Self.requireSuccess(response)
  }

  public func logout() async {
    supportSession = nil
    activeConversationID = nil
    partialBodies = [:]
  }

  private func startConversation() async throws -> String {
    guard supportSession != nil else { throw SupportChannelError.noActiveSession }
    var request = try await authorizedRequest(path: "/v1/router/conversations", method: "POST")
    request.httpBody = try JSONEncoder().encode(
      StartRequest(providerId: configuration.agentProviderID)
    )
    let (data, response) = try await session.data(for: request)
    try Self.requireSuccess(response)
    let result = try JSONDecoder().decode(StartResponse.self, from: data)
    guard !result.conversation.id.isEmpty else {
      throw SupportChannelError.invalidServerResponse("conversation ID is empty")
    }
    return result.conversation.id
  }

  private func authorizedRequest(path: String, method: String) async throws -> URLRequest {
    let token = try await configuration.sessionToken()
    guard !token.isEmpty else { throw SupportChannelError.missingCredential(id) }
    var request = URLRequest(url: URL(string: path, relativeTo: configuration.baseURL)!.absoluteURL)
    request.httpMethod = method
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    return request
  }

  private func receive(line: String, conversationID: String) throws {
    guard
      let data = line.data(using: .utf8),
      let value = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let type = value["type"] as? String
    else { throw SupportChannelError.invalidServerResponse("invalid NDJSON event") }
    if type == "response.completed" || type == "response.snapshot" || type == "response.delta" {
      let content = value["content"] as? [String: Any]
      let messageID = value["messageId"] as? String ?? UUID().uuidString
      let body: String
      if type == "response.delta" {
        body = partialBodies[messageID, default: ""] + (value["delta"] as? String ?? "")
        partialBodies[messageID] = body
      } else if type == "response.snapshot" {
        body = value["text"] as? String ?? ""
        partialBodies[messageID] = body
      } else {
        body = (content?["body"] as? String) ?? partialBodies[messageID] ?? ""
        partialBodies[messageID] = nil
      }
      let date = (value["occurredAt"] as? String).flatMap(Self.isoDate) ?? Date()
      let message = SupportMessage(
        id: messageID,
        conversationID: conversationID,
        role: .agent,
        body: body,
        format: content?["format"] as? String ?? "plain",
        createdAt: date
      )
      delegate?.supportChannel(
        self,
        didEmit: type == "response.completed" ? .messageReceived(message) : .messageUpdated(message)
      )
    } else if type == "citation" {
      delegate?.supportChannel(
        self,
        didEmit: .citation(
          SupportCitation(
            id: value["citationId"] as? String ?? UUID().uuidString,
            title: value["title"] as? String ?? "Source",
            url: (value["url"] as? String).flatMap(URL.init(string:)),
            excerpt: value["excerpt"] as? String
          )
        )
      )
    } else if type == "action.requested" {
      delegate?.supportChannel(
        self,
        didEmit: .actionRequested(
          SupportActionRequest(
            id: value["actionId"] as? String ?? UUID().uuidString,
            name: value["name"] as? String ?? "action",
            approvalRequired: value["approvalRequired"] as? Bool ?? true
          )
        )
      )
    } else if type == "clarification.requested" {
      delegate?.supportChannel(
        self,
        didEmit: .clarificationRequested(
          question: value["question"] as? String ?? "Could you clarify?",
          fields: value["fields"] as? [String] ?? []
        )
      )
    } else if type == "handoff.requested" {
      delegate?.supportChannel(
        self,
        didEmit: .handoffRequested(
          reason: value["reason"] as? String ?? "Human help requested",
          targetHint: value["targetHint"] as? String
        )
      )
    } else if type == "error" {
      delegate?.supportChannel(
        self,
        didEmit: .failure(
          code: value["code"] as? String ?? "router_error",
          message: value["message"] as? String ?? "Support router error"
        )
      )
    }
  }

  private static func validate(_ url: URL) throws {
    let loopback = ["localhost", "127.0.0.1", "::1"].contains(url.host?.lowercased() ?? "")
    guard url.scheme == "https" || (url.scheme == "http" && loopback) else {
      throw SupportChannelError.invalidServerResponse(
        "router URL must use HTTPS outside local development")
    }
    guard url.user == nil, url.password == nil else {
      throw SupportChannelError.invalidServerResponse(
        "credentials cannot be embedded in the router URL")
    }
  }

  private static func requireSuccess(_ response: URLResponse) throws {
    guard let http = response as? HTTPURLResponse else {
      throw SupportChannelError.invalidServerResponse("server did not return HTTP")
    }
    guard (200...299).contains(http.statusCode) else {
      throw SupportChannelError.requestFailed(statusCode: http.statusCode)
    }
  }

  private static func isoDate(_ value: String) -> Date? { ISO8601DateFormatter().date(from: value) }
}

private struct StartRequest: Encodable {
  let providerId: String
}

private struct StartResponse: Decodable {
  struct Conversation: Decodable { let id: String }
  let conversation: Conversation
}
