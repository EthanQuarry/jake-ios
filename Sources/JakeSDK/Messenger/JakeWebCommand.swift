import Foundation

#if canImport(UIKit)
  import UIKit
#endif

struct JakeWebCommand {
  let name: String
  let payload: [String: Any]

  static func track(name: String, properties: [String: JakeValue]) -> Self {
    .init(
      name: "track",
      payload: [
        "name": name,
        "properties": properties.mapValues(\.foundationValue),
      ]
    )
  }

  static func setUserAttributes(_ attributes: [String: JakeValue]) -> Self {
    .init(
      name: "setUserAttributes", payload: ["attributes": attributes.mapValues(\.foundationValue)])
  }

  static func setPushToken(_ token: String) -> Self {
    .init(name: "setPushToken", payload: ["token": token, "provider": "apns"])
  }

  #if canImport(UIKit)
    @MainActor
    static func deviceContext() -> Self {
      let bundle = Bundle.main
      let device = UIDevice.current
      return .init(
        name: "deviceContext",
        payload: [
          "app": [
            "bundleId": bundle.bundleIdentifier ?? "",
            "version": bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
              ?? "",
            "build": bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
          ],
          "device": [
            "model": device.model,
            "systemName": device.systemName,
            "systemVersion": device.systemVersion,
          ],
          "locale": Locale.current.identifier,
          "timeZone": TimeZone.current.identifier,
        ]
      )
    }
  #endif
}
