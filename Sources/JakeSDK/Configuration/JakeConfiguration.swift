import Foundation

public struct JakeConfiguration: Equatable, Sendable {
  public static let hostedMessengerURL = URL(string: "https://widget.tryjake.ai/messenger")!

  public let workspaceId: String
  public let publicKey: String
  public let messengerURL: URL

  public init(
    workspaceId: String,
    publicKey: String,
    messengerURL: URL = Self.hostedMessengerURL
  ) {
    self.workspaceId = workspaceId.trimmingCharacters(in: .whitespacesAndNewlines)
    self.publicKey = publicKey.trimmingCharacters(in: .whitespacesAndNewlines)
    self.messengerURL = messengerURL
  }

  func validate() throws {
    guard !workspaceId.isEmpty else {
      throw JakeError.invalidConfiguration("Jake workspaceId cannot be empty.")
    }
    guard !publicKey.isEmpty else {
      throw JakeError.invalidConfiguration("Jake publicKey cannot be empty.")
    }
    guard let scheme = messengerURL.scheme?.lowercased(), ["https", "http"].contains(scheme) else {
      throw JakeError.invalidConfiguration("Jake messengerURL must use HTTP or HTTPS.")
    }
    #if !DEBUG
      guard messengerURL.scheme?.lowercased() == "https" else {
        throw JakeError.invalidConfiguration("Jake messengerURL must use HTTPS in release builds.")
      }
    #endif
  }
}
