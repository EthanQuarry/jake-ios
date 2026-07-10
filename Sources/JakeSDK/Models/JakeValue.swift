import Foundation

public enum JakeValue: Codable, Equatable, Sendable {
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

extension JakeValue {
  var foundationValue: Any {
    switch self {
    case .string(let value): value
    case .integer(let value): value
    case .double(let value): value
    case .boolean(let value): value
    case .null: NSNull()
    }
  }
}
