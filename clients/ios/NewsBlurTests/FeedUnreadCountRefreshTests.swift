import XCTest
import UIKit

@testable import NewsBlur

@MainActor final class Test_FeedUnreadCountRefresh: XCTestCase {
    #if targetEnvironment(macCatalyst)
    func test_sidebarOuterMarginsRemainStableWhenNativeSidebarInsetsArrive() async throws {
        // FeedUnreadCountRefreshTests.swift measures in table coordinates because Catalyst can inset the whole row or header later.
        // Adding a fixed inset inside an already inset sidebar row doubles the visible margin after activation.
        let fixture = try makeFixture()
        fixture.controller.suppliesFolderHeaders = true
        fixture.table.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        fixture.table.reloadData()
        fixture.table.layoutIfNeeded()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        var geometry = [String]()
        defer {
            fixture.controller.reloadWorkItem?.cancel()
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
            let attachment = XCTAttachment(string: geometry.joined(separator: "\n"))
            attachment.name = "sidebar-native-inset-lifecycle"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        func margins(_ stage: String, layoutTable: Bool = true) throws -> [CGFloat] {
            if layoutTable { fixture.table.layoutIfNeeded() }
            let cell = try fixture.cell(row: 0)
            let content = try XCTUnwrap(cell.value(forKey: "cellContent") as? UIView)
            let header = try XCTUnwrap(fixture.controller.measuredFolderHeader)
            _ = renderedImage(of: cell)
            _ = renderedImage(of: header)
            let target = try XCTUnwrap(header.invisibleHeaderButton)
            let rowRect = content.convert(content.bounds, to: fixture.table)
            let headerRect = target.convert(target.bounds, to: fixture.table)
            geometry.append("\(stage): table=\(fixture.table.bounds) safe=\(fixture.table.safeAreaInsets) margins=\(fixture.table.layoutMargins) row=\(cell.frame) nativeContent=\(cell.contentView.frame) drawingInTable=\(rowRect) header=\(header.frame) targetInTable=\(headerRect)")
            return [rowRect.minX - fixture.table.bounds.minX - CGFloat(cell.indentationLevel) * cell.indentationWidth,
                    fixture.table.bounds.maxX - rowRect.maxX,
                    headerRect.minX - fixture.table.bounds.minX,
                    fixture.table.bounds.maxX - headerRect.maxX]
        }
        let initial = try margins("before attachment")
        for margin in initial { XCTAssertGreaterThan(margin, 0) }
        let split = UISplitViewController(style: .doubleColumn)
        split.primaryBackgroundStyle = .none
        split.preferredDisplayMode = .oneBesideSecondary
        split.minimumPrimaryColumnWidth = 390
        split.maximumPrimaryColumnWidth = 390
        split.setViewController(UINavigationController(rootViewController: fixture.controller), for: .primary)
        split.setViewController(UIViewController(), for: .secondary)
        window.rootViewController = split
        window.makeKeyAndVisible()
        for stage in ["attached", "reactivated"] {
            if stage == "reactivated" {
                previousKeyWindow?.makeKey()
                await Task.yield()
                window.makeKey()
            }
            await Task.yield()
            window.layoutIfNeeded()
            fixture.table.frame = fixture.controller.view.bounds
            let current = try margins(stage)
            for (before, after) in zip(initial, current) {
                XCTAssertEqual(after, before, accuracy: 0.5, "\(stage): native sidebar insets must not add a second outer margin; \(geometry.last ?? "")")
            }
        }
        // FeedUnreadCountRefreshTests.swift replays the live Catalyst ancestor inset, which the isolated test window does not always deliver.
        // The runtime row remains at x0 in an inset ancestor, while its header is inset directly in table coordinates.
        let cell = try fixture.cell(row: 0)
        let nativeParent = UIView(frame: fixture.table.bounds)
        fixture.table.addSubview(nativeParent)
        let header = try XCTUnwrap(fixture.controller.measuredFolderHeader)
        let content = try XCTUnwrap(cell.value(forKey: "cellContent") as? UIView)
        for width: CGFloat in [390, 450, 300] {
            fixture.table.frame.size.width = width
            fixture.table.layoutIfNeeded()
            let nativeInset = initial[2]
            nativeParent.addSubview(cell)
            nativeParent.frame.origin.x = nativeInset
            nativeParent.frame.size.width = width - 2 * nativeInset
            cell.frame.origin.x = 0
            cell.frame.size.width = width - 2 * nativeInset
            cell.setNeedsLayout()
            cell.layoutIfNeeded()
            var headerInTable = header.convert(header.bounds, to: fixture.table)
            headerInTable.origin.x = fixture.table.bounds.minX + nativeInset
            headerInTable.size.width = width - 2 * nativeInset
            header.frame = try XCTUnwrap(header.superview).convert(headerInTable, from: fixture.table)
            let current = try margins("native ancestor inset at width \(width)", layoutTable: false)
            for (before, after) in zip(initial, current) {
                XCTAssertEqual(after, before, accuracy: 0.5, "Native row and header insets must count toward the existing margin; \(geometry.last ?? "")")
            }
            let drawingFrame = content.frame
            cell.contentView.transform = CGAffineTransform(translationX: 35, y: 0)
            cell.setNeedsLayout()
            cell.layoutIfNeeded()
            XCTAssertEqual(content.frame, drawingFrame, "Swiping the content must not recalculate the row's outer margins")
            cell.contentView.transform = .identity
        }
    }

    func test_feedRowLayoutIsReadyBeforePaintingAndSurvivesPartialRedraws() throws {
        // FeedUnreadCountRefreshTests.swift protects visible row alignment through first paint, reuse and native inset changes.
        // Sizing the drawing view from drawRect's dirty region delays indentation and shifts it again on a partial redraw.
        let fixture = try makeFixture()
        defer { fixture.controller.reloadWorkItem?.cancel() }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.rootViewController?.view.addSubview(fixture.controller.view)
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }
        fixture.table.layoutIfNeeded()
        let cell = try fixture.cell(row: 0)
        let drawingView = try XCTUnwrap(cell.value(forKey: "cellContent") as? UIView)
        var geometry = [String]()
        for (width, indentation, accessoryWidth) in [(CGFloat(390), 1, CGFloat(0)), (310, 0, 34), (450, 2, 0)] {
            fixture.table.frame.size.width = width
            fixture.table.layoutIfNeeded()
            cell.prepareForReuse()
            cell.indentationLevel = indentation
            cell.accessoryView = accessoryWidth > 0 ? UIView(frame: CGRect(x: 0, y: 0, width: accessoryWidth, height: 24)) : nil
            cell.setNeedsLayout()
            cell.layoutIfNeeded()
            let laidOut = drawingView.frame
            let laidOutInTable = drawingView.convert(drawingView.bounds, to: fixture.table)
            let leadingMargin = laidOutInTable.minX - fixture.table.bounds.minX - CGFloat(indentation) * cell.indentationWidth
            let trailingMargin = fixture.table.bounds.maxX - laidOutInTable.maxX
            XCTAssertGreaterThan(leadingMargin, 0, "The first layout must leave space outside the feed's content")
            XCTAssertGreaterThan(trailingMargin, 0, "The row must retain an outer trailing margin")
            if accessoryWidth == 0 {
                XCTAssertEqual(leadingMargin, trailingMargin, accuracy: 0.5,
                               "Folder indentation must be added inside equal outer margins")
            }
            geometry.append("before: cell=\(cell.bounds) nativeContent=\(cell.contentView.frame) drawing=\(laidOut)")
            _ = renderedImage(of: cell)
            let painted = drawingView.frame
            geometry.append("painted: nativeContent=\(cell.contentView.frame) drawing=\(painted)")
            XCTAssertEqual(laidOut, painted, "Painting must not introduce the row's margins or change its content geometry")
            XCTAssertTrue(cell.contentView.bounds.insetBy(dx: -0.5, dy: -0.5).contains(painted),
                          "Feed content must fit the region UIKit actually assigns, including native accessories")
            _ = UIGraphicsImageRenderer(bounds: cell.bounds).image { _ in
                cell.draw(CGRect(x: 7, y: 3, width: width / 2, height: cell.bounds.height - 6))
            }
            XCTAssertEqual(drawingView.frame, painted, "An activation or exposure redraw must not move the row content")
        }
        let attachment = XCTAttachment(string: geometry.joined(separator: "\n"))
        attachment.name = "feed-row-layout-and-paint-geometry"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func test_folderHitAreaTracksResizingWithoutWaitingForActivationAndSurvivesPartialRedraw() throws {
        // FeedUnreadCountRefreshTests.swift protects the folder's click target during resizing and partial activation redraws.
        // Waiting for an explicit redraw leaves the resized row stale; using its dirty region then shifts and shrinks the target.
        let fixture = try makeFixture()
        defer { fixture.controller.reloadWorkItem?.cancel() }
        let header = CountFolderTitle(frame: CGRect(x: 0, y: 0, width: 390, height: 44))
        header.fixtureApp = fixture.app
        header.section = 2
        var outerMargin: CGFloat?
        for width: CGFloat in [390, 300, 450] {
            header.frame.size.width = width
            _ = renderedImage(of: header)
            let button = try XCTUnwrap(header.invisibleHeaderButton)
            let target = button.convert(button.bounds, to: header)
            let leadingMargin = target.minX - header.bounds.minX
            let trailingMargin = header.bounds.maxX - target.maxX
            XCTAssertGreaterThan(leadingMargin, 0, "Folder selection must leave space beside the window edge")
            XCTAssertGreaterThan(trailingMargin, 0, "Folder selection must leave space beside the column edge")
            XCTAssertEqual(leadingMargin, trailingMargin, accuracy: 0.5,
                           "The click target must fill the inset content without counting its origin twice")
            if let outerMargin {
                XCTAssertEqual(leadingMargin, outerMargin, accuracy: 0.5, "Resizing must preserve the same outer margin")
            } else {
                outerMargin = leadingMargin
            }
            XCTAssertEqual(target.height, header.bounds.height, "The inset row remains clickable through its full height")
            _ = UIGraphicsImageRenderer(bounds: header.bounds).image { _ in
                header.draw(CGRect(x: 7, y: 3, width: width / 2, height: header.bounds.height - 6))
            }
            let redrawnButton = try XCTUnwrap(header.invisibleHeaderButton)
            XCTAssertEqual(redrawnButton.convert(redrawnButton.bounds, to: header), target,
                           "Redrawing the same folder must retain its click target across the whole row")
        }
    }
    #endif

    func test_articleUnreadMarkerDistinguishesOpeningFromExplicitMarkUnread() throws {
        // FeedUnreadCountRefreshTests.swift protects the Mac title from shifting when a prefetched unread article becomes read on focus.
        // Rendering the header from unread status alone would show a transient marker before that automatic read completes.
        let fixture = try makeFixture()
        defer { fixture.controller.reloadWorkItem?.cancel() }
        let article: [AnyHashable: Any] = ["story_hash": "article-marker", "story_feed_id": 1,
                                         "story_title": "An unread article", "read_status": 0,
                                         "intelligence": ["feed": 0]]
        let stories = makeCollection(fixture: fixture, story: article)
        fixture.app.activeStory = article
        let page = StoryDetailViewController()
        page.appDelegate = fixture.app
        page.activeStory = NSMutableDictionary(dictionary: article)
        fixture.pages.currentPage = page

        let initialHeader = try XCTUnwrap(page.getHeader())
        #if targetEnvironment(macCatalyst)
        XCTAssertFalse(initialHeader.contains("NB-story-unread"), "Opening an unread Mac article must not insert a marker that disappears on focus")
        #else
        XCTAssertTrue(initialHeader.contains("NB-story-unread"), "Keep the existing iPhone and iPad article behavior")
        #endif

        stories.markStoryRead(fixture.app.activeStory)
        page.setActiveStoryAt(-1)
        XCTAssertFalse(try XCTUnwrap(page.getHeader()).contains("NB-story-unread"))

        stories.markStoryUnread(fixture.app.activeStory)
        page.setActiveStoryAt(-1)
        XCTAssertTrue(try XCTUnwrap(page.getHeader()).contains("NB-story-unread"), "Explicitly marking the displayed story unread must show its marker")

        stories.markStoryRead(fixture.app.activeStory)
        page.setActiveStoryAt(-1)
        XCTAssertFalse(try XCTUnwrap(page.getHeader()).contains("NB-story-unread"), "Marking it read again must remove the explicit unread marker")

        stories.markStoryUnread(fixture.app.activeStory)
        page.setActiveStoryAt(-1)
        var nextArticle = article
        nextArticle["story_hash"] = "another-unread-article"
        page.activeStory = NSMutableDictionary(dictionary: nextArticle)
        #if targetEnvironment(macCatalyst)
        XCTAssertFalse(try XCTUnwrap(page.getHeader()).contains("NB-story-unread"), "Reusing the page for another unread article must not carry its previous story's explicit marker")
        #endif
    }

    func test_retainedArticleReadActionUpdatesItsFeedWithoutChangingBrowsedSource() throws {
        let fixture = try makeFixture()
        defer { fixture.controller.reloadWorkItem?.cancel() }
        let stories = StoriesCollection()
        stories.appDelegate = fixture.app
        stories.activeFeed = fixture.app.dictFeeds["2"] as? [AnyHashable: Any]
        let retained: [AnyHashable: Any] = ["story_hash": "retained-1", "story_feed_id": 1,
                                         "read_status": 0, "intelligence": ["feed": 0]]
        let browsed: [AnyHashable: Any] = ["story_hash": "browsed-2", "story_feed_id": 2,
                                        "read_status": 0, "intelligence": ["feed": 0]]
        stories.activeFeedStories = [browsed]
        stories.activeFeedStoryLocations = [0]
        stories.activeFeedStoryLocationIds = ["browsed-2"]
        stories.visibleUnreadCount = 1
        fixture.app.storiesCollection = stories
        fixture.app.activeStory = retained
        fixture.app.activeUsername = "retained-read-" + UUID().uuidString

        // FeedUnreadCountRefreshTests.swift models the mounted article after Duo's overlay switches to another source.
        stories.markStoryRead(retained)

        XCTAssertEqual(fixture.app.activeStory["read_status"] as? Int, 1)
        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? [String: Int])?["nt"], 9)
        XCTAssertEqual((fixture.app.dictUnreadCounts["2"] as? [String: Int])?["nt"], 1)
        XCTAssertEqual(stories.visibleUnreadCount, 1, "Reading the retained article must not decrement the browsed source")
        XCTAssertEqual(stories.activeFeedStories.count, 1)
        XCTAssertEqual((stories.activeFeedStories.first as? [String: Any])?["story_hash"] as? String, "browsed-2")
        XCTAssertEqual((stories.activeFeedStories.first as? [String: Any])?["read_status"] as? Int, 0)
        XCTAssertEqual(fixture.app.recentlyReadStories["retained-1"] as? Bool, true)
        XCTAssertEqual(try cachedReadStatus(retained, fixture: fixture), 1)
    }

    func test_retainedArticleUnreadAndReadUpdateSharedFeedsWithoutChangingBrowsedProgress() throws {
        let fixture = try makeFixture()
        defer { fixture.controller.reloadWorkItem?.cancel() }
        let retained: [AnyHashable: Any] = ["story_hash": "retained-1", "story_feed_id": 1,
                                         "read_status": 1, "intelligence": ["feed": 0], "shared_by_friends": [3]]
        let browsed: [AnyHashable: Any] = ["story_hash": "browsed-2", "story_feed_id": 2,
                                        "read_status": 0, "intelligence": ["feed": 0]]
        let stories = makeCollection(fixture: fixture, story: browsed)
        fixture.app.activeStory = retained
        fixture.app.originalStoryCount = 7
        fixture.app.recentlyReadStories["retained-1"] = true
        fixture.app.activeUsername = "retained-unread-" + UUID().uuidString
        let page = StoryDetailViewController()
        page.activeStory = NSMutableDictionary(dictionary: retained)
        fixture.pages.currentPage = page

        stories.markStoryUnread(retained)

        XCTAssertEqual(fixture.app.activeStory["read_status"] as? Int, 0)
        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? [String: Int])?["nt"], 11)
        XCTAssertEqual((fixture.app.dictUnreadCounts["social:3"] as? [String: Int])?["nt"], 6)
        XCTAssertNil(fixture.app.recentlyReadStories["retained-1"])
        XCTAssertEqual(try cachedReadStatus(retained, fixture: fixture), 0)
        XCTAssertTrue(page.isRecentlyUnread)
        XCTAssertEqual(stories.visibleUnreadCount, 1)
        XCTAssertEqual(fixture.app.originalStoryCount, 7)
        XCTAssertEqual(fixture.pages.navigationRefreshes, 0)
        XCTAssertEqual(stories.activeFeedStories as NSArray, [browsed] as NSArray)

        // FeedUnreadCountRefreshTests.swift repeats the reader action using its newly updated activeStory.
        stories.markStoryRead(fixture.app.activeStory)

        XCTAssertEqual(fixture.app.activeStory["read_status"] as? Int, 1)
        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? [String: Int])?["nt"], 10)
        XCTAssertEqual((fixture.app.dictUnreadCounts["social:3"] as? [String: Int])?["nt"], 5)
        XCTAssertEqual((fixture.app.dictUnreadCounts["2"] as? [String: Int])?["nt"], 1)
        XCTAssertEqual(try cachedReadStatus(retained, fixture: fixture), 1)
        XCTAssertFalse(page.isRecentlyUnread)
        XCTAssertEqual(stories.visibleUnreadCount, 1)
        XCTAssertEqual(fixture.app.originalStoryCount, 7)
        XCTAssertEqual(stories.activeFeedStories as NSArray, [browsed] as NSArray)
    }

    func test_dictionaryReadActionKeepsItsStoryWhenActiveStoryHasChanged() throws {
        let fixture = try makeFixture()
        defer { fixture.controller.reloadWorkItem?.cancel() }
        let supplied: [AnyHashable: Any] = ["story_hash": "retained-1", "story_feed_id": 1,
                                         "read_status": 0, "intelligence": ["feed": 0]]
        let browsed: [AnyHashable: Any] = ["story_hash": "browsed-2", "story_feed_id": 2,
                                        "read_status": 0, "intelligence": ["feed": 0]]
        let stories = makeCollection(fixture: fixture, story: browsed)
        fixture.app.activeStory = browsed

        stories.markStoryRead(supplied)

        XCTAssertEqual(fixture.app.activeStory as NSDictionary, browsed as NSDictionary)
        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? [String: Int])?["nt"], 9)
        XCTAssertEqual((fixture.app.dictUnreadCounts["2"] as? [String: Int])?["nt"], 1)
        XCTAssertEqual(fixture.app.recentlyReadStories["retained-1"] as? Bool, true)
        XCTAssertEqual(stories.visibleUnreadCount, 1)
        XCTAssertEqual(stories.activeFeedStories as NSArray, [browsed] as NSArray)
    }

    func test_idReadActionsResolveRetainedStoryAndIgnoreAnUnknownHash() throws {
        let fixture = try makeFixture()
        defer { fixture.controller.reloadWorkItem?.cancel() }
        let retained: [AnyHashable: Any] = ["story_hash": "retained-1", "story_feed_id": 1,
                                         "read_status": 0, "intelligence": ["feed": 0]]
        let browsed: [AnyHashable: Any] = ["story_hash": "browsed-2", "story_feed_id": 2,
                                        "read_status": 0, "intelligence": ["feed": 0]]
        let stories = makeCollection(fixture: fixture, story: browsed)
        fixture.app.activeStory = retained

        stories.markStoryRead("retained-1", feedId: 1)
        XCTAssertEqual(fixture.app.activeStory["read_status"] as? Int, 1)
        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? [String: Int])?["nt"], 9)
        stories.markStoryUnread("retained-1", feedId: 1)
        XCTAssertEqual(fixture.app.activeStory["read_status"] as? Int, 0)
        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? [String: Int])?["nt"], 10)
        stories.markStoryUnread("missing", feedId: 1)
        stories.markStoryRead("missing", feedId: 1)
        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? [String: Int])?["nt"], 10)
        XCTAssertEqual(stories.visibleUnreadCount, 1)
        XCTAssertEqual(stories.activeFeedStories as NSArray, [browsed] as NSArray)
    }

    func test_inListReadAndUnreadStillUpdateVisibleCountAndProgress() throws {
        let fixture = try makeFixture()
        defer { fixture.controller.reloadWorkItem?.cancel() }
        let listed: [AnyHashable: Any] = ["story_hash": "listed-1", "story_feed_id": 1,
                                       "read_status": 0, "intelligence": ["feed": 0], "story_title": "Current title"]
        let stories = makeCollection(fixture: fixture, story: listed)
        fixture.app.activeStory = listed
        fixture.app.originalStoryCount = 7
        var stale = listed
        stale["story_title"] = "Old title"

        stories.markStoryRead(stale)

        XCTAssertEqual(fixture.app.activeStory["read_status"] as? Int, 1)
        XCTAssertEqual(fixture.app.activeStory["story_title"] as? String, "Current title")
        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? [String: Int])?["nt"], 9)
        XCTAssertEqual(stories.visibleUnreadCount, 0)
        // FeedUnreadCountRefreshTests.swift expects NewsBlurAppDelegate.m to refresh Next/Done after a read, so Done appears at zero unread.
        XCTAssertEqual(fixture.pages.navigationRefreshes, 1)

        stories.markStoryUnread(fixture.app.activeStory)

        XCTAssertEqual(fixture.app.activeStory["read_status"] as? Int, 0)
        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? [String: Int])?["nt"], 10)
        XCTAssertEqual(stories.visibleUnreadCount, 1)
        XCTAssertEqual(fixture.app.originalStoryCount, 8)
        XCTAssertEqual(fixture.pages.navigationRefreshes, 2)
        XCTAssertEqual(stories.activeFeedStories as NSArray, [listed] as NSArray)
    }

    func test_refreshUpdatesEveryVisibleFeedAndDuplicateWithoutReloading() throws {
        let fixture = try makeFixture()
        let cells = try [0, 1, 2].map { try fixture.cell(row: $0) }
        let duplicate = try fixture.cell(row: 0, section: 3)
        let icons = cells.map { $0.value(forKey: "feedFavicon") as? UIImage }
        let offset = fixture.table.contentOffset
        let initialReads = fixture.app.iconReads
        fixture.app.dictUnreadCounts["1"] = ["nt": 4, "ps": 2, "ng": 1]
        fixture.app.dictUnreadCounts["2"] = ["nt": 0, "ps": 0, "ng": 0]
        fixture.app.dictUnreadCounts["social:3"] = ["nt": 3, "ps": 1, "ng": 0]
        fixture.controller.currentRowAtIndexPath = nil

        fixture.controller.refreshFeedCounts()

        XCTAssertEqual(cells[0].value(forKey: "neutralCount") as? Int, 4)
        XCTAssertEqual(cells[0].value(forKey: "positiveCount") as? Int, 2)
        XCTAssertEqual(cells[0].value(forKey: "negativeCount") as? Int, 1)
        XCTAssertEqual(duplicate.value(forKey: "neutralCount") as? Int, 4)
        XCTAssertEqual(cells[1].value(forKey: "neutralCount") as? Int, 0)
        XCTAssertEqual(cells[2].value(forKey: "neutralCount") as? Int, 3)
        XCTAssertEqual(cells[0].accessibilityLabel, "First feed, 4 unread stories")
        XCTAssertEqual(cells[1].accessibilityLabel, "Second feed")
        XCTAssertTrue(fixture.app.folderCountCache.count == 0)
        XCTAssertEqual(fixture.controller.headerRefreshes, 1)
        XCTAssertEqual(fixture.controller.reloads, 0)
        XCTAssertEqual(fixture.table.reloads, 0)
        XCTAssertEqual(fixture.table.rowReloads, 0)
        XCTAssertEqual(fixture.table.contentOffset, offset)
        XCTAssertEqual(fixture.app.iconReads, initialReads)
        for row in cells.indices {
            XCTAssertTrue(try fixture.cell(row: row) === cells[row])
            XCTAssertTrue(cells[row].value(forKey: "feedFavicon") as? UIImage === icons[row])
        }
    }

    func test_searchInactiveAndSavedRowsRetainTheirCountSemantics() throws {
        let fixture = try makeFixture()
        let search = try fixture.cell(row: 3)
        let inactive = try fixture.cell(row: 4)
        let saved = try fixture.cell(row: 5)
        fixture.app.dictUnreadCounts["1"] = ["nt": 99, "ps": 99, "ng": 99]
        fixture.app.dictUnreadCounts["4"] = ["nt": 99, "ps": 99, "ng": 99]
        fixture.app.dictUnreadCounts["saved:tag"] = ["nt": 0, "ps": 7, "ng": 0]

        fixture.controller.refreshFeedCounts()

        for cell in [search, inactive] {
            XCTAssertEqual(cell.value(forKey: "neutralCount") as? Int, 0)
            XCTAssertEqual(cell.value(forKey: "positiveCount") as? Int, 0)
        }
        XCTAssertEqual(saved.value(forKey: "positiveCount") as? Int, 7)
        XCTAssertEqual(saved.value(forKey: "neutralCount") as? Int, 0)
        XCTAssertEqual(fixture.table.reloads, 0)
    }

    func test_existingCellActuallyPaintsItsNewBadge() throws {
        let fixture = try makeFixture()
        let cell = try fixture.cell(row: 0)
        let before = renderedImage(of: cell)
        let badge = try XCTUnwrap(cell.value(forKey: "unreadCount") as? NSObject)
        XCTAssertEqual(badge.value(forKey: "ntCount") as? Int, 10)
        fixture.app.dictUnreadCounts["1"] = ["nt": 9, "ps": 3, "ng": 2]

        fixture.controller.refreshFeedCounts()
        let after = renderedImage(of: cell)

        XCTAssertEqual(badge.value(forKey: "ntCount") as? Int, 9, "FeedUnreadCountRefreshTests.swift must observe the badge actually drawn by the retained cell")
        XCTAssertNotEqual(before.pngData(), after.pngData())
        for (name, image) in [("feed-count-before", before), ("feed-count-after", after)] {
            let attachment = XCTAttachment(image: image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertEqual(fixture.table.reloads, 0)
    }

    func test_savedIntelligenceModeKeepsSavedCountInsteadOfUnreadBadge() throws {
        let fixture = try makeFixture(savedMode: true)
        let cell = try fixture.cell(row: 0)
        XCTAssertEqual(cell.value(forKey: "savedStoriesCount") as? Int, 8)
        fixture.app.dictUnreadCounts["1"] = ["nt": 0, "ps": 0, "ng": 0]
        fixture.controller.refreshFeedCounts()
        XCTAssertEqual(cell.value(forKey: "savedStoriesCount") as? Int, 8)
        XCTAssertEqual(cell.value(forKey: "neutralCount") as? Int, 0)
    }

    func test_markReadBeforeOpeningArticleUpdatesModelAndSidebar() async throws {
        let fixture = try makeFixture()
        let cell = try fixture.cell(row: 0)
        let stories = StoriesCollection()
        stories.appDelegate = fixture.app
        stories.activeFeedStories = [["story_hash": "count-1", "story_feed_id": 1, "read_status": 0,
                                     "intelligence": ["feed": 0]]]
        stories.activeFeedStoryLocations = [0]
        stories.activeFeedStoryLocationIds = ["count-1"]
        let refreshed = expectation(description: "Read updates reach feed counts before article pages exist")
        fixture.controller.onRefresh = { refreshed.fulfill() }
        XCTAssertNil(fixture.pages.currentPage)
        let story = try XCTUnwrap(stories.activeFeedStories.first as? [AnyHashable: Any])

        stories.markStoryRead(story)

        XCTAssertEqual((fixture.app.dictUnreadCounts["1"] as? [String: Int])?["nt"], 9)
        // FeedUnreadCountRefreshTests.swift waits on FeedsViewController.swift's throttled main-queue refresh, which a stalled simulator can delay for seconds.
        await fulfillment(of: [refreshed], timeout: SimulatorTestTiming.realWorkTimeout)
        XCTAssertEqual(cell.value(forKey: "neutralCount") as? Int, 9)
        XCTAssertFalse(fixture.pages.isViewLoaded)
        XCTAssertEqual(fixture.table.reloads, 0)
        fixture.controller.reloadWorkItem?.cancel()
    }

    func test_burstOfReadsCoalescesAndUsesLatestCounts() async throws {
        let fixture = try makeFixture()
        fixture.pages.previousPage = StoryDetailViewController()
        fixture.pages.currentPage = StoryDetailViewController()
        fixture.pages.nextPage = StoryDetailViewController()
        fixture.controller.lastFeedTitlesReloadTime = Date()
        let refreshed = expectation(description: "A reading burst refreshes the latest feed counts once")
        fixture.controller.onRefresh = { refreshed.fulfill() }
        let cell = try fixture.cell(row: 0)

        for count in stride(from: 9, through: 0, by: -1) {
            fixture.app.dictUnreadCounts["1"] = ["nt": count, "ps": 0, "ng": 0]
            fixture.app.finishMark(asRead: ["story_hash": "count-\(count)"])
        }
        await fulfillment(of: [refreshed], timeout: SimulatorTestTiming.realWorkTimeout)

        XCTAssertEqual(cell.value(forKey: "neutralCount") as? Int, 0)
        XCTAssertEqual(fixture.controller.refreshes, 1)
        XCTAssertEqual(fixture.table.reloads, 0)
        XCTAssertFalse(fixture.pages.isViewLoaded)
        fixture.controller.reloadWorkItem?.cancel()
    }

    func test_markUnreadWithoutArticlePagesStillRefreshesFeedVisibilityAndCount() throws {
        let fixture = try makeFixture()
        fixture.app.originalStoryCount = 3
        fixture.app.finishMark(asUnread: ["story_hash": "count-1"])
        XCTAssertEqual(fixture.app.originalStoryCount, 4)
        XCTAssertEqual(fixture.controller.reloads, 1)
        XCTAssertFalse(fixture.pages.isViewLoaded)
    }

    func test_partialArticlePagesStillUpdateTheirReadState() async throws {
        let fixture = try makeFixture()
        let page = StoryDetailViewController()
        page.activeStory = ["story_hash": "count-1"]
        page.isRecentlyUnread = true
        fixture.pages.currentPage = page
        let refreshed = expectation(description: "Missing neighbors do not skip feed refresh")
        fixture.controller.onRefresh = { refreshed.fulfill() }

        fixture.app.finishMark(asRead: ["story_hash": "count-1"])
        await fulfillment(of: [refreshed], timeout: SimulatorTestTiming.realWorkTimeout)

        XCTAssertFalse(page.isRecentlyUnread)
        XCTAssertEqual(fixture.pages.headerRefreshes, 1)
        XCTAssertFalse(page.isViewLoaded)
        fixture.controller.reloadWorkItem?.cancel()
    }

    private func makeCollection(fixture: CountFixture, story: [AnyHashable: Any]) -> StoriesCollection {
        let stories = StoriesCollection()
        stories.appDelegate = fixture.app
        stories.activeFeed = fixture.app.dictFeeds[String(describing: story["story_feed_id"]!)] as? [AnyHashable: Any]
        stories.activeFeedStories = [story]
        stories.activeFeedStoryLocations = [0]
        stories.activeFeedStoryLocationIds = [story["story_hash"]!]
        stories.visibleUnreadCount = story["read_status"] as? Int == 0 ? 1 : 0
        fixture.app.storiesCollection = stories
        return stories
    }

    private func cachedReadStatus(_ story: [AnyHashable: Any], fixture: CountFixture) throws -> Int? {
        let request = try XCTUnwrap(StoryFirstPageRequest(account: fixture.app.activeUsername, host: fixture.app.url,
                                                        url: fixture.app.url + "/reader/feed/1/?page=1"))
        let response = StoryFirstPageCache.shared.overlay(["stories": [story]], request: request, revision: 0)
        return (response["stories"] as? [[String: Any]])?.first?["read_status"] as? Int
    }

    private func makeFixture(savedMode: Bool = false) throws -> CountFixture {
        let app = CountAppDelegate()
        app.selectedIntelligence = savedMode ? 2 : 0
        app.dictFoldersArray = ["dashboard", "daily_briefing", "Feeds", "Duplicate"]
        app.dictFolders = ["dashboard": [], "daily_briefing": [],
                           "Feeds": [1, "2", "social:3", "1?query", 4, "saved:tag"], "Duplicate": ["1"]]
        app.dictSubfolders = [:]
        app.dictFeeds = ["1": ["id": 1, "feed_title": "First", "active": 1],
                         "2": ["id": "2", "feed_title": "Second", "active": 1],
                         "4": ["id": 4, "feed_title": "Inactive", "active": 1]]
        app.dictSocialFeeds = ["social:3": ["id": "social:3", "feed_title": "Friend", "active": 1]]
        app.dictSavedStoryTags = ["saved:tag": ["id": "tag", "feed_title": "Saved tag"]]
        app.dictSavedStoryFeedCounts = savedMode ? ["1": 8] : [:]
        app.dictUnreadCounts = ["1": ["nt": 10, "ps": 3, "ng": 2], "2": ["nt": 1, "ps": 0, "ng": 0],
                               "social:3": ["nt": 5, "ps": 2, "ng": 0], "4": ["nt": 5], "saved:tag": ["ps": 8]]
        app.dictInactiveFeeds = ["4": true]
        app.collapsedFolders = [:]
        app.folderCountCache = ["Feeds": ["nt": 100]]
        app.recentlyReadFeeds = []
        app.recentlyReadStories = [:]
        app.unreadStoryHashes = [:]
        let controller = CountFeedsController()
        controller.appDelegate = app
        controller.viewShowingAllFeeds = true
        controller.searchFeedIds = ["1", "2", "social:3", "1?query", "4"]
        controller.setValue(NSMutableDictionary(), forKey: "rowHeights")
        controller.setValue(NSMutableDictionary(), forKey: "folderTitleViews")
        let pages = CountPagesController()
        pages.appDelegate = app
        app.testFeeds = controller
        app.testPages = pages
        let table = CountTable(frame: CGRect(x: 0, y: 0, width: 390, height: 780), style: .plain)
        controller.view = UIView(frame: table.frame)
        controller.view.addSubview(table)
        controller.feedTitlesTable = table
        table.dataSource = controller
        table.delegate = controller
        table.reloadData()
        table.layoutIfNeeded()
        table.reloads = 0
        return CountFixture(app: app, controller: controller, pages: pages, table: table)
    }

    private func renderedImage(of view: UIView) -> UIImage {
        view.layoutIfNeeded()
        func displayPendingLayers(_ layer: CALayer) {
            layer.displayIfNeeded()
            layer.sublayers?.forEach(displayPendingLayers)
        }
        displayPendingLayers(view.layer)
        return UIGraphicsImageRenderer(bounds: view.bounds).image { context in
            view.layer.render(in: context.cgContext)
        }
    }
}

@MainActor private struct CountFixture {
    let app: CountAppDelegate
    let controller: CountFeedsController
    let pages: CountPagesController
    let table: CountTable

    func cell(row: Int, section: Int = 2) throws -> UITableViewCell {
        let cell = try XCTUnwrap(table.cellForRow(at: IndexPath(row: row, section: section)))
        XCTAssertTrue(cell.responds(to: NSSelectorFromString("neutralCount")))
        return cell
    }
}

private final class CountAppDelegate: NewsBlurAppDelegate {
    var iconReads = 0
    weak var testFeeds: CountFeedsController?
    weak var testPages: CountPagesController?
    let icon = UIImage()
    override var url: String! { "https://feed-count-fixture.invalid" }
    override var feedsViewController: FeedsViewController! {
        get { testFeeds }
        set {}
    }
    override var storyPagesViewController: StoryPagesViewController! {
        get { testPages }
        set {}
    }
    override func preparedFavicon(_ filename: String!, size: CGSize) -> UIImage! {
        iconReads += 1
        return icon
    }
}

@MainActor private final class CountFeedsController: FeedsViewController {
    var refreshes = 0
    var reloads = 0
    var headerRefreshes = 0
    var onRefresh: (() -> Void)?
    var suppliesFolderHeaders = false
    var measuredFolderHeader: CountFolderTitle?
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func refreshFeedCounts() {
        super.refreshFeedCounts()
        refreshes += 1
        onRefresh?()
    }
    override func refreshHeaderCounts() { headerRefreshes += 1 }
    override func reloadFeedTitlesTable() { reloads += 1 }
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 60 }
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        suppliesFolderHeaders && section == 2 ? 44 : 0
    }
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard suppliesFolderHeaders, section == 2 else { return nil }
        let header = CountFolderTitle(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 44))
        header.fixtureApp = appDelegate
        header.section = Int32(section)
        measuredFolderHeader = header
        return header
    }
}

@MainActor private final class CountPagesController: StoryPagesViewController {
    var headerRefreshes = 0
    var navigationRefreshes = 0
    override func reloadWidget() {}
    override func refreshHeaders() { headerRefreshes += 1 }
    override func setNextPreviousButtons() { navigationRefreshes += 1 }
}

@MainActor private final class CountFolderTitle: FolderTitleView {
    var fixtureApp: NewsBlurAppDelegate?
    override var appDelegate: NewsBlurAppDelegate! {
        get { super.appDelegate }
        set { super.appDelegate = fixtureApp ?? newValue }
    }
}

@MainActor private final class CountTable: UITableView {
    var reloads = 0
    var rowReloads = 0
    override func reloadData() { reloads += 1; super.reloadData() }
    override func reloadRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {
        rowReloads += 1
        super.reloadRows(at: indexPaths, with: animation)
    }
}
