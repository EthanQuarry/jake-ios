#if canImport(UIKit)
  import UIKit
  import SwiftUI
  import CustomAgentAdapter
  import SupportKitCore
  import SupportKitUI

  enum JakeNativePresenterCommand: Sendable {
    case track(name: String, properties: [String: JakeValue])
    case setUserAttributes([String: JakeValue])
    case setPushToken(String)
  }

  @MainActor
  final class JakeNativePresenter {
    private weak var conversationController: JakeNativeConversationController?
    private var channel: RouterChannelAdapter?
    private var delegateBridge: JakeNativeChannelDelegate?

    func present(
      configuration: JakeConfiguration,
      session: JakeSession,
      from source: UIViewController? = nil,
      onAuthenticationExpired: @escaping () -> Void,
      onError: @escaping (JakeError) -> Void
    ) throws {
      guard conversationController == nil else { return }
      guard let source = source ?? Self.topViewController() else {
        throw JakeError.presentationUnavailable
      }

      let channel = RouterChannelAdapter(
        configuration: SupportRouterConfiguration(
          baseURL: configuration.conversationAPIURL,
          agentProviderID: "jake",
          aiDisclosure: "AI agent",
          sessionToken: { session.token }
        )
      )
      let model = SupportConversationModel(channel: channel)
      let delegate = JakeNativeChannelDelegate(
        model: model,
        onError: onError,
        onAuthenticationExpired: onAuthenticationExpired
      )
      channel.delegate = delegate

      let controller = JakeNativeConversationController(model: model) { [weak self] in
        self?.conversationController?.dismiss(animated: true)
        self?.clearPresenterState()
      }

      self.channelPresentationStyle(controller)
      self.channel = channel
      self.delegateBridge = delegate
      self.conversationController = controller

      Task {
        do {
          try await channel.identify(
            SupportChannelSession(
              customer: SupportCustomer(
                id: session.userId,
                externalID: session.userId,
                name: nil,
                email: nil,
                attributes: [:]
              )
            )
          )
          source.present(controller, animated: true)
        } catch {
          clearPresenterState()
          onError(.authenticationRequired)
        }
      }
    }

    func dismiss() {
      conversationController?.dismiss(animated: true)
      clearPresenterState()
    }

    func reset() {
      dismiss()
    }

    func send(_ command: JakeNativePresenterCommand) {
      _ = command
    }

  private func channelPresentationStyle(_ controller: UIViewController) {
      controller.modalPresentationStyle = .pageSheet
      if let sheet = controller.sheetPresentationController {
        sheet.detents = [.large()]
        sheet.prefersGrabberVisible = false
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        if #available(iOS 16.0, *) {
          sheet.preferredCornerRadius = 16
        }
      }
    }

    private func clearPresenterState() {
      conversationController = nil
      delegateBridge = nil
      Task {
        await channel?.logout()
        channel = nil
      }
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

  @MainActor
  private final class JakeNativeChannelDelegate: SupportChannelAdapterDelegate {
    private let model: SupportConversationModel
    private let onError: (JakeError) -> Void
    private let onAuthenticationExpired: () -> Void

    init(
      model: SupportConversationModel,
      onError: @escaping (JakeError) -> Void,
      onAuthenticationExpired: @escaping () -> Void
    ) {
      self.model = model
      self.onError = onError
      self.onAuthenticationExpired = onAuthenticationExpired
    }

    func supportChannel(_ channel: any SupportChannelAdapter, didEmit event: SupportChannelEvent) {
      model.supportChannel(channel, didEmit: event)
      if case .failure(_, let message) = event {
        onError(.messengerLoadFailed(message))
      }
      if case .authenticationExpired = event {
        onAuthenticationExpired()
      }
    }
  }

  private final class JakeNativeConversationController: UIViewController {
    private let onDismiss: () -> Void
    private let hostingController: UIViewController

    init(model: SupportConversationModel, onDismiss: @escaping () -> Void) {
      self.onDismiss = onDismiss
      hostingController = UIHostingController(
        rootView: JakeNativeConversationView(model: model, onClose: onDismiss)
      )
      super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
      super.viewDidLoad()
      view.backgroundColor = .systemBackground

      addChild(hostingController)
      hostingController.view.backgroundColor = .clear
      hostingController.view.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(hostingController.view)
      hostingController.didMove(toParent: self)

      NSLayoutConstraint.activate([
        hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
        hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      ])
    }

    override func viewDidDisappear(_ animated: Bool) {
      super.viewDidDisappear(animated)
      onDismiss()
    }
  }

  private struct JakeNativeConversationView: View {
    @ObservedObject private var model: SupportConversationModel
    private let onClose: () -> Void

    init(model: SupportConversationModel, onClose: @escaping () -> Void) {
      self.model = model
      self.onClose = onClose
    }

    var body: some View {
      ZStack(alignment: .topTrailing) {
        SupportConversationView(model: model, branding: .channel, theme: .automatic)
        Button {
          onClose()
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 13, weight: .semibold))
            .padding(8)
            .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
        .padding(.trailing, 12)
        .accessibilityLabel("Close")
      }
    }
  }
#endif
