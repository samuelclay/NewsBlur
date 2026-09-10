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
        defaults.set("light", forKey: "theme_light")
        defaults.set("dark", forKey: "theme_dark")
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

    func test_00_prefetchMeasuresActualUpcomingUnicodeTextAwayFromMainThread() throws {
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
        fixture.queue.sync {}
        let preparedAt = CACurrentMediaTime()
        let beforeDraw = probe.counts
        let cell = try XCTUnwrap(fixture.controller.tableView(fixture.table,
            cellForRowAt: IndexPath(row: 0, section: 0)) as? FeedDetailTableCell)
        cell.setValue(fixture.app, forKey: "appDelegate")
        let height = fixture.controller.tableView(fixture.table, heightForRowAt: IndexPath(row: 0, section: 0))
        let size = CGSize(width: 390, height: height)
        let pixels = render(cell, app: fixture.app, size: size)
        print("TEXT_LAYOUT_BENCHMARK worker_layout_ms=\(probe.workerMilliseconds) first_cell_and_draw_ms=\((CACurrentMediaTime() - preparedAt) * 1_000) main_measurements=\(probe.counts.main) worker_measurements=\(probe.counts.worker)")

        XCTAssertEqual(beforeDraw.main, 0)
        XCTAssertEqual(beforeDraw.worker, 2)
        XCTAssertEqual(probe.counts.main, 0, "A prepared first draw must not repeat either boundingRect on main.")
        let oldPixels = try withOldLayout { render(cell, app: fixture.app, size: size) }
        XCTAssertEqual(pixels, oldPixels)
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
        let queue = DispatchQueue(label: "test.story-text-layout.parity")
        let cache = StoryTextLayoutCache(worker: queue)
        let probe = try TextMeasurementProbe(matching: [title, preview]) { _ in }
        defer { probe.restore() }
        var cases = 0
        for theme in ["light", "sepia", "medium", "dark"] {
            defaults.set(theme, forKey: "theme_style")
            for pointSize: CGFloat in [10, 11, 12, 13, 14, 16, 18, 23, 36] {
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
                            cell.storyTextLayoutCache = cache
                            cache.prefetch([layoutRequest(cell, size: size, app: app, spacing: spacing, imageStyle: imageStyle)],
                                           identifier: "parity-row")
                            queue.sync {}
                            let actualView = makeContentView(cell, app: app, size: size)
                            let mainBefore = probe.counts.main
                            let actualPixels = bitmap(actualView)
                            XCTAssertEqual(probe.counts.main, mainBefore, "A prepared matrix case should not measure during drawRect.")
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
        XCTAssertEqual(cases, 1_080)
    }

    func test_prefetchDoesNotNormalizeMissingHTMLOnMain() throws {
        let fixture = makeFixture()
        let previews = try XCTUnwrap(fixture.controller.value(forKey: "storyPreviewTextCache") as? NSCache<NSString, NSString>)
        previews.removeAllObjects()
        let prefetcher = try XCTUnwrap(fixture.controller as? UITableViewDataSourcePrefetching)
        prefetcher.tableView(fixture.table, prefetchRowsAt: [IndexPath(row: 0, section: 0)])
        fixture.queue.sync {}
        XCTAssertEqual(fixture.controller.normalizations, 0)
        XCTAssertEqual(fixture.cache.cachedEntryCount, 0)
    }

    func test_prefetchIgnoresClusterAndLoadingRows() throws {
        let fixture = makeFixture()
        fixture.controller.setValue([
            ["type": 0, "story_location": 0],
            ["type": 1, "story_location": 0, "cluster_story": ["story_title": title]]
        ], forKey: "visibleStoryRows")
        let prefetcher = try XCTUnwrap(fixture.controller as? UITableViewDataSourcePrefetching)
        prefetcher.tableView(fixture.table, prefetchRowsAt: [IndexPath(row: 1, section: 0), IndexPath(row: 2, section: 0)])
        fixture.queue.sync {}
        XCTAssertEqual(fixture.cache.cachedEntryCount, 0)
    }

    func test_nativeCancellationAndSizingResetCancelQueuedLayouts() throws {
        let fixture = makeFixture()
        let prefetcher = try XCTUnwrap(fixture.controller as? UITableViewDataSourcePrefetching)
        let paths = [IndexPath(row: 0, section: 0)]
        fixture.queue.suspend()
        prefetcher.tableView(fixture.table, prefetchRowsAt: paths)
        XCTAssertEqual(fixture.cache.pendingRowCount, 1)
        prefetcher.tableView?(fixture.table, cancelPrefetchingForRowsAt: paths)
        XCTAssertEqual(fixture.cache.pendingRowCount, 0)
        prefetcher.tableView(fixture.table, prefetchRowsAt: paths)
        fixture.controller.perform(NSSelectorFromString("clearStoryRenderCaches"))
        XCTAssertEqual(fixture.cache.pendingRowCount, 0)
        fixture.queue.resume()
        fixture.queue.sync {}
        XCTAssertEqual(fixture.cache.cachedEntryCount, 0)
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

    private func makeFixture() -> (controller: TextLayoutController, table: UITableView, app: TextLayoutAppDelegate,
                                  queue: DispatchQueue, cache: StoryTextLayoutCache) {
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
        let queue = DispatchQueue(label: "test.story-text-layout.prefetch")
        let cache = StoryTextLayoutCache(worker: queue)
        controller.setValue(cache, forKey: "storyTextLayoutCache")
        app.fontDescriptorTitleSize = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption1).withSize(13)
        return (controller, table, app, queue, cache)
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

    private func layoutRequest(_ cell: FeedDetailTableCell, size: CGSize, app: NewsBlurAppDelegate,
                               spacing: String, imageStyle: String) -> StoryTextLayoutRequest {
        let style = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        style.lineBreakMode = .byWordWrapping
        style.alignment = .left
        style.lineHeightMultiple = CGFloat(Float(0.95))
        let margin: CGFloat = spacing == "compact" ? 0 : 10
        let hasImage = imageStyle != "none" && (app as! TextLayoutAppDelegate).image != nil
        return StoryTextLayoutRequest(title: (cell.storyTitle ?? "") as NSString,
            preview: (cell.storyContent ?? "") as NSString,
            contentWidth: StoryTextLayoutRequest.contentWidth(boundsWidth: size.width, imageStyle: imageStyle, hasImage: hasImage),
            boundsHeight: size.height, fontPointSize: app.fontDescriptorTitleSize.pointSize,
            textSize: Int(cell.textSize.rawValue), shortTitles: cell.isShort, river: cell.isRiverOrSocial,
            comfortMargin: margin, riverPadding: (cell.isRiverOrSocial ? 20 : -10) + margin,
            hasImage: hasImage, paragraphStyle: style)
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
    var normalizations = 0
    override var isLegacyTable: Bool { true }
    override var isDashboard: Bool { false }
    override func viewDidLoad() {}
    override func checkScroll() {}
    @objc(normalizedPreviewTextForStory:)
    func recordNormalization(_ story: NSDictionary) -> String {
        normalizations += 1
        return story["story_content"] as? String ?? ""
    }
}

private final class TextMeasurementProbe {
    private let method: Method
    private let original: IMP
    private let replacement: IMP
    private var restored = false
    var counts: (main: Int, worker: Int) { countsRecorder!.counts }
    var workerMilliseconds: Double { countsRecorder!.workerMilliseconds }

    init(matching strings: Set<String>, measured: @escaping (Bool) -> Void) throws {
        let selector = NSSelectorFromString("boundingRectWithSize:options:attributes:context:")
        method = try XCTUnwrap(class_getInstanceMethod(NSString.self, selector))
        original = method_getImplementation(method)
        typealias Function = @convention(c) (NSString, Selector, CGSize, UInt, NSDictionary?, NSStringDrawingContext?) -> CGRect
        let function = unsafeBitCast(original, to: Function.self)
        // StoryTextLayoutPerformanceTests.swift uses a separate recorder so the block cannot retain an uninitialized self.
        let recorder = TextMeasurementCounts()
        let block: @convention(block) (NSString, CGSize, UInt, NSDictionary?, NSStringDrawingContext?) -> CGRect = { text, size, options, attributes, context in
            let started = CACurrentMediaTime()
            let result = function(text, selector, size, options, attributes, context)
            if strings.contains(text as String) {
                recorder.record(main: Thread.isMainThread, milliseconds: (CACurrentMediaTime() - started) * 1_000)
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
    private var workerTime = 0.0
    func record(main isMain: Bool, milliseconds: Double) {
        lock.lock()
        if isMain { main += 1 } else { worker += 1; workerTime += milliseconds }
        lock.unlock()
    }
    var workerMilliseconds: Double {
        lock.lock()
        defer { lock.unlock() }
        return workerTime
    }
    var counts: (main: Int, worker: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (main, worker)
    }
}
