import XCTest

@testable import NewsBlur

@MainActor
final class Test_Localization: XCTestCase {
    func test_missingObjectiveCCountOmitsTheStatistic() {
        // LocalizationTests.swift reproduces NotificationsViewController.m passing a missing feed statistic.
        let result = NBLocalization.perform(#selector(NBLocalization.plural(_:count:)),
                                            with: "%@ stories/month", with: nil)
        XCTAssertEqual(result?.takeUnretainedValue() as? String, "")
    }

    func test_accountOverrideControlsPluralRules() {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: NBLocalization.preferenceKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: NBLocalization.preferenceKey)
            } else {
                defaults.removeObject(forKey: NBLocalization.preferenceKey)
            }
        }

        // LocalizationTests.swift catches using the device's English plural rule with Russian copy.
        defaults.set("ru", forKey: NBLocalization.preferenceKey)
        XCTAssertEqual(NBLocalization.plural("%@ subscribers", count: 1), "1 подписчик")
        XCTAssertEqual(NBLocalization.plural("%@ subscribers", count: 2), "2 подписчика")
        XCTAssertEqual(NBLocalization.plural("%@ subscribers", count: 5), "5 подписчиков")

        defaults.set("en", forKey: NBLocalization.preferenceKey)
        XCTAssertEqual(NBLocalization.plural("%@ subscribers", count: 1), "1 subscriber")
        XCTAssertEqual(NBLocalization.plural("%@ subscribers", count: 2), "2 subscribers")
    }

    func test_translatedFollowButtonStillFollowsAndUnfollows() throws {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: NBLocalization.preferenceKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: NBLocalization.preferenceKey)
            } else {
                defaults.removeObject(forKey: NBLocalization.preferenceKey)
            }
        }
        // LocalizationTests.swift reproduces ProfileBadge.m comparing the French button title to English "Follow".
        defaults.set("fr", forKey: NBLocalization.preferenceKey)
        let badgeClass = try XCTUnwrap(NSClassFromString("ProfileBadge") as? NSObject.Type)
        typealias Refresh = @convention(c) (AnyObject, Selector, NSDictionary, Bool, Int32) -> Void
        let refreshSelector = NSSelectorFromString("refreshWithProfile:showStats:withWidth:")
        for (followed, path) in [(0, "/social/follow"), (1, "/social/unfollow")] {
            let badge = try XCTUnwrap(badgeClass.init() as? UITableViewCell)
            let profile: NSDictionary = ["user_id": 42, "username": "localization-fixture", "followed_by_you": followed,
                                         "photo_url": "https://localization-fixture.invalid/avatar.png"]
            unsafeBitCast(badge.method(for: refreshSelector), to: Refresh.self)(badge, refreshSelector, profile, false, 320)
            let button = try XCTUnwrap(badge.value(forKey: "followButton") as? UIButton)
            XCTAssertEqual(button.currentTitle, NBLocalization.text(followed == 1 ? "Following" : "Follow"))
            XCTAssertNotEqual(button.currentTitle, "Follow", "The fixture must render a translated title")
            // ProfileBadge.m reads the shared app delegate while rendering, so the recorder replaces it afterwards.
            let app = LocalizationRecordingAppDelegate()
            badge.setValue(app, forKey: "appDelegate")
            badge.perform(NSSelectorFromString("doFollowButton:"), with: nil)
            XCTAssertEqual(app.postedURLs, ["https://localization-fixture.invalid\(path)"])
        }
    }
}

// LocalizationTests.swift records ProfileBadge.m requests without sending them.
private final class LocalizationRecordingAppDelegate: NewsBlurAppDelegate {
    var postedURLs: [String] = []
    override var url: String! { "https://localization-fixture.invalid" }
    override func post(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask?, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error?) -> Void)!) {
        postedURLs.append(urlString)
    }
}
