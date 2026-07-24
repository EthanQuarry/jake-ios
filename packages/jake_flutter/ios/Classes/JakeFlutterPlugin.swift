import Flutter
import JakeSDK
import UIKit

@MainActor
public final class JakeFlutterPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, JakeDelegate {
  private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = JakeFlutterPlugin()
    let methods = FlutterMethodChannel(
      name: "ai.tryjake.sdk/methods",
      binaryMessenger: registrar.messenger()
    )
    let events = FlutterEventChannel(
      name: "ai.tryjake.sdk/events",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: methods)
    events.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "configure":
        try configure(call.arguments)
        result(nil)
      case "authenticate":
        guard
          let arguments = call.arguments as? [String: Any],
          let userId = arguments["userId"] as? String,
          let token = arguments["token"] as? String
        else {
          throw BridgeError("invalid_authentication", "userId and token are required.")
        }
        Task { @MainActor in
          do {
            try await Jake.authenticate(userId: userId, token: token)
            result(nil)
          } catch {
            result(flutterError(error))
          }
        }
      case "present":
        try Jake.presentMessenger()
        result(nil)
      case "dismiss":
        Jake.dismiss()
        result(nil)
      case "logout":
        Jake.logout()
        result(nil)
      case "track":
        guard
          let arguments = call.arguments as? [String: Any],
          let event = arguments["event"] as? String
        else {
          throw BridgeError("invalid_event", "event is required.")
        }
        Jake.track(
          event,
          properties: try values(arguments["properties"] as? [String: Any] ?? [:])
        )
        result(nil)
      case "setUserAttributes":
        Jake.setUserAttributes(try values(call.arguments as? [String: Any] ?? [:]))
        result(nil)
      case "setPushToken":
        guard
          let token = call.arguments as? String,
          let data = Data(hex: token)
        else {
          throw BridgeError(
            "invalid_push_token",
            "The APNs token must be a hexadecimal string."
          )
        }
        Jake.setPushToken(data)
        result(nil)
      case "getUnreadCount":
        result(Jake.unreadCount)
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      result(flutterError(error))
    }
  }

  public func onListen(
    withArguments _: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    Jake.delegate = self
    return nil
  }

  public func onCancel(withArguments _: Any?) -> FlutterError? {
    eventSink = nil
    Jake.delegate = nil
    return nil
  }

  public func jakeDidUpdateUnreadCount(_ count: Int) {
    eventSink?(["type": "unreadCountChanged", "count": count])
  }

  public func jakeAuthenticationDidExpire() {
    eventSink?(["type": "authenticationExpired"])
  }

  public func jakeDidFail(with error: JakeError) {
    eventSink?([
      "type": "error",
      "code": error.bridgeCode,
      "message": error.localizedDescription,
    ])
  }

  private func configure(_ rawArguments: Any?) throws {
    guard
      let arguments = rawArguments as? [String: Any],
      let workspaceId = arguments["workspaceId"] as? String,
      !workspaceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let publicKey = arguments["publicKey"] as? String,
      !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      throw BridgeError(
        "invalid_configuration",
        "workspaceId and publicKey are required."
      )
    }
    let messengerURL: URL
    if let value = arguments["messengerUrl"] as? String {
      guard
        let parsed = URL(string: value),
        let scheme = parsed.scheme?.lowercased(),
        ["http", "https"].contains(scheme)
      else {
        throw BridgeError(
          "invalid_configuration",
          "messengerUrl must use HTTP or HTTPS."
        )
      }
      messengerURL = parsed
    } else {
      messengerURL = JakeConfiguration.hostedMessengerURL
    }
    try Jake.configureMessenger(
      workspaceId: workspaceId,
      publicKey: publicKey,
      messengerURL: messengerURL
    )
  }

  private func values(_ dictionary: [String: Any]) throws -> [String: JakeValue] {
    try dictionary.mapValues { try JakeValue(bridgeValue: $0) }
  }

  private func flutterError(_ error: Error) -> FlutterError {
    if let bridge = error as? BridgeError {
      return FlutterError(code: bridge.code, message: bridge.message, details: nil)
    }
    let jake = error as? JakeError
    return FlutterError(
      code: jake?.bridgeCode ?? "jake_error",
      message: error.localizedDescription,
      details: nil
    )
  }
}

private struct BridgeError: LocalizedError {
  let code: String
  let message: String

  init(_ code: String, _ message: String) {
    self.code = code
    self.message = message
  }

  var errorDescription: String? { message }
}

private extension JakeError {
  var bridgeCode: String {
    switch self {
    case .notConfigured: "not_configured"
    case .invalidConfiguration: "invalid_configuration"
    case .invalidAuthentication: "invalid_authentication"
    case .authenticationRequired: "authentication_required"
    case .tokenStorageFailed: "token_storage_failed"
    case .presentationUnavailable: "presentation_unavailable"
    case .messengerLoadFailed: "messenger_load_failed"
    }
  }
}

private extension JakeValue {
  init(bridgeValue value: Any) throws {
    switch value {
    case is NSNull: self = .null
    case let value as Bool: self = .boolean(value)
    case let value as NSNumber:
      let double = value.doubleValue
      self = double.rounded() == double ? .integer(value.intValue) : .double(double)
    case let value as String: self = .string(value)
    default:
      throw BridgeError(
        "invalid_value",
        "Properties must be strings, numbers, booleans, or null."
      )
    }
  }
}

private extension Data {
  init?(hex: String) {
    let normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    guard normalized.count.isMultiple(of: 2) else { return nil }
    var data = Data()
    var index = normalized.startIndex
    while index < normalized.endIndex {
      let next = normalized.index(index, offsetBy: 2)
      guard let byte = UInt8(normalized[index..<next], radix: 16) else { return nil }
      data.append(byte)
      index = next
    }
    self = data
  }
}
