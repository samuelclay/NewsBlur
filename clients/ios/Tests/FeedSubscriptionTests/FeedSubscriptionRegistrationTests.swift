import Foundation
import XCTest

final class Test_FeedSubscriptionRegistration: XCTestCase {
    func test_safariOffersDedicatedSubscriptionAction() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Subscribe Extension/Info.plist"))
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(plist["CFBundleDisplayName"] as? String, "Subscribe in NewsBlur")
        let config = try XCTUnwrap(plist["NSExtension"] as? [String: Any])
        XCTAssertEqual(config["NSExtensionPointIdentifier"] as? String, "com.apple.ui-services")
        XCTAssertEqual(config["NSExtensionMainStoryboard"] as? String, "MainInterface",
                       "Subscribe must reuse the familiar NewsBlur share dialog and folder picker.")
    }

    func test_feedLinksCanBeDeliveredToNewsBlur() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Resources/Info.plist"))
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let types = try XCTUnwrap(plist["CFBundleURLTypes"] as? [[String: Any]])
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        XCTAssertTrue(schemes.contains("feed"), "Safari must be able to hand RSS feed links to NewsBlur")
        XCTAssertTrue(schemes.contains("feeds"), "Secure feed links must preserve HTTPS")
        XCTAssertTrue(schemes.contains("newsblur"))
    }
}
