import ObjectiveC.runtime
import UIKit
import XCTest

@testable import NewsBlur

@MainActor final class Test_StoryDetailAssetPerformance: XCTestCase {
    private let preferenceKeys = ["theme_style", "theme_light", "theme_dark", "fontStyle", "story_font_size", "story_line_spacing"]
    private var savedPreferences: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        for key in preferenceKeys {
            if let value = UserDefaults.standard.object(forKey: key) {
                savedPreferences[key] = value
            }
        }
        UserDefaults.standard.set("medium", forKey: "story_font_size")
        UserDefaults.standard.set("medium", forKey: "story_line_spacing")
        setTheme("light")
    }

    override func tearDown() {
        for key in preferenceKeys {
            if let value = savedPreferences[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        savedPreferences.removeAll()
        super.tearDown()
    }

    func test_warmStoryDrawsAcrossPagesDoNotRereadStaticBundleFiles() throws {
        let pages = (0..<3).map { makePage(storyHash: "fixture-\($0)") }
        _ = draw(pages[0])
        let reads = try StaticAssetReadSpy()
        defer { reads.restore() }

        for _ in 0..<4 {
            for page in pages { _ = draw(page) }
        }

        XCTAssertEqual(StaticAssetReadSpy.readPaths, [], "Warm story draws must reuse their immutable CSS and JavaScript")
    }

    func test_allThemesKeepExactCSSScriptsAndEmbeddedFontData() throws {
        let page = makePage()
        let mainCSS = try readResource("storyDetailView", extension: "css")
        let expectedCSS = try XCTUnwrap(page.perform(NSSelectorFromString("embedResourcesInCSS:bundle:"),
                                                    with: mainCSS, with: Bundle.main)?.takeUnretainedValue() as? String)
        let scripts = try ["zepto", "fitvid", "mark", "storyDetailView", "fastTouch"].map {
            try readResource($0, extension: "js")
        }

        for theme in ["light", "sepia", "medium", "dark"] {
            setTheme(theme)
            let suffix = try XCTUnwrap(ThemeManager.shared?.themeCSSSuffix)
            let themeCSS = try readResource("storyDetailView" + suffix, extension: "css")
            let html = draw(page)
            XCTAssertTrue(html.contains("<style>\(expectedCSS)</style><style id=\"NB-theme-style\">\(themeCSS)</style>"), theme)
            XCTAssertTrue(html.contains(scripts.map { "<script>\($0)</script>" }.joined()), theme)

            for font in ["ChronicleSSm-Book", "GothamNarrow-Book", "WhitneySSm-Book-Bas"] {
                let path = try XCTUnwrap(Bundle.main.path(forResource: font, ofType: "otf"))
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                XCTAssertTrue(html.contains("data:font/otf;base64," + data.base64EncodedString()), "\(theme): \(font)")
            }
        }
    }

    func test_cachedAssetsStillRegenerateStoryContentAndReadingPreferences() {
        let page = makePage()
        let firstHTML = draw(page)
        page.activeStory["story_content"] = "<p>Updated body with <em>formatting</em></p>"
        page.activeStory["story_title"] = "Updated title"
        page.commentText = "Updated comments"
        page.inTextView = true
        page.activeStory["original_text"] = "<p>Updated text view</p>"
        UserDefaults.standard.set("ChronicleSSm-Book", forKey: "fontStyle")
        UserDefaults.standard.set("large", forKey: "story_font_size")
        UserDefaults.standard.set("wide", forKey: "story_line_spacing")
        page.view.frame.size.width = 300
        let secondHTML = draw(page)

        XCTAssertTrue(firstHTML.contains("Fixture body"))
        XCTAssertFalse(firstHTML.contains("Updated title"))
        XCTAssertTrue(secondHTML.contains("Updated title"))
        XCTAssertTrue(secondHTML.contains("Updated comments"))
        XCTAssertTrue(secondHTML.contains("Updated text view"))
        XCTAssertTrue(secondHTML.contains("font-family: ChronicleSSm-Book"))
        XCTAssertTrue(secondHTML.contains("NB-large"))
        XCTAssertTrue(secondHTML.contains("NB-line-spacing-wide"))
        XCTAssertTrue(secondHTML.contains("NB-width-300"))
        XCTAssertFalse(secondHTML.contains("Fixture body"))

        page.inTextView = false
        let storyHTML = draw(page)
        XCTAssertTrue(storyHTML.contains("Updated body with <em>formatting</em>"))
        XCTAssertFalse(storyHTML.contains("Updated text view"))
    }

    func test_benchmarkTenWarmStoryHTMLPreparations() {
        let page = makePage()
        _ = draw(page)
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTClockMetric()], options: options) {
            for index in 0..<10 {
                page.activeStory["story_hash"] = "benchmark-\(index)"
                page.drawStory()
            }
        }
    }

    private func makePage(storyHash: String = "fixture") -> StaticAssetStoryPage {
        let appDelegate = NewsBlurAppDelegate()
        appDelegate.storiesCollection = StoriesCollection()
        appDelegate.isPremium = true
        let page = StaticAssetStoryPage()
        page.appDelegate = appDelegate
        page.activeStory = ["story_hash": storyHash, "story_feed_id": 1,
                            "story_title": "Fixture title", "story_content": "<p>Fixture body</p>"]
        page.loadViewIfNeeded()
        return page
    }

    private func draw(_ page: StaticAssetStoryPage) -> String {
        page.drawStory()
        return page.value(forKey: "fullStoryHTML") as? String ?? ""
    }

    private func setTheme(_ theme: String) {
        let dark = theme == "medium" || theme == "dark"
        UserDefaults.standard.set(dark ? "dark" : "light", forKey: "theme_style")
        UserDefaults.standard.set(theme, forKey: dark ? "theme_dark" : "theme_light")
    }

    private func readResource(_ name: String, extension fileExtension: String) throws -> String {
        let path = try XCTUnwrap(Bundle.main.path(forResource: name, ofType: fileExtension))
        return try String(contentsOfFile: path, encoding: .utf8)
    }
}

@MainActor private final class StaticAssetStoryPage: StoryDetailViewController {
    var commentText = "Fixture comments"
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)) }
    override func viewDidLoad() {}
    override func viewWillLayoutSubviews() {}
    override func getHeader() -> String! { activeStory["story_title"] as? String }
    override func getShareBar() -> String! { "Fixture sharing" }
    override func getComments() -> String! { commentText }

    // StoryDetailAssetPerformanceTests.swift intercepts deferred WebKit work while exercising the real drawStory HTML preparation.
    @objc(getSideOptions) func fixtureSideOptions() -> String { "Fixture options" }
    @objc(loadHTMLString:) func fixtureLoadHTML(_ html: String) {}
    @objc(loadStory) func fixtureLoadStory() {}
}

private final class StaticAssetReadSpy {
    static var readPaths: [String] = []
    private let original: Method
    private let replacement: Method
    private let originalData: Method
    private let replacementData: Method
    private var restored = false

    init() throws {
        original = try XCTUnwrap(class_getClassMethod(NSString.self, NSSelectorFromString("stringWithContentsOfFile:encoding:error:")))
        replacement = try XCTUnwrap(class_getClassMethod(NSString.self, NSSelectorFromString("nb_test_assetStringWithContentsOfFile:encoding:error:")))
        originalData = try XCTUnwrap(class_getClassMethod(NSData.self, NSSelectorFromString("dataWithContentsOfFile:")))
        replacementData = try XCTUnwrap(class_getClassMethod(NSData.self, NSSelectorFromString("nb_test_assetDataWithContentsOfFile:")))
        Self.readPaths = []
        method_exchangeImplementations(original, replacement)
        method_exchangeImplementations(originalData, replacementData)
    }

    func restore() {
        guard !restored else { return }
        restored = true
        method_exchangeImplementations(original, replacement)
        method_exchangeImplementations(originalData, replacementData)
    }

    deinit { restore() }
}

private extension NSData {
    @objc(nb_test_assetDataWithContentsOfFile:)
    dynamic class func testAssetData(contentsOfFile path: String) -> NSData? {
        if Thread.isMainThread, path.hasPrefix(Bundle.main.bundlePath), (path as NSString).pathExtension == "otf" {
            StaticAssetReadSpy.readPaths.append((path as NSString).lastPathComponent)
        }
        return testAssetData(contentsOfFile: path)
    }
}

private extension NSString {
    @objc(nb_test_assetStringWithContentsOfFile:encoding:error:)
    dynamic class func testAssetString(contentsOfFile path: String, encoding: UInt, error: NSErrorPointer) -> NSString? {
        if Thread.isMainThread, path.hasPrefix(Bundle.main.bundlePath), ["css", "js"].contains((path as NSString).pathExtension) {
            StaticAssetReadSpy.readPaths.append((path as NSString).lastPathComponent)
        }
        return testAssetString(contentsOfFile: path, encoding: encoding, error: error)
    }
}
