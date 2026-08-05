import Foundation

#if canImport(UIKit)
  import UIKit
#endif

@MainActor
final class JakeClient {
  weak var delegate: (any JakeDelegate)?
  private(set) var unreadCount = 0

  private let tokenStore: JakeTokenStore
  private var configuration: JakeConfiguration?
  private var session: JakeSession?

  #if canImport(UIKit)
    private let nativePresenter = JakeNativePresenter()
  #endif

  init(tokenStore: JakeTokenStore = JakeTokenStore()) {
    self.tokenStore = tokenStore
  }

  func configure(_ configuration: JakeConfiguration) {
    do {
      try configuration.validate()
      #if canImport(UIKit)
        nativePresenter.reset()
      #endif
      self.configuration = configuration
      session = tokenStore.load(workspaceId: configuration.workspaceId)
      updateUnreadCount(0)
    } catch let error as JakeError {
      self.configuration = nil
      session = nil
      report(error)
    } catch {
      self.configuration = nil
      session = nil
      report(.invalidConfiguration(error.localizedDescription))
    }
  }

  func authenticate(userId: String, token: String) throws {
    guard let configuration else { throw JakeError.notConfigured }
    try configuration.validate()

    let normalizedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedUserId.isEmpty else {
      throw JakeError.invalidAuthentication("Jake userId cannot be empty.")
    }
    guard !normalizedToken.isEmpty else {
      throw JakeError.invalidAuthentication("Jake user token cannot be empty.")
    }

    let session = JakeSession(
      userId: normalizedUserId,
      token: normalizedToken,
      authenticatedAt: Date()
    )
    try tokenStore.save(session, workspaceId: configuration.workspaceId)
    #if canImport(UIKit)
      nativePresenter.reset()
    #endif
    self.session = session
  }

  func logout() {
    #if canImport(UIKit)
      nativePresenter.reset()
    #endif

    if let configuration {
      tokenStore.clear(workspaceId: configuration.workspaceId)
    }
    session = nil
    updateUnreadCount(0)
  }

  func track(_ event: String, properties: [String: JakeValue]) {
    guard session != nil else {
      report(.authenticationRequired)
      return
    }
    let normalizedEvent = event.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedEvent.isEmpty else { return }
    #if canImport(UIKit)
      nativePresenter.send(.track(name: normalizedEvent, properties: properties))
    #endif
  }

  func setUserAttributes(_ attributes: [String: JakeValue]) {
    guard session != nil else {
      report(.authenticationRequired)
      return
    }
    #if canImport(UIKit)
      nativePresenter.send(.setUserAttributes(attributes))
    #endif
  }

  func setPushToken(_ token: String) {
    guard session != nil else {
      report(.authenticationRequired)
      return
    }
    guard !token.isEmpty else { return }
    #if canImport(UIKit)
      nativePresenter.send(.setPushToken(token))
    #endif
  }

  #if canImport(UIKit)
    func present(from viewController: UIViewController? = nil) {
      do {
        try presentThrowing(from: viewController)
      } catch let error as JakeError {
        report(error)
      } catch {
        report(.messengerLoadFailed(error.localizedDescription))
      }
    }

    func presentThrowing(from viewController: UIViewController? = nil) throws {
      guard let configuration else { throw JakeError.notConfigured }
      guard let session else { throw JakeError.authenticationRequired }
      try nativePresenter.present(
        configuration: configuration,
        session: session,
        from: viewController,
        onAuthenticationExpired: { [weak self] in self?.handleAuthenticationExpired() },
        onError: { [weak self] error in self?.report(error) }
      )
    }

    func dismiss() {
      nativePresenter.dismiss()
    }

    private func handleAuthenticationExpired() {
      if let configuration {
        tokenStore.clear(workspaceId: configuration.workspaceId)
      }
      session = nil
      dismiss()
      report(.authenticationExpired)
      delegate?.jakeAuthenticationDidExpire()
      NotificationCenter.default.post(name: .jakeAuthenticationDidExpire, object: nil)
    }
  #endif

  private func updateUnreadCount(_ count: Int) {
    let normalized = max(0, count)
    guard unreadCount != normalized else { return }
    unreadCount = normalized
    delegate?.jakeDidUpdateUnreadCount(normalized)
    NotificationCenter.default.post(
      name: .jakeUnreadCountDidChange,
      object: nil,
      userInfo: [JakeNotificationUserInfoKey.unreadCount: normalized]
    )
  }

  private func report(_ error: JakeError) {
    delegate?.jakeDidFail(with: error)
  }
}
