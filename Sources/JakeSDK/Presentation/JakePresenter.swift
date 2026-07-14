#if canImport(UIKit)
  import UIKit

  @MainActor
  final class JakePresenter {
    private weak var messenger: JakeMessengerViewController?
    private var pendingCommands: [JakeWebCommand] = []

    func present(
      request: URLRequest,
      from source: UIViewController?,
      onMessage: @escaping (JakeWebMessage) -> Void,
      onError: @escaping (JakeError) -> Void
    ) throws {
      guard messenger == nil else { return }

      guard let source = source ?? Self.topViewController() else {
        throw JakeError.presentationUnavailable
      }

      let messenger = JakeMessengerViewController(
        request: request,
        onMessage: onMessage,
        onError: onError
      )
      messenger.onReady = { [weak self, weak messenger] in
        guard let self, let messenger else { return }
        pendingCommands.forEach(messenger.send)
        pendingCommands.removeAll()
      }

      let navigation = UINavigationController(rootViewController: messenger)
      navigation.modalPresentationStyle = .pageSheet
      if let sheet = navigation.sheetPresentationController {
        sheet.detents = [.large()]
        sheet.prefersGrabberVisible = true
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
      }

      self.messenger = messenger
      source.present(navigation, animated: true)
    }

    func dismiss() {
      guard let messenger else { return }
      messenger.navigationController?.dismiss(animated: true)
      self.messenger = nil
    }

    func reset() {
      dismiss()
      pendingCommands.removeAll()
    }

    func send(_ command: JakeWebCommand) {
      guard let messenger else {
        pendingCommands.append(command)
        return
      }
      messenger.send(command)
    }

    private static func topViewController() -> UIViewController? {
      let root = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .filter { $0.activationState == .foregroundActive }
        .flatMap(\.windows)
        .first(where: \.isKeyWindow)?
        .rootViewController
      return topViewController(from: root)
    }

    private static func topViewController(from viewController: UIViewController?)
      -> UIViewController?
    {
      if let presented = viewController?.presentedViewController {
        return topViewController(from: presented)
      }
      if let navigation = viewController as? UINavigationController {
        return topViewController(from: navigation.visibleViewController)
      }
      if let tab = viewController as? UITabBarController {
        return topViewController(from: tab.selectedViewController)
      }
      return viewController
    }
  }
#endif
