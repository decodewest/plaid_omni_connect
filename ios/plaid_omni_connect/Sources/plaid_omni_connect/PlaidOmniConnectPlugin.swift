import Flutter
import UIKit
import WebKit


public class PlaidOmniConnectPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var linkHandler: PlaidLinkIOHandler?
    private var registrar: FlutterPluginRegistrar?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "plaid_omni_connect", binaryMessenger: registrar.messenger())
        let instance = PlaidOmniConnectPlugin()
        instance.channel = channel
        instance.registrar = registrar
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
         switch call.method {
        case "open":
            guard let args = call.arguments as? [String: Any],
                  let pageHtml = args["pageHtml"] as? String,
                  !pageHtml.isEmpty else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing pageHtml", details: nil))
                return
            }

            guard let rootViewController = presentingViewController() else {
                result(FlutterError(code: "NO_ROOT_VIEW", message: "No root view controller", details: nil))
                return
            }

            linkHandler = PlaidLinkIOHandler(channel: self.channel!, rootViewController: rootViewController)
            linkHandler?.openPlaidLink(pageHtml: pageHtml)
            result(nil)

        case "close":
            linkHandler?.close(animated: true)
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Resolves a view controller that can present Plaid Link after UIScene adoption.
    /// `UIApplication.delegate.window` is no longer set at launch on UIScene apps.
    private func presentingViewController() -> UIViewController? {
        if let controller = registrar?.viewController {
            return topViewController(from: controller)
        }

        guard let window = keyWindow() else {
            return nil
        }
        return topViewController(from: window.rootViewController)
    }

    private func keyWindow() -> UIWindow? {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let keyWindow = windowScenes.flatMap({ $0.windows }).first(where: { $0.isKeyWindow }) {
            return keyWindow
        }
        return windowScenes.first?.windows.first
    }

    private func topViewController(from controller: UIViewController?) -> UIViewController? {
        var current = controller
        while let presented = current?.presentedViewController {
            current = presented
        }
        return current
    }
}

class PlaidLinkIOHandler: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private var webView: WKWebView?
    private var viewController: UIViewController?
    private var rootViewController: UIViewController
    private var channel: FlutterMethodChannel
    private var finished = false

    init(channel: FlutterMethodChannel, rootViewController: UIViewController) {
        self.channel = channel
        self.rootViewController = rootViewController
        super.init()
    }

    func openPlaidLink(pageHtml: String) {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(self, name: "plaidLinkHandler")
        config.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView?.navigationDelegate = self

        viewController = UIViewController()
        viewController?.view = webView
        viewController?.modalPresentationStyle = .overFullScreen

        webView?.loadHTMLString(pageHtml, baseURL: URL(string: "https://cdn.plaid.com"))

        rootViewController.present(viewController!, animated: true)
    }

    func close(animated: Bool) {
        viewController?.dismiss(animated: animated)
        webView = nil
        viewController = nil
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let json = jsonText(from: message.body) else { return }
        forward(json)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        forward(errorPayload(error.localizedDescription))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        forward(errorPayload(error.localizedDescription))
    }

    private func forward(_ json: String) {
        let terminal = isTerminalLinkMessage(json)
        if terminal {
            if finished { return }
            finished = true
        }
        channel.invokeMethod("onLinkMessage", arguments: json)
        if terminal {
            close(animated: true)
        }
    }

    private func jsonText(from body: Any) -> String? {
        if let text = body as? String {
            return text
        }
        guard JSONSerialization.isValidJSONObject(body),
              let data = try? JSONSerialization.data(withJSONObject: body),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return text
    }

    private func errorPayload(_ message: String) -> String {
        let escaped = message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "{\"type\":\"error\",\"error\":\"\(escaped)\"}"
    }

    private func isTerminalLinkMessage(_ json: String) -> Bool {
        return json.contains("\"type\":\"success\"")
            || json.contains("\"type\":\"exit\"")
            || json.contains("\"type\":\"error\"")
    }
}
