import XCTest
import UIKit
import ObjectiveC.runtime

@testable import NewsBlur

@MainActor final class Test_StoryTextLayoutPerformance: XCTestCase {
    private let defaults = UserDefaults.standard
    private let keys = ["theme_style", "theme_light", "theme_dark", "feed_list_spacing",
                        "story_list_preview_images_size", "story_list_preview_text_size"]
    private var saved: [String: Any] = [:]
    private let title = "Layout fixture: 数学と科学 العربية हिन्दी 한글 ∑ 👩🏽‍🔬 e\u{301}"
    private let preview = "Layout fixture preview: 漢字と仮名 العربية हिन्दी 한글 ∑∞≠ 👨‍👩‍👧‍👦 café e\u{301}. "
        + "A longer paragraph preserves the exact line breaks and truncation of the current reader."

    override func setUp() {
        super.setUp()
        for key in keys { saved[key] = defaults.object(forKey: key) }
        defaults.set("medium", forKey: "story_list_preview_text_size")
        defaults.set("comfortable", forKey: "feed_list_spacing")
        defaults.set("none", forKey: "story_list_preview_images_size")
    }

    override func tearDown() {
        for key in keys {
            if let value = saved[key] { defaults.set(value, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }
        saved.removeAll()
        super.tearDown()
    }

    func test_prefetchMeasuresActualUpcomingUnicodeTextAwayFromMainThread() throws {
        let fixture = makeFixture()
        let prefetcher = try XCTUnwrap(fixture.controller as? UITableViewDataSourcePrefetching,
            "Native rows should prepare their actual text before the first visible draw.")
        let measured = expectation(description: "Title and preview measured on the worker")
        measured.expectedFulfillmentCount = 2
        let probe = try TextMeasurementProbe(matching: [title, preview]) { isMain in
            if !isMain { measured.fulfill() }
        }
        defer { probe.restore() }

        prefetcher.tableView(fixture.table, prefetchRowsAt: [IndexPath(row: 0, section: 0)])
        wait(for: [measured], timeout: 5)
        // StoryTextLayoutPerformanceTests.swift lets the worker publish its scalar result before drawing.
        let published = expectation(description: "Worker result publication")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { published.fulfill() }
        wait(for: [published], timeout: 1)
        let beforeDraw = probe.counts
        let cell = try XCTUnwrap(fixture.controller.tableView(fixture.table,
            cellForRowAt: IndexPath(row: 0, section: 0)) as? FeedDetailTableCell)
        cell.setValue(fixture.app, forKey: "appDelegate")
        let height = fixture.controller.tableView(fixture.table, heightForRowAt: IndexPath(row: 0, section: 0))
        _ = render(cell, app: fixture.app, size: CGSize(width: 390, height: height))

        XCTAssertEqual(beforeDraw.main, 0)
        XCTAssertEqual(beforeDraw.worker, 2)
        XCTAssertEqual(probe.counts.main, 0, "A prepared first draw must not repeat either boundingRect on main.")
    }

    func test_reusingStoryHashWithChangedTextCannotRetainOldGeometry() throws {
        let app = TextLayoutAppDelegate()
        app.fontDescriptorTitleSize = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption1).withSize(13)
        let cell = makeCell(app: app)
        cell.storyTitle = "A short title"
        cell.storyContent = "Short preview."
        let view = makeContentView(cell, app: app, size: CGSize(width: 320, height: 200))
        _ = bitmap(view)
        cell.storyTitle = title + title
        cell.storyContent = preview
        let actual = bitmap(view)
        let reference = try withOldLayout { bitmap(makeContentView(cell, app: app, size: view.bounds.size)) }
        XCTAssertEqual(actual, reference, "The same story hash can receive a replacement title and preview.")
    }

    func test_currentCellPixelsAndSizesMatchOriginalLayoutAcrossSupportedPresentation() throws {
        let app = TextLayoutAppDelegate()
        var cases = 0
        for theme in ["light", "sepia", "medium", "dark"] {
            defaults.set(theme, forKey: "theme_style")
            for pointSize: CGFloat in [10, 12, 13, 16, 18] {
                app.fontDescriptorTitleSize = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption1).withSize(pointSize)
                for width: CGFloat in [320, 390, 768] {
                    for spacing in ["compact", "comfortable"] {
                        defaults.set(spacing, forKey: "feed_list_spacing")
                        for imageStyle in ["none", "small_left", "small_right", "large_left", "large_right"] {
                            defaults.set(imageStyle, forKey: "story_list_preview_images_size")
                            let cell = makeCell(app: app)
                            cell.textSize = FeedDetailTextSize(rawValue: UInt(cases % 4))!
                            cell.isShort = cases % 3 == 0
                            cell.isRiverOrSocial = cases % 2 == 0
                            cell.isRead = cases % 3 == 1
                            cell.isSaved = cases % 7 == 0
                            cell.isShared = cases % 11 == 0
                            cell.isHighlighted = cases % 5 == 0
                            if cell.textSize.rawValue == 0 { cell.storyContent = nil }
                            app.image = cases % 4 == 0 ? nil : fixtureImage()
                            let size = CGSize(width: width, height: cell.isShort ? 110 : 190)
                            let actualView = makeContentView(cell, app: app, size: size)
                            let actualPixels = bitmap(actualView)
                            let actualSizes = layoutSizes(actualView)
                            let expected = try withOldLayout { () -> (Data, [NSValue]) in
                                let view = makeContentView(cell, app: app, size: size)
                                return (bitmap(view), layoutSizes(view))
                            }
                            let context = "\(theme) \(pointSize)pt \(width) \(spacing) \(imageStyle) case \(cases)"
                            XCTAssertEqual(actualSizes, expected.1, context)
                            XCTAssertEqual(actualPixels, expected.0, context)
                            cases += 1
                        }
                    }
                }
            }
        }
        XCTAssertEqual(cases, 600)
    }

    func test_clusterCellsKeepTheirDistinctDrawingPath() throws {
        let app = TextLayoutAppDelegate()
        app.fontDescriptorTitleSize = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption1).withSize(13)
        for theme in ["light", "sepia", "medium", "dark"] {
            defaults.set(theme, forKey: "theme_style")
            for tier in ["title", "semantic"] {
                let cell = makeCell(app: app)
                cell.isClusterStory = true
                cell.clusterTier = tier
                app.image = fixtureImage()
                let view = makeContentView(cell, app: app, size: CGSize(width: 390, height: 42))
                let actual = bitmap(view)
                let expected = try withOldLayout { bitmap(makeContentView(cell, app: app, size: view.bounds.size)) }
                XCTAssertEqual(actual, expected)
                XCTAssertNil(view.value(forKey: "cachedRegularLayoutKey"))
            }
        }
    }

    private func makeFixture() -> (controller: TextLayoutController, table: UITableView, app: TextLayoutAppDelegate) {
        let app = TextLayoutAppDelegate()
        app.isPremium = true
        app.recentlyReadStories = NSMutableDictionary()
        app.dictFeeds = ["1": ["id": 1, "feed_title": "Text layout", "active": 1]]
        let stories = StoriesCollection()
        stories.appDelegate = app
        stories.isRiverView = true
        stories.setStories([["story_hash": "layout-fixture", "story_feed_id": 1,
                             "story_title": title, "story_content": preview,
                             "story_authors": "Author", "short_parsed_date": "3m",
                             "story_timestamp": 1_800_000_000, "read_status": 0,
                             "intelligence": ["feed": 0, "title": 0, "author": 0, "tags": 0]]])
        let controller = TextLayoutController()
        controller.appDelegate = app
        controller.storiesCollection = stories
        let table = UITableView(frame: CGRect(x: 0, y: 0, width: 390, height: 780), style: .plain)
        controller.storyTitlesTable = table
        controller.view = UIView(frame: table.frame)
        controller.messageView = UIView()
        controller.messageView.isHidden = true
        controller.textSize = FeedDetailTextSize(rawValue: 2)!
        controller.setValue([["type": 0, "story_location": 0]], forKey: "visibleStoryRows")
        let previews = NSCache<NSString, NSString>()
        previews.setObject(preview as NSString, forKey: "layout-fixture")
        controller.setValue(previews, forKey: "storyPreviewTextCache")
        app.fontDescriptorTitleSize = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption1).withSize(13)
        return (controller, table, app)
    }

    private func makeCell(app: TextLayoutAppDelegate) -> FeedDetailTableCell {
        let cell = FeedDetailTableCell(style: .default, reuseIdentifier: "TextLayoutFixture")
        cell.setValue(app, forKey: "appDelegate")
        cell.storyHash = "layout-fixture"
        cell.storyTitle = title
        cell.storyContent = preview
        cell.storyDate = "3m"
        cell.siteTitle = "Text layout"
        cell.siteFavicon = fixtureImage()
        cell.feedColorBar = .blue
        cell.feedColorBarTopBorder = .cyan
        cell.textSize = FeedDetailTextSize(rawValue: 2)!
        return cell
    }

    private func makeContentView(_ cell: FeedDetailTableCell, app: NewsBlurAppDelegate, size: CGSize) -> FeedDetailTableCellView {
        let view = FeedDetailTableCellView(frame: CGRect(origin: .zero, size: size))
        view.cell = cell
        view.appDelegate = app
        return view
    }

    private func render(_ cell: FeedDetailTableCell, app: NewsBlurAppDelegate, size: CGSize) -> Data {
        bitmap(makeContentView(cell, app: app, size: size))
    }

    private func bitmap(_ view: FeedDetailTableCellView) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { _ in view.draw(view.bounds) }
        return image.cgImage!.dataProvider!.data! as Data
    }

    private func layoutSizes(_ view: FeedDetailTableCellView) -> [NSValue] {
        [view.value(forKey: "cachedRegularTitleSize") as! NSValue,
         view.value(forKey: "cachedRegularContentSize") as! NSValue,
         NSNumber(value: view.value(forKey: "cachedRegularContentGap") as! Double)]
    }

    private func fixtureImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 20, height: 30)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 30))
        }
    }

    private func withOldLayout<T>(_ body: () throws -> T) throws -> T {
        let selector = NSSelectorFromString("updateRegularLayoutCacheWithBounds:contentRect:fontDescriptor:paragraphStyle:comfortMargin:riverPadding:hasCachedImage:")
        let method = try XCTUnwrap(class_getInstanceMethod(FeedDetailTableCellView.self, selector))
        let original = method_getImplementation(method)
        let block: @convention(block) (FeedDetailTableCellView, CGRect, CGRect, UIFontDescriptor,
                                      NSMutableParagraphStyle, CGFloat, CGFloat, Bool) -> Void = { view, bounds, rect, descriptor, style, margin, river, _ in
            let cell = view.cell!
            let titleFont = UIFont(name: "WhitneySSm-Medium", size: descriptor.pointSize + 1)!
            var titleRows: CGFloat = cell.isShort ? 1.5 : 4
            if !cell.isShort && cell.textSize.rawValue >= 2 {
                titleRows = min((bounds.height - 24) / titleFont.pointSize - 2, 4)
            }
            let title = (cell.storyTitle ?? "") as NSString
            let options: NSStringDrawingOptions = [.truncatesLastVisibleLine, .usesLineFragmentOrigin]
            let titleSize = title.boundingRect(with: CGSize(width: rect.width, height: titleFont.pointSize * titleRows),
                options: options, attributes: [.font: titleFont, .paragraphStyle: style], context: nil).size
            var contentSize = CGSize.zero
            var gap: CGFloat = 0
            if let content = cell.storyContent, !content.isEmpty {
                let font = UIFont(name: "WhitneySSm-Book", size: descriptor.pointSize - 1)!
                var rows: CGFloat = cell.isShort ? 1.5 : 3
                if !cell.isShort && cell.textSize.rawValue >= 2 {
                    rows = max(3, (bounds.height - 30 - margin - (14 + river + titleSize.height)) / font.pointSize)
                }
                contentSize = (content as NSString).boundingRect(with: CGSize(width: rect.width, height: font.pointSize * rows),
                    options: options, attributes: [.font: font, .paragraphStyle: style], context: nil).size
                gap = max((bounds.height - 18 - margin - (cell.isRiverOrSocial ? river : 0)
                    - titleSize.height - contentSize.height) / 3, 2)
            }
            view.setValue(NSValue(cgSize: titleSize), forKey: "cachedRegularTitleSize")
            view.setValue(NSValue(cgSize: contentSize), forKey: "cachedRegularContentSize")
            view.setValue(gap, forKey: "cachedRegularContentGap")
        }
        let replacement = imp_implementationWithBlock(block)
        method_setImplementation(method, replacement)
        defer {
            method_setImplementation(method, original)
            imp_removeBlock(replacement)
        }
        return try body()
    }
}

private final class TextLayoutAppDelegate: NewsBlurAppDelegate {
    var image: UIImage?
    override func getFavicon(_ feedId: String!) -> UIImage! { nil }
    override func cachedImage(forStoryHash storyHash: String!) -> UIImage! { image }
}

@MainActor private final class TextLayoutController: FeedDetailViewController {
    override var isLegacyTable: Bool { true }
    override var isDashboard: Bool { false }
    override func viewDidLoad() {}
    override func checkScroll() {}
}

private final class TextMeasurementProbe {
    private let method: Method
    private let original: IMP
    private let replacement: IMP
    private var restored = false
    var counts: (main: Int, worker: Int) { countsRecorder!.counts }

    init(matching strings: Set<String>, measured: @escaping (Bool) -> Void) throws {
        let selector = NSSelectorFromString("boundingRectWithSize:options:attributes:context:")
        method = try XCTUnwrap(class_getInstanceMethod(NSString.self, selector))
        original = method_getImplementation(method)
        typealias Function = @convention(c) (NSString, Selector, CGSize, UInt, NSDictionary?, NSStringDrawingContext?) -> CGRect
        let function = unsafeBitCast(original, to: Function.self)
        // StoryTextLayoutPerformanceTests.swift uses a separate recorder so the block cannot retain an uninitialized self.
        let recorder = TextMeasurementCounts()
        let block: @convention(block) (NSString, CGSize, UInt, NSDictionary?, NSStringDrawingContext?) -> CGRect = { text, size, options, attributes, context in
            let result = function(text, selector, size, options, attributes, context)
            if strings.contains(text as String) {
                recorder.record(main: Thread.isMainThread)
                measured(Thread.isMainThread)
            }
            return result
        }
        replacement = imp_implementationWithBlock(block)
        countsRecorder = recorder
        method_setImplementation(method, replacement)
    }

    private var countsRecorder: TextMeasurementCounts?
    func restore() {
        guard !restored else { return }
        restored = true
        method_setImplementation(method, original)
        imp_removeBlock(replacement)
    }
}

private final class TextMeasurementCounts {
    private let lock = NSLock()
    private var main = 0
    private var worker = 0
    func record(main isMain: Bool) {
        lock.lock()
        if isMain { main += 1 } else { worker += 1 }
        lock.unlock()
    }
    var counts: (main: Int, worker: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (main, worker)
    }
}
