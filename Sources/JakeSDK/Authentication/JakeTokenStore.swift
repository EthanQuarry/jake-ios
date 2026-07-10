import Foundation
import Security

struct JakeTokenStore: Sendable {
  private let service = "ai.tryjake.JakeSDK.session"

  func save(_ session: JakeSession, workspaceId: String) throws {
    let data = try JSONEncoder().encode(session)
    let baseQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: workspaceId,
    ]

    SecItemDelete(baseQuery as CFDictionary)

    var addQuery = baseQuery
    addQuery[kSecValueData as String] = data
    addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    guard SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess else {
      throw JakeError.tokenStorageFailed
    }
  }

  func load(workspaceId: String) -> JakeSession? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: workspaceId,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else {
      return nil
    }
    return try? JSONDecoder().decode(JakeSession.self, from: data)
  }

  func clear(workspaceId: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: workspaceId,
    ]
    SecItemDelete(query as CFDictionary)
  }
}
