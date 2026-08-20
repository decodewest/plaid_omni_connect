import Cocoa
import FlutterMacOS
import WebKit

class PlaidLinkHandler: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
    private var webView: WKWebView?
    private var panel: NSPanel?
    private var parentWindow: NSWindow?
    private var channel: FlutterMethodChannel
    private var popupWindow: NSWindow?
    
    init(channel: FlutterMethodChannel, parentWindow: NSWindow?) {
        self.channel = channel
        self.parentWindow = parentWindow
        super.init()
    }
    
    func openPlaidLink(linkToken: String) {
        // Configure WebView
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(self, name: "plaidLinkHandler")
        config.userContentController = contentController
        
        if #available(macOS 11.0, *) {
            let preferences = WKWebpagePreferences()
            preferences.allowsContentJavaScript = true
            config.defaultWebpagePreferences = preferences
        } else {
            config.preferences.javaScriptEnabled = true
        }
        
        // Create WebView
        let rect = NSRect(x: 0, y: 0, width: 600, height: 800)
        webView = WKWebView(frame: rect, configuration: config)
        webView?.navigationDelegate = self
        webView?.uiDelegate = self

        
        // Create modal panel
        panel = NSPanel(
            contentRect: rect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        panel?.title = "Connect Your Account"
        panel?.titlebarAppearsTransparent = false
        panel?.backgroundColor = .white
        panel?.isMovableByWindowBackground = true
        panel?.contentView = webView
        panel?.isFloatingPanel = true
        panel?.level = .modalPanel
        
        // Center and show
        if let parent = parentWindow {
            panel?.center()
            parent.beginSheet(panel!) { response in
                // Sheet closed
            }
        } else {
            panel?.center()
            panel?.makeKeyAndOrderFront(nil)
        }
        
        // Animate appearance
        panel?.alphaValue = 0.0
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel?.animator().alphaValue = 1.0
        })
        
        // Load Plaid Link
        let htmlString = createPlaidHTML(linkToken: linkToken)
        webView?.loadHTMLString(htmlString, baseURL: URL(string: "https://cdn.plaid.com"))
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
                body {
                    margin: 0;
                    padding: 0;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
                    overflow: hidden;
                }
                #plaid-container {
                    width: 100%;
                    height: 100vh;
                }
                .loading {
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    height: 100vh;
                    font-size: 18px;
                    color: #666;
                }
            </style>
        </head>
        <body>
            <div id="plaid-container">
                <div class="loading">Loading Plaid Link...</div>
            </div>
            <script>
                try {
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
                        },
                        onLoad: () => {
                            document.querySelector('.loading').style.display = 'none';
                        }
                    });
                    
                    handler.open();
                } catch (error) {
                    window.webkit.messageHandlers.plaidLinkHandler.postMessage({
                        type: 'error',
                        error: error.message
                    });
                }
            </script>
        </body>
        </html>
        """
    }
    
    func closePanel(animated: Bool = true) {
        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel?.animator().alphaValue = 0.0
            }, completionHandler: {
                self.dismissPanel()
            })
        } else {
            dismissPanel()
        }
    }
    
    private func dismissPanel() {
        if let parent = parentWindow {
            parent.endSheet(panel!)
        } else {
            panel?.close()
        }
        panel = nil
        webView = nil
    }
    
    func userContentController(_ userContentController: WKUserContentController,
                              didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        
        switch type {
        case "success":
            channel.invokeMethod("onSuccess", arguments: [
                "publicToken": body["publicToken"] ?? "",
                "metadata": body["metadata"] ?? [:]
            ])
            closePanel(animated: true)
            
        case "exit":
            channel.invokeMethod("onExit", arguments: [
                "error": body["error"] as Any,
                "metadata": body["metadata"] ?? [:]
            ])
            closePanel(animated: true)
            
        case "event":
            channel.invokeMethod("onEvent", arguments: [
                "eventName": body["eventName"] ?? "",
                "metadata": body["metadata"] ?? [:]
            ])
            
        case "error":
            channel.invokeMethod("onError", arguments: [
                "error": body["error"] ?? "Unknown error"
            ])
            closePanel(animated: true)
            
        default:
            break
        }
    }
    
    func webView(_ webView: WKWebView,
                didFail navigation: WKNavigation!,
                withError error: Error) {
        channel.invokeMethod("onError", arguments: [
            "error": error.localizedDescription
        ])
        closePanel(animated: true)
    }
    
    // MARK: - WKUIDelegate
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let popup = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        popup.navigationDelegate = self
        popup.uiDelegate = self
        
        let newWindow = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Authentication"
        newWindow.contentView = popup
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        
        self.popupWindow = newWindow
        return popup
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        if webView == self.popupWindow?.contentView {
            self.popupWindow?.close()
            self.popupWindow = nil
        }
    }
}
