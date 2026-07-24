import Foundation
import JakeSDK
@preconcurrency import React

@objc(JakeSdk)
@MainActor
final class JakeReactNative: RCTEventEmitter, JakeDelegate {
  private var observing = false

  override static func requiresMainQueueSetup() -> Bool { true }

  override func supportedEvents() -> [String]! {
    ["jakeUnreadCountChanged", "jakeAuthenticationExpired", "jakeError"]
  }

  override func startObserving() {
    observing = true
    Jake.delegate = self
  }

  override func stopObserving() {
    observing = false
    Jake.delegate = nil
  }

  @objc
  func configure(
    _ options: NSDictionary,
    resolver resolve: RCTPromiseResolveBlock,
    rejecter reject: RCTPromiseRejectBlock
  ) {
    guard
      let workspaceId = options["workspaceId"] as? String,
      !workspaceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let publicKey = options["publicKey"] as? String,
      !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      reject("invalid_configuration", "workspaceId and publicKey are required.", nil)
      return
    }

    let messengerURL: URL
    if let value = options["messengerUrl"] as? String {
      guard
        let parsed = URL(string: value),
        let scheme = parsed.scheme?.lowercased(),
        ["http", "https"].contains(scheme)
      else {
        reject("invalid_configuration", "messengerUrl must use HTTP or HTTPS.", nil)
        return
      }
      messengerURL = parsed
    } else {
      messengerURL = JakeConfiguration.hostedMessengerURL
    }
    do {
      try Jake.configureMessenger(
        workspaceId: workspaceId,
        publicKey: publicKey,
        messengerURL: messengerURL
      )
      resolve(nil)
    } catch {
      rejectError(error, reject)
    }
  }

  @objc
  func authenticate(
    _ userId: String,
    token: String,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    Task { @MainActor in
      do {
        try await Jake.authenticate(userId: userId, token: token)
        resolve(nil)
      } catch {
        rejectError(error, reject)
      }
    }
  }

  @objc
  func present(
    _ resolve: RCTPromiseResolveBlock,
    rejecter reject: RCTPromiseRejectBlock
  ) {
    do {
      try Jake.presentMessenger()
      resolve(nil)
    } catch {
      rejectError(error, reject)
    }
  }

  @objc
  func dismiss(_ resolve: RCTPromiseResolveBlock, rejecter _: RCTPromiseRejectBlock) {
    Jake.dismiss()
    resolve(nil)
  }

  @objc
  func logout(_ resolve: RCTPromiseResolveBlock, rejecter _: RCTPromiseRejectBlock) {
    Jake.logout()
    resolve(nil)
  }

  @objc
  func track(
    _ event: String,
    properties: NSDictionary,
    resolver resolve: RCTPromiseResolveBlock,
    rejecter reject: RCTPromiseRejectBlock
  ) {
    do {
      Jake.track(event, properties: try values(properties))
      resolve(nil)
    } catch {
      rejectError(error, reject)
    }
  }

  @objc
  func setUserAttributes(
    _ attributes: NSDictionary,
    resolver resolve: RCTPromiseResolveBlock,
    rejecter reject: RCTPromiseRejectBlock
  ) {
    do {
      Jake.setUserAttributes(try values(attributes))
      resolve(nil)
    } catch {
      rejectError(error, reject)
    }
  }

  @objc
  func setPushToken(
    _ token: String,
    resolver resolve: RCTPromiseResolveBlock,
    rejecter reject: RCTPromiseRejectBlock
  ) {
    guard let data = Data(hex: token) else {
      reject("invalid_push_token", "The APNs token must be a hexadecimal string.", nil)
      return
    }
    Jake.setPushToken(data)
    resolve(nil)
  }

  @objc
  func getUnreadCount(
    _ resolve: RCTPromiseResolveBlock,
    rejecter _: RCTPromiseRejectBlock
  ) {
    resolve(Jake.unreadCount)
  }

  func jakeDidUpdateUnreadCount(_ count: Int) {
    emit("jakeUnreadCountChanged", body: ["count": count])
  }

  func jakeAuthenticationDidExpire() {
    emit("jakeAuthenticationExpired", body: [:])
  }

  func jakeDidFail(with error: JakeError) {
    emit(
      "jakeError",
      body: [
        "code": error.bridgeCode,
        "message": error.localizedDescription,
      ])
  }

  private func emit(_ name: String, body: Any) {
    guard observing else { return }
    sendEvent(withName: name, body: body)
  }

  private func values(_ dictionary: NSDictionary) throws -> [String: JakeValue] {
    var result: [String: JakeValue] = [:]
    for (key, value) in dictionary {
      guard let key = key as? String else { continue }
      result[key] = try JakeValue(bridgeValue: value)
    }
    return result
  }

  private func rejectError(_ error: Error, _ reject: RCTPromiseRejectBlock) {
    let jakeError = error as? JakeError
    reject(jakeError?.bridgeCode ?? "jake_error", error.localizedDescription, error)
  }
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
      throw NSError(
        domain: "ai.tryjake.react-native",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Properties must be strings, numbers, booleans, or null."]
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
