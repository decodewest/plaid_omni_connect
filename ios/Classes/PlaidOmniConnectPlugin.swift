import Flutter
import UIKit
import WebKit


public class PlaidOmniConnectPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var linkHandler: PlaidLinkIOHandler?
        
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "plaid_omni_connect", binaryMessenger: registrar.messenger())
        let instance = PlaidOmniConnectPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
         switch call.method {
        case "open":
            guard let args = call.arguments as? [String: Any],
                  let linkToken = args["linkToken"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing linkToken", details: nil))
                return
            }
            
            // Get root view controller
            guard let window = UIApplication.shared.delegate?.window as? UIWindow,
                  let rootViewController = window.rootViewController else {
                result(FlutterError(code: "NO_ROOT_VIEW", message: "No root view controller", details: nil))
                return
            }
            
            linkHandler = PlaidLinkIOHandler(channel: self.channel!, rootViewController: rootViewController)
            linkHandler?.openPlaidLink(linkToken: linkToken)
            result(nil)
            
        case "close":
            linkHandler?.close(animated: true)
            result(nil)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

class PlaidLinkIOHandler: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private var webView: WKWebView?
    private var viewController: UIViewController?
    private var rootViewController: UIViewController
    private var channel: FlutterMethodChannel
    
    init(channel: FlutterMethodChannel, rootViewController: UIViewController) {
        self.channel = channel
        self.rootViewController = rootViewController
        super.init()
    }
    
    func openPlaidLink(linkToken: String) {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(self, name: "plaidLinkHandler")
        config.userContentController = contentController
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView?.navigationDelegate = self
        
        viewController = UIViewController()
        viewController?.view = webView
        viewController?.modalPresentationStyle = .overFullScreen
        
        // Load Plaid Link
        let htmlString = createPlaidHTML(linkToken: linkToken)
        webView?.loadHTMLString(htmlString, baseURL: URL(string: "https://cdn.plaid.com"))
        
        rootViewController.present(viewController!, animated: true)
    }
    
    func close(animated: Bool) {
        viewController?.dismiss(animated: animated)
        webView = nil
        viewController = nil
    }
    
    private func createPlaidHTML(linkToken: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <script src="https://cdn.plaid.com/link/v2/stable/link-initialize.js"></script>
            <style>
                body { margin: 0; padding: 0; }
                #plaid-container { width: 100vw; height: 100vh; }
            </style>
        </head>
        <body>
            <script>
                const handler = Plaid.create({
                    token: '\(linkToken)',
                    onSuccess: (public_token, metadata) => {
                        window.webkit.messageHandlers.plaidLinkHandler.postMessage({
                            type: 'success',
                            publicToken: public_token,
                            metadata: metadata
                        });
                    },
                    onExit: (err, metadata) => {
                        window.webkit.messageHandlers.plaidLinkHandler.postMessage({
                            type: 'exit',
                            error: err,
                            metadata: metadata
                        });
                    },
                    onEvent: (eventName, metadata) => {
                        window.webkit.messageHandlers.plaidLinkHandler.postMessage({
                            type: 'event',
                            eventName: eventName,
                            metadata: metadata
                        });
                    }
                });
                handler.open();
            </script>
        </body>
        </html>
        """
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        
        switch type {
        case "success":
            channel.invokeMethod("onSuccess", arguments: [
                "publicToken": body["publicToken"] ?? "",
                "metadata": body["metadata"] ?? [:]
            ])
            close(animated: true)
            
        case "exit":
            channel.invokeMethod("onExit", arguments: [
                "error": body["error"] as Any,
                "metadata": body["metadata"] ?? [:]
            ])
            close(animated: true)
            
        case "event":
            channel.invokeMethod("onEvent", arguments: [
                "eventName": body["eventName"] ?? "",
                "metadata": body["metadata"] ?? [:]
            ])
            
        default:
            break
        }
    }
}
