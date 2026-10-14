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

    func test_languageChangeMirrorsViewsThatAlreadyExist() throws {
        // LocalizationTests.swift reproduces views built before an account language sync keeping the old direction.
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: NBLocalization.preferenceKey)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer {
            window.isHidden = true
            if let previous {
                defaults.set(previous, forKey: NBLocalization.preferenceKey)
            } else {
                defaults.removeObject(forKey: NBLocalization.preferenceKey)
            }
            NBLocalization.configureDirection()
        }
        defaults.set("en", forKey: NBLocalization.preferenceKey)
        NBLocalization.configureDirection()
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        window.rootViewController = UIViewController()
        window.isHidden = false
        let existing = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        window.rootViewController?.view.addSubview(existing)
        window.layoutIfNeeded()
        XCTAssertEqual(existing.effectiveUserInterfaceLayoutDirection, .leftToRight)

        defaults.set("ar", forKey: NBLocalization.preferenceKey)
        NBLocalization.configureDirection()
        window.layoutIfNeeded()
        XCTAssertEqual(existing.effectiveUserInterfaceLayoutDirection, .rightToLeft,
                       "A view created in English must mirror once the account switches to Arabic")
        let created = UIView()
        window.rootViewController?.view.addSubview(created)
        XCTAssertEqual(created.effectiveUserInterfaceLayoutDirection, .rightToLeft)

        defaults.set("fr", forKey: NBLocalization.preferenceKey)
        NBLocalization.configureDirection()
        window.layoutIfNeeded()
        XCTAssertEqual(existing.effectiveUserInterfaceLayoutDirection, .leftToRight)
    }

    func test_rightToLeftFeedListDrawsUnreadCountsOnTheLeadingEdge() {
        // LocalizationTests.swift catches UnreadCountView.m drawing an Arabic feed list's counts on the right.
        let counts = UnreadCountView(frame: CGRect(x: 0, y: 0, width: 300, height: 40))
        counts.appDelegate = NewsBlurAppDelegate.shared
        func render(rightToLeft: Bool) -> UIImage {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            format.preferredRange = .standard
            return UIGraphicsImageRenderer(size: counts.bounds.size, format: format).image { context in
                UIColor.white.setFill()
                context.fill(counts.bounds)
                counts.draw(in: counts.bounds, ps: 5, nt: 0, listType: NBFeedListFeed, rightToLeft: rightToLeft)
            }
        }
        // UnreadCountView.m places a one-digit count's pill 274 to 290 points from the left edge, with its digit
        // centered, so x 275 and its mirror x 11 sample the pill beside the digit.
        let leftToRight = render(rightToLeft: false)
        XCTAssertTrue(isCountGreen(leftToRight, x: 275, y: 20))
        XCTAssertFalse(isCountGreen(leftToRight, x: 11, y: 20))
        let rightToLeft = render(rightToLeft: true)
        XCTAssertTrue(isCountGreen(rightToLeft, x: 11, y: 20), "The count must move to the left edge right to left")
        XCTAssertFalse(isCountGreen(rightToLeft, x: 275, y: 20))
    }

    func test_storyDetailMirrorsTheReaderButKeepsStoryTextInItsOwnDirection() {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: NBLocalization.preferenceKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: NBLocalization.preferenceKey)
            } else {
                defaults.removeObject(forKey: NBLocalization.preferenceKey)
            }
        }
        let page = LocalizationStoryPage()
        let appDelegate = NewsBlurAppDelegate()
        appDelegate.storiesCollection = StoriesCollection()
        page.appDelegate = appDelegate
        page.activeStory = ["story_hash": "localization-fixture", "story_feed_id": 1,
                            "story_title": "English title", "story_content": "<p>English body</p>"]
        page.loadViewIfNeeded()

        defaults.set("he", forKey: NBLocalization.preferenceKey)
        page.drawStory()
        let hebrew = page.value(forKey: "fullStoryHTML") as? String ?? ""
        XCTAssertTrue(hebrew.contains("<html dir=\"rtl\" lang=\"he\">"))
        XCTAssertTrue(hebrew.contains("<div class=\"NB-story-title\" dir=\"auto\">"))
        XCTAssertTrue(hebrew.contains("\" dir=\"auto\"><p>English body</p>"), "The story text takes its own direction")

        // LocalizationTests.swift keeps the left-to-right document free of the new direction attributes.
        defaults.set("en", forKey: NBLocalization.preferenceKey)
        page.drawStory()
        let english = page.value(forKey: "fullStoryHTML") as? String ?? ""
        XCTAssertTrue(english.contains("<!DOCTYPE html>\n<html><head>"))
        XCTAssertTrue(english.contains("<div class=\"NB-story-title\">"))
        XCTAssertTrue(english.contains("\"><p>English body</p>"))
        XCTAssertFalse(english.contains("<html dir"))
        XCTAssertFalse(english.contains(" dir=\"auto\">"), "Left-to-right markup must not gain direction attributes")
    }

    func test_searchIconStaysOnTheLeadingEdgeWhenTheLanguageChanges() throws {
        // LocalizationTests.swift reproduces FeedsObjCViewController.m's magnifying glass drawing on the left in Arabic.
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: NBLocalization.preferenceKey)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer {
            window.isHidden = true
            if let previous {
                defaults.set(previous, forKey: NBLocalization.preferenceKey)
            } else {
                defaults.removeObject(forKey: NBLocalization.preferenceKey)
            }
            NBLocalization.configureDirection()
        }
        defaults.set("ar", forKey: NBLocalization.preferenceKey)
        NBLocalization.configureDirection()
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 100)
        window.rootViewController = UIViewController()
        window.isHidden = false
        // FeedsObjCViewController.m builds the field with its icon as leftView, then places it for the language.
        let field = UITextField(frame: CGRect(x: 0, y: 0, width: 300, height: 24))
        let icon = UIView(frame: CGRect(x: 0, y: 0, width: 28, height: 24))
        icon.backgroundColor = .red
        field.leftView = icon
        field.leftViewMode = .always
        window.rootViewController?.view.addSubview(field)
        window.layoutIfNeeded()
        func iconIsDrawn(atX x: Int) -> Bool {
            window.layoutIfNeeded()
            field.layoutIfNeeded()
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.preferredRange = .standard
            let image = UIGraphicsImageRenderer(size: field.bounds.size, format: format).image { _ in
                field.drawHierarchy(in: field.bounds, afterScreenUpdates: true)
            }
            return isColor(image, x: x, y: 12, red: 0xFF, green: 0, blue: 0)
        }

        XCTAssertTrue(iconIsDrawn(atX: 14), "UITextField keeps leftView on the left when only the trait is right to left")
        field.nbPlaceLeadingAccessoryForLanguage()
        XCTAssertTrue(iconIsDrawn(atX: 286), "The icon leads on the right in Arabic")
        XCTAssertFalse(iconIsDrawn(atX: 14))

        defaults.set("en", forKey: NBLocalization.preferenceKey)
        NBLocalization.configureDirection()
        field.nbPlaceLeadingAccessoryForLanguage()
        XCTAssertNotNil(field.leftView)
        XCTAssertNil(field.rightView)
        XCTAssertTrue(iconIsDrawn(atX: 14))
        XCTAssertFalse(iconIsDrawn(atX: 286))
    }

    func test_subscriberCountsUseThePluralRulesWithGroupedDigits() {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: NBLocalization.preferenceKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: NBLocalization.preferenceKey)
            } else {
                defaults.removeObject(forKey: NBLocalization.preferenceKey)
            }
        }
        // LocalizationTests.swift reproduces AddSiteViewController.m appending an English "s" ("2人の購読者s").
        defaults.set("ja", forKey: NBLocalization.preferenceKey)
        let japanese = NBLocalization.plural("%@ subscribers", groupedCount: 2)
        XCTAssertTrue(japanese.hasPrefix("2") && japanese.hasSuffix("購読者"), japanese)
        defaults.set("ru", forKey: NBLocalization.preferenceKey)
        XCTAssertEqual(NBLocalization.plural("%@ subscribers", groupedCount: 18259),
                       "\(NBLocalization.formattedCount(18259)) подписчиков")
        defaults.set("en", forKey: NBLocalization.preferenceKey)
        XCTAssertEqual(NBLocalization.plural("%@ subscribers", groupedCount: 1), "1 subscriber")
        XCTAssertEqual(NBLocalization.plural("%@ subscribers", groupedCount: 1240), "1,240 subscribers")
    }

    func test_countsGroupDigitsLikeTheAccountLanguageWithLatinDigits() {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: NBLocalization.preferenceKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: NBLocalization.preferenceKey)
            } else {
                defaults.removeObject(forKey: NBLocalization.preferenceKey)
            }
        }
        // LocalizationTests.swift reproduces FeedsObjCViewController.m showing "18,259" to a German account.
        defaults.set("de", forKey: NBLocalization.preferenceKey)
        XCTAssertEqual(NBLocalization.formattedCount(18259), "18.259")
        defaults.set("ar", forKey: NBLocalization.preferenceKey)
        XCTAssertEqual(NBLocalization.formattedCount(18259), "18,259", "Arabic keeps the Latin digits the web shows")
        defaults.set("en", forKey: NBLocalization.preferenceKey)
        let device = NumberFormatter()
        device.numberStyle = .decimal
        XCTAssertEqual(NBLocalization.formattedCount(18259), device.string(from: 18259))
    }

    private func isCountGreen(_ image: UIImage, x: Int, y: Int) -> Bool {
        // UnreadCountView.m fills focus counts with 0x6EA74A.
        isColor(image, x: x, y: y, red: 0x6E, green: 0xA7, blue: 0x4A)
    }

    private func isColor(_ image: UIImage, x: Int, y: Int, red: Int, green: Int, blue: Int) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        // LocalizationTests.swift copies the pixel into a known RGBA layout before comparing it.
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        context.draw(cgImage, in: CGRect(x: -x, y: y - cgImage.height + 1, width: cgImage.width, height: cgImage.height))
        return abs(Int(pixel[0]) - red) < 12 && abs(Int(pixel[1]) - green) < 12 && abs(Int(pixel[2]) - blue) < 12
    }
}

// LocalizationTests.swift builds the real story document without WebKit, like StoryDetailAssetPerformanceTests.swift.
@MainActor private final class LocalizationStoryPage: StoryDetailViewController {
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)) }
    override func viewDidLoad() {}
    override func viewWillLayoutSubviews() {}
    override func getShareBar() -> String! { "" }
    override func getComments() -> String! { "" }
    @objc(getSideOptions) func fixtureSideOptions() -> String { "" }
    @objc(loadHTMLString:) func fixtureLoadHTML(_ html: String) {}
    @objc(loadStory) func fixtureLoadStory() {}
}

// LocalizationTests.swift records ProfileBadge.m requests without sending them.
private final class LocalizationRecordingAppDelegate: NewsBlurAppDelegate {
    var postedURLs: [String] = []
    override var url: String! { "https://localization-fixture.invalid" }
    override func post(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask?, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error?) -> Void)!) {
        postedURLs.append(urlString)
    }
}
