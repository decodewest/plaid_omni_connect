import Cocoa
import FlutterMacOS

public class PlaidOmniConnectPlugin: NSObject, FlutterPlugin {
    private var linkHandler: PlaidLinkHandler?
    private var channel: FlutterMethodChannel?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "plaid_omni_connect",
            binaryMessenger: registrar.messenger
        )
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
            
            let parentWindow = NSApplication.shared.mainWindow
            // Use the stored channel
            if let channel = self.channel {
                linkHandler = PlaidLinkHandler(
                    channel: channel,
                    parentWindow: parentWindow
                )
                linkHandler?.openPlaidLink(linkToken: linkToken)
                result(nil)
            } else {
                 result(FlutterError(code: "INTERNAL_ERROR", message: "Channel not initialized", details: nil))
            }
            
        case "close":
            linkHandler?.closePanel(animated: true)
            result(nil)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
