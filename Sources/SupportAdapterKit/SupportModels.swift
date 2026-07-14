import Foundation

public struct SupportProviderID: RawRepresentable, Codable, Hashable, Sendable,
  ExpressibleByStringLiteral, CustomStringConvertible
{
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  public init(stringLiteral value: String) {
    self.init(rawValue: value)
  }

  public var description: String { rawValue }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    rawValue = try container.decode(String.self)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

extension SupportProviderID {
  public static let jake: Self = "jake"
  public static let intercom: Self = "intercom"
  public static let internalAgent: Self = "internal"
}

public enum SupportCapability: String, Codable, CaseIterable, Hashable, Sendable {
  case messenger
  case unreadCount
  case eventTracking
  case userAttributes
  case pushNotifications
  case handoffContext
}

public enum SupportValue: Codable, Equatable, Sendable {
  case string(String)
  case integer(Int)
  case double(Double)
  case boolean(Bool)
  case null

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .boolean(value)
    } else if let value = try? container.decode(Int.self) {
      self = .integer(value)
    } else if let value = try? container.decode(Double.self) {
      self = .double(value)
    } else {
      self = .string(try container.decode(String.self))
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let value): try container.encode(value)
    case .integer(let value): try container.encode(value)
    case .double(let value): try container.encode(value)
    case .boolean(let value): try container.encode(value)
    case .null: try container.encodeNil()
    }
  }
}

public struct SupportUser: Codable, Equatable, Sendable {
  public let id: String
  public let email: String?
  public let name: String?
  public let attributes: [String: SupportValue]

  public init(
    id: String,
    email: String? = nil,
    name: String? = nil,
    attributes: [String: SupportValue] = [:]
  ) {
    self.id = id
    self.email = email
    self.name = name
    self.attributes = attributes
  }
}

public struct SupportCredential: Codable, Equatable, Sendable {
  public let token: String?
  public let metadata: [String: SupportValue]

  public init(token: String? = nil, metadata: [String: SupportValue] = [:]) {
    self.token = token
    self.metadata = metadata
  }
}

public struct SupportSession: Codable, Equatable, Sendable {
  public let user: SupportUser
  public let credentials: [String: SupportCredential]

  public init(
    user: SupportUser,
    credentials: [SupportProviderID: SupportCredential] = [:]
  ) {
    self.user = user
    self.credentials = Dictionary(
      uniqueKeysWithValues: credentials.map { ($0.key.rawValue, $0.value) }
    )
  }

  public init(user: SupportUser, rawCredentials: [String: SupportCredential]) {
    self.user = user
    self.credentials = rawCredentials
  }

  public func credential(for providerID: SupportProviderID) -> SupportCredential? {
    credentials[providerID.rawValue]
  }
}

public struct SupportHandoffContext: Codable, Equatable, Sendable {
  public let reason: String
  public let externalConversationID: String?
  public let transcriptSummary: String?
  public let metadata: [String: SupportValue]

  public init(
    reason: String,
    externalConversationID: String? = nil,
    transcriptSummary: String? = nil,
    metadata: [String: SupportValue] = [:]
  ) {
    self.reason = reason
    self.externalConversationID = externalConversationID
    self.transcriptSummary = transcriptSummary
    self.metadata = metadata
  }
}

public struct SupportHandoffResult: Equatable, Sendable {
  public let sourceProviderID: SupportProviderID
  public let targetProviderID: SupportProviderID
  public let contextTransferred: Bool

  public init(
    sourceProviderID: SupportProviderID,
    targetProviderID: SupportProviderID,
    contextTransferred: Bool
  ) {
    self.sourceProviderID = sourceProviderID
    self.targetProviderID = targetProviderID
    self.contextTransferred = contextTransferred
  }
}

public struct SupportRoutingContext: Codable, Equatable, Sendable {
  public let userID: String
  public let locale: String?
  public let appVersion: String?
  public let attributes: [String: SupportValue]

  public init(
    userID: String,
    locale: String? = nil,
    appVersion: String? = nil,
    attributes: [String: SupportValue] = [:]
  ) {
    self.userID = userID
    self.locale = locale
    self.appVersion = appVersion
    self.attributes = attributes
  }
}

public struct SupportProviderSelection: Codable, Equatable, Sendable {
  public let provider: SupportProviderID
  public let reason: String?
  public let ttlSeconds: Int?

  public init(provider: SupportProviderID, reason: String? = nil, ttlSeconds: Int? = nil) {
    self.provider = provider
    self.reason = reason
    self.ttlSeconds = ttlSeconds
  }
}
