// NewsBlur Archive - Safari Web Extension Handler
// Handles native messaging between the extension and the macOS app

import SafariServices
import os.log

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    private let logger = Logger(subsystem: "com.newsblur.archive", category: "SafariWebExtensionHandler")

    func beginRequest(with context: NSExtensionContext) {
        let item = context.inputItems[0] as! NSExtensionItem
        let message = item.userInfo?[SFExtensionMessageKey] as? [String: Any]

        logger.info("Received message from extension: \(String(describing: message))")

        // Handle messages from the extension
        guard let action = message?["action"] as? String else {
            sendResponse(context: context, response: ["error": "No action specified"])
            return
        }

        switch action {
        case "getAppGroupIdentifier":
            // Return the app group identifier for shared storage
            let response: [String: Any] = [
                "appGroupIdentifier": "group.com.newsblur.archive"
            ]
            sendResponse(context: context, response: response)

        case "getNativeStatus":
            // Return status information
            let response: [String: Any] = [
                "status": "active",
                "version": getAppVersion()
            ]
            sendResponse(context: context, response: response)

        case "log":
            // Log message from extension
            if let logMessage = message?["message"] as? String {
                logger.info("Extension log: \(logMessage)")
            }
            sendResponse(context: context, response: ["logged": true])

        default:
            logger.warning("Unknown action: \(action)")
            sendResponse(context: context, response: ["error": "Unknown action"])
        }
    }

    private func sendResponse(context: NSExtensionContext, response: [String: Any]) {
        let item = NSExtensionItem()
        item.userInfo = [SFExtensionMessageKey: response]
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }

    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
