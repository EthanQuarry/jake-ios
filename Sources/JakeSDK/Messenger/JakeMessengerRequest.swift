import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

enum JakeMessengerRequest {
  static func make(configuration: JakeConfiguration, session: JakeSession) throws -> URLRequest {
    try configuration.validate()

    guard
      var components = URLComponents(
        url: configuration.messengerURL, resolvingAgainstBaseURL: false)
    else {
      throw JakeError.invalidConfiguration("Jake messengerURL is invalid.")
    }

    var items = components.queryItems ?? []
    items.append(contentsOf: [
      URLQueryItem(name: "workspace_id", value: configuration.workspaceId),
      URLQueryItem(name: "platform", value: "ios"),
      URLQueryItem(name: "sdk_version", value: JakeSDKVersion.current),
    ])
    components.queryItems = items

    guard let url = components.url else {
      throw JakeError.invalidConfiguration("Jake could not construct the Messenger URL.")
    }

    var request = URLRequest(url: url)
    request.cachePolicy = .reloadRevalidatingCacheData
    request.timeoutInterval = 30
    request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
    request.setValue(session.userId, forHTTPHeaderField: "X-Jake-User-ID")
    request.setValue(configuration.publicKey, forHTTPHeaderField: "X-Jake-Public-Key")
    request.setValue(configuration.workspaceId, forHTTPHeaderField: "X-Jake-Workspace-ID")
    request.setValue(JakeSDKVersion.current, forHTTPHeaderField: "X-Jake-SDK-Version")
    return request
  }
}
