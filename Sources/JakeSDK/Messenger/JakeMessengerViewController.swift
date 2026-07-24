#if canImport(UIKit)
  import UIKit
  @preconcurrency import WebKit

  @MainActor
  final class JakeMessengerViewController: UIViewController {
    private let request: URLRequest
    private let onMessage: (JakeWebMessage) -> Void
    private let onError: (JakeError) -> Void
    private let bridge = JakeWebBridge()
    private let webView: WKWebView
    private let spinner = UIActivityIndicatorView(style: .large)
    private let errorView = JakeMessengerErrorView()
    private var isReady = false
    private var pendingCommands: [JakeWebCommand] = []

    var onReady: (() -> Void)?

    init(
      request: URLRequest,
      onMessage: @escaping (JakeWebMessage) -> Void,
      onError: @escaping (JakeError) -> Void
    ) {
      self.request = request
      self.onMessage = onMessage
      self.onError = onError

      let configuration = WKWebViewConfiguration()
      configuration.websiteDataStore = .nonPersistent()
      configuration.defaultWebpagePreferences.allowsContentJavaScript = true
      configuration.allowsInlineMediaPlayback = true
      configuration.userContentController.add(bridge, name: "jake")
      webView = WKWebView(frame: .zero, configuration: configuration)

      super.init(nibName: nil, bundle: nil)
      bridge.delegate = self
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
      super.viewDidLoad()
      view.backgroundColor = .systemBackground

      webView.navigationDelegate = self
      webView.uiDelegate = self
      webView.allowsLinkPreview = false
      webView.scrollView.contentInsetAdjustmentBehavior = .never
      webView.scrollView.keyboardDismissMode = .interactive
      webView.scrollView.automaticallyAdjustsScrollIndicatorInsets = false

      for subview in [webView, spinner, errorView] {
        subview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subview)
      }
      NSLayoutConstraint.activate([
        webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
        errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        errorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      ])
      errorView.isHidden = true
      errorView.onRetry = { [weak self] in self?.loadMessenger() }
      loadMessenger()
    }

    func send(_ command: JakeWebCommand) {
      guard isReady else {
        pendingCommands.append(command)
        return
      }
      evaluate(command)
    }

    private func evaluate(_ command: JakeWebCommand) {
      do {
        let data = try JSONSerialization.data(
          withJSONObject: ["type": command.name, "payload": command.payload],
          options: [.sortedKeys]
        )
        guard let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.JakeNative && window.JakeNative.receive(\(json));")
      } catch {
        onError(.messengerLoadFailed("Could not send a native event."))
      }
    }

    private func loadMessenger() {
      isReady = false
      errorView.isHidden = true
      webView.isHidden = true
      spinner.startAnimating()
      webView.load(request)
    }

    private func show(error: Error) {
      spinner.stopAnimating()
      webView.isHidden = true
      errorView.isHidden = false
      let jakeError = JakeError.messengerLoadFailed(error.localizedDescription)
      errorView.set(message: jakeError.localizedDescription)
      onError(jakeError)
    }
  }

  extension JakeMessengerViewController: JakeWebBridgeDelegate {
    func webBridge(didReceive message: JakeWebMessage) {
      if message == .ready {
        isReady = true
        evaluate(.deviceContext())
        pendingCommands.forEach(evaluate)
        pendingCommands.removeAll()
        onReady?()
      }
      if case .openExternalURL(let url) = message {
        openExternal(url)
      }
      onMessage(message)
    }
  }

  extension JakeMessengerViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish _: WKNavigation?) {
      spinner.stopAnimating()
      errorView.isHidden = true
      webView.isHidden = false
    }

    func webView(_: WKWebView, didFail _: WKNavigation?, withError error: Error) {
      show(error: error)
    }

    func webView(
      _: WKWebView, didFailProvisionalNavigation _: WKNavigation?, withError error: Error
    ) {
      show(error: error)
    }

    func webView(
      _: WKWebView,
      decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
      guard navigationAction.navigationType == .linkActivated,
        let url = navigationAction.request.url,
        !isMessengerURL(url)
      else {
        decisionHandler(.allow)
        return
      }
      openExternal(url)
      decisionHandler(.cancel)
    }

    private func isMessengerURL(_ url: URL) -> Bool {
      url.host?.lowercased() == request.url?.host?.lowercased()
    }
  }

  extension JakeMessengerViewController: WKUIDelegate {
    func webView(
      _: WKWebView,
      createWebViewWith _: WKWebViewConfiguration,
      for navigationAction: WKNavigationAction,
      windowFeatures _: WKWindowFeatures
    ) -> WKWebView? {
      if let url = navigationAction.request.url {
        openExternal(url)
      }
      return nil
    }
  }

  extension JakeMessengerViewController {
    fileprivate func openExternal(_ url: URL) {
      guard let scheme = url.scheme?.lowercased(),
        ["http", "https", "mailto", "tel"].contains(scheme)
      else {
        return
      }
      UIApplication.shared.open(url)
    }
  }

  @MainActor
  private final class JakeMessengerErrorView: UIView {
    private let messageLabel = UILabel()
    var onRetry: (() -> Void)?

    override init(frame: CGRect) {
      super.init(frame: frame)

      let titleLabel = UILabel()
      titleLabel.text = "Messenger is unavailable"
      titleLabel.font = .preferredFont(forTextStyle: .headline)
      titleLabel.textAlignment = .center

      messageLabel.font = .preferredFont(forTextStyle: .subheadline)
      messageLabel.textColor = .secondaryLabel
      messageLabel.textAlignment = .center
      messageLabel.numberOfLines = 0

      var buttonConfiguration = UIButton.Configuration.filled()
      buttonConfiguration.title = "Try again"
      let retryButton = UIButton(configuration: buttonConfiguration)
      retryButton.addAction(UIAction { [weak self] _ in self?.onRetry?() }, for: .touchUpInside)

      let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, retryButton])
      stack.axis = .vertical
      stack.alignment = .center
      stack.spacing = 16
      stack.translatesAutoresizingMaskIntoConstraints = false
      addSubview(stack)
      NSLayoutConstraint.activate([
        stack.topAnchor.constraint(equalTo: topAnchor),
        stack.leadingAnchor.constraint(equalTo: leadingAnchor),
        stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        retryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
      ])
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    func set(message: String) {
      messageLabel.text = message
    }
  }
#endif
