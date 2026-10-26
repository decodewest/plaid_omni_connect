import Cocoa
import FlutterMacOS
import WebKit

class PlaidLinkHandler: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
    private var webView: WKWebView?
    private var panel: NSPanel?
    private var parentWindow: NSWindow?
    private var channel: FlutterMethodChannel
    private var popupWindow: NSWindow?
    private var finished = false
    
    init(channel: FlutterMethodChannel, parentWindow: NSWindow?) {
        self.channel = channel
        self.parentWindow = parentWindow
        super.init()
    }
    
    func openPlaidLink(pageHtml: String) {
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
        
        webView?.loadHTMLString(pageHtml, baseURL: URL(string: "https://cdn.plaid.com"))
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
        guard let json = jsonText(from: message.body) else { return }
        forward(json)
    }
    
    func webView(_ webView: WKWebView,
                didFail navigation: WKNavigation!,
                withError error: Error) {
        forward(errorPayload(error.localizedDescription))
    }

    func webView(_ webView: WKWebView,
                didFailProvisionalNavigation navigation: WKNavigation!,
                withError error: Error) {
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
            closePanel(animated: true)
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
