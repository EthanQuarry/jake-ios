import Foundation
import JakeSDK
import SupportAdapterKit

#if canImport(UIKit)
  import IntercomSupportAdapter
  import UIKit
#endif

public struct JakeSupportIntercomConfiguration: Equatable, Sendable {
  public let apiKey: String
  public let appId: String

  public init(apiKey: String, appId: String) {
    self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    self.appId = appId.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

public struct JakeSupportUser: Equatable, Sendable {
  public let id: String
  public let name: String?

  public init(id: String, name: String? = nil) {
    self.id = id.trimmingCharacters(in: .whitespacesAndNewlines)
    self.name = name?.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

public struct JakeSupportTokens: Equatable, Sendable {
  public let jake: String
  public let intercom: String

  public init(jake: String, intercom: String) {
    self.jake = jake.trimmingCharacters(in: .whitespacesAndNewlines)
    self.intercom = intercom.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

public enum JakeSupportError: LocalizedError, Equatable, Sendable {
  case invalidConfiguration(String)
  case notConfigured
  case unsupportedPlatform

  public var errorDescription: String? {
    switch self {
    case .invalidConfiguration(let message):
      message
    case .notConfigured:
      "Call JakeSupport.configure before logging in or presenting support."
    case .unsupportedPlatform:
      "JakeSupport is available on iOS."
    }
  }
}

@MainActor
public enum JakeSupport {
  public static let defaultSelectionEndpoint = URL(
    string: "https://app.tryjake.ai/v1/sdk/provider-selection"
  )!

  #if canImport(UIKit)
    private static var runtime: JakeSupportRuntime?
  #endif

  public static func configure(
    workspaceId: String,
    publicKey: String,
    intercom: JakeSupportIntercomConfiguration,
    selectionEndpoint: URL = defaultSelectionEndpoint,
    messengerURL: URL = JakeConfiguration.hostedMessengerURL
  ) throws {
    let configuration = try JakeSupportRuntimeConfiguration(
      workspaceId: workspaceId,
      publicKey: publicKey,
      intercom: intercom,
      selectionEndpoint: selectionEndpoint,
      messengerURL: messengerURL
    )

    #if canImport(UIKit)
      runtime = try JakeSupportRuntime(configuration: configuration)
    #else
      _ = configuration
      throw JakeSupportError.unsupportedPlatform
    #endif
  }

  public static func login(
    user: JakeSupportUser,
    tokens: JakeSupportTokens
  ) async throws {
    guard !user.id.isEmpty else {
      throw JakeSupportError.invalidConfiguration("The support user ID cannot be empty.")
    }
    guard !tokens.jake.isEmpty else {
      throw JakeSupportError.invalidConfiguration("The Jake session token cannot be empty.")
    }
    guard !tokens.intercom.isEmpty else {
      throw JakeSupportError.invalidConfiguration("The Intercom user JWT cannot be empty.")
    }

    #if canImport(UIKit)
      guard let runtime else { throw JakeSupportError.notConfigured }
      try await runtime.login(user: user, tokens: tokens)
    #else
      throw JakeSupportError.unsupportedPlatform
    #endif
  }

  public static func present() async throws {
    #if canImport(UIKit)
      guard let runtime else { throw JakeSupportError.notConfigured }
      try await runtime.present()
    #else
      throw JakeSupportError.unsupportedPlatform
    #endif
  }

  public static func dismiss() async {
    #if canImport(UIKit)
      await runtime?.dismiss()
    #endif
  }

  public static func setDeviceToken(_ token: Data) async throws {
    #if canImport(UIKit)
      guard let runtime else { throw JakeSupportError.notConfigured }
      try await runtime.setDeviceToken(token)
    #else
      throw JakeSupportError.unsupportedPlatform
    #endif
  }

  public static func logout() async {
    #if canImport(UIKit)
      await runtime?.logout()
    #endif
  }
}

struct JakeSupportRuntimeConfiguration: Equatable, Sendable {
  let workspaceId: String
  let publicKey: String
  let intercom: JakeSupportIntercomConfiguration
  let selectionEndpoint: URL
  let messengerURL: URL

  init(
    workspaceId: String,
    publicKey: String,
    intercom: JakeSupportIntercomConfiguration,
    selectionEndpoint: URL,
    messengerURL: URL
  ) throws {
    let workspaceId = workspaceId.trimmingCharacters(in: .whitespacesAndNewlines)
    let publicKey = publicKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !workspaceId.isEmpty else {
      throw JakeSupportError.invalidConfiguration("The Jake workspace ID cannot be empty.")
    }
    guard !publicKey.isEmpty else {
      throw JakeSupportError.invalidConfiguration("The Jake public key cannot be empty.")
    }
    guard !intercom.apiKey.isEmpty, !intercom.appId.isEmpty else {
      throw JakeSupportError.invalidConfiguration("The Intercom API key and app ID are required.")
    }
    try Self.requireSecureURL(selectionEndpoint, name: "selection endpoint")
    try Self.requireSecureURL(messengerURL, name: "messenger URL")

    self.workspaceId = workspaceId
    self.publicKey = publicKey
    self.intercom = intercom
    self.selectionEndpoint = selectionEndpoint
    self.messengerURL = messengerURL
  }

  private static func requireSecureURL(_ url: URL, name: String) throws {
    let scheme = url.scheme?.lowercased()
    let isLoopback =
      scheme == "http"
      && ["localhost", "127.0.0.1", "::1"].contains(url.host?.lowercased() ?? "")
    guard scheme == "https" || isLoopback else {
      throw JakeSupportError.invalidConfiguration(
        "The \(name) must use HTTPS outside local development."
      )
    }
    guard url.user == nil, url.password == nil else {
      throw JakeSupportError.invalidConfiguration(
        "The \(name) cannot contain embedded credentials."
      )
    }
  }
}

#if canImport(UIKit)
  @MainActor
  private final class JakeSupportRuntime {
    private let configuration: JakeSupportRuntimeConfiguration
    private let coordinator = SupportCoordinator()

    init(configuration: JakeSupportRuntimeConfiguration) throws {
      self.configuration = configuration
      try coordinator.register(
        JakeSupportProvider(
          configuration: JakeConfiguration(
            workspaceId: configuration.workspaceId,
            publicKey: configuration.publicKey,
            messengerURL: configuration.messengerURL
          )
        )
      )
      try coordinator.register(
        IntercomSupportProvider(
          configuration: IntercomSupportConfiguration(
            apiKey: configuration.intercom.apiKey,
            appID: configuration.intercom.appId
          )
        )
      )
    }

    func login(user: JakeSupportUser, tokens: JakeSupportTokens) async throws {
      await coordinator.endSession()

      let selector = HTTPProviderSelector(
        endpoint: configuration.selectionEndpoint,
        headers: [
          "Authorization": "Bearer \(tokens.jake)",
          "X-Jake-Public-Key": configuration.publicKey,
        ]
      )
      let routingContext = SupportRoutingContext(
        userID: user.id,
        locale: Locale.current.identifier,
        appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
      )

      do {
        _ = try await coordinator.refreshSelection(using: selector, context: routingContext)
      } catch {
        try coordinator.selectProvider(.intercom)
      }

      let credentials: [SupportProviderID: SupportCredential] = [
        .jake: SupportCredential(token: tokens.jake),
        .intercom: SupportCredential(token: tokens.intercom),
      ]

      try await coordinator.startSession(
        SupportSession(
          user: SupportUser(id: user.id, name: user.name),
          credentials: credentials
        )
      )
    }

    func present() async throws {
      try await coordinator.present()
    }

    func dismiss() async {
      try? await coordinator.dismiss()
    }

    func setDeviceToken(_ token: Data) async throws {
      try await coordinator.setPushToken(token)
    }

    func logout() async {
      await coordinator.endSession()
    }
  }
#endif
