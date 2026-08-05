import Foundation

public struct JakeConfiguration: Equatable, Sendable {
  public static let hostedConversationAPIURL = URL(string: "https://app.tryjake.ai")!

  public let workspaceId: String
  public let publicKey: String
  public let conversationAPIURL: URL

  public init(
    workspaceId: String,
    publicKey: String,
    conversationAPIURL: URL = Self.hostedConversationAPIURL
  ) {
    self.workspaceId = workspaceId.trimmingCharacters(in: .whitespacesAndNewlines)
    self.publicKey = publicKey.trimmingCharacters(in: .whitespacesAndNewlines)
    self.conversationAPIURL = conversationAPIURL
  }

  func validate() throws {
    guard !workspaceId.isEmpty else {
      throw JakeError.invalidConfiguration("Jake workspaceId cannot be empty.")
    }
    guard !publicKey.isEmpty else {
      throw JakeError.invalidConfiguration("Jake publicKey cannot be empty.")
    }
    guard let apiScheme = conversationAPIURL.scheme?.lowercased(),
          ["https", "http"].contains(apiScheme) else {
      throw JakeError.invalidConfiguration("Jake conversationAPIURL must use HTTP or HTTPS.")
    }
    #if !DEBUG
      guard conversationAPIURL.scheme?.lowercased() == "https" else {
        throw JakeError.invalidConfiguration(
          "Jake conversationAPIURL must use HTTPS in release builds."
        )
      }
    #endif
  }
}
