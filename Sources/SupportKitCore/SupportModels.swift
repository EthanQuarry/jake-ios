import Foundation

public struct SupportChannelID: RawRepresentable, Codable, Hashable, Sendable,
  ExpressibleByStringLiteral
{
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public init(stringLiteral value: String) { rawValue = value }

  public init(from decoder: any Decoder) throws {
    rawValue = try decoder.singleValueContainer().decode(String.self)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

extension SupportChannelID {
  public static let native: Self = "supportkit-native"
  public static let jakeMessenger: Self = "jake-messenger"
  public static let intercomMessenger: Self = "intercom-messenger"
}

public enum SupportJSONValue: Codable, Equatable, Sendable {
  case string(String)
  case integer(Int)
  case double(Double)
  case boolean(Bool)
  case array([SupportJSONValue])
  case object([String: SupportJSONValue])
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
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([SupportJSONValue].self) {
      self = .array(value)
    } else {
      self = .object(try container.decode([String: SupportJSONValue].self))
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let value): try container.encode(value)
    case .integer(let value): try container.encode(value)
    case .double(let value): try container.encode(value)
    case .boolean(let value): try container.encode(value)
    case .array(let value): try container.encode(value)
    case .object(let value): try container.encode(value)
    case .null: try container.encodeNil()
    }
  }
}

public struct SupportCustomer: Codable, Equatable, Sendable {
  public let tenantID: String?
  public let applicationID: String?
  public let id: String
  public let externalID: String
  public let name: String?
  public let email: String?
  public let attributes: [String: SupportJSONValue]

  public init(
    id: String,
    externalID: String,
    tenantID: String? = nil,
    applicationID: String? = nil,
    name: String? = nil,
    email: String? = nil,
    attributes: [String: SupportJSONValue] = [:]
  ) {
    self.tenantID = tenantID
    self.applicationID = applicationID
    self.id = id
    self.externalID = externalID
    self.name = name
    self.email = email
    self.attributes = attributes
  }
}

public struct SupportChannelSession: Codable, Equatable, Sendable {
  public let customer: SupportCustomer
  public let credentials: [String: String]
  public let metadata: [String: SupportJSONValue]

  public init(
    customer: SupportCustomer,
    credentials: [SupportChannelID: String] = [:],
    metadata: [String: SupportJSONValue] = [:]
  ) {
    self.customer = customer
    self.credentials = Dictionary(
      uniqueKeysWithValues: credentials.map { ($0.key.rawValue, $0.value) })
    self.metadata = metadata
  }

  public func credential(for channelID: SupportChannelID) -> String? {
    credentials[channelID.rawValue]
  }
}

public struct SupportAttachment: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let type: String
  public let name: String?
  public let contentType: String?
  public let sizeBytes: Int?
  public let url: URL?

  public init(
    id: String = UUID().uuidString,
    type: String,
    name: String? = nil,
    contentType: String? = nil,
    sizeBytes: Int? = nil,
    url: URL? = nil
  ) {
    self.id = id
    self.type = type
    self.name = name
    self.contentType = contentType
    self.sizeBytes = sizeBytes
    self.url = url
  }
}

public struct SupportMessage: Codable, Equatable, Identifiable, Sendable {
  public enum Role: String, Codable, Sendable { case customer, agent, human, system, tool }
  public let id: String
  public let conversationID: String
  public let role: Role
  public let body: String
  public let format: String
  public let attachments: [SupportAttachment]
  public let createdAt: Date
  public let metadata: [String: SupportJSONValue]

  public init(
    id: String,
    conversationID: String,
    role: Role,
    body: String,
    format: String = "plain",
    attachments: [SupportAttachment] = [],
    createdAt: Date,
    metadata: [String: SupportJSONValue] = [:]
  ) {
    self.id = id
    self.conversationID = conversationID
    self.role = role
    self.body = body
    self.format = format
    self.attachments = attachments
    self.createdAt = createdAt
    self.metadata = metadata
  }
}

public struct OutgoingSupportMessage: Equatable, Sendable {
  public let clientMessageID: String
  public let body: String
  public let attachments: [SupportAttachment]
  public let metadata: [String: SupportJSONValue]

  public init(
    clientMessageID: String = UUID().uuidString,
    body: String,
    attachments: [SupportAttachment] = [],
    metadata: [String: SupportJSONValue] = [:]
  ) {
    self.clientMessageID = clientMessageID
    self.body = body
    self.attachments = attachments
    self.metadata = metadata
  }
}

public struct SupportCitation: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let title: String
  public let url: URL?
  public let excerpt: String?

  public init(id: String, title: String, url: URL? = nil, excerpt: String? = nil) {
    self.id = id
    self.title = title
    self.url = url
    self.excerpt = excerpt
  }
}

public struct SupportActionRequest: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let approvalRequired: Bool

  public init(id: String, name: String, approvalRequired: Bool) {
    self.id = id
    self.name = name
    self.approvalRequired = approvalRequired
  }
}
