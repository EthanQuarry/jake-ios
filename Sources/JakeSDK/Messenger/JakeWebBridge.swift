#if canImport(UIKit)
  @preconcurrency import WebKit

  @MainActor
  protocol JakeWebBridgeDelegate: AnyObject {
    func webBridge(didReceive message: JakeWebMessage)
  }

  final class JakeWebBridge: NSObject, WKScriptMessageHandler {
    weak var delegate: (any JakeWebBridgeDelegate)?

    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
      guard message.name == "jake", let parsed = JakeWebMessage(body: message.body) else { return }
      Task { @MainActor [weak self] in
        self?.delegate?.webBridge(didReceive: parsed)
      }
    }
  }
#endif
