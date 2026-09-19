import XCTest
import UIKit
import WebKit

@testable import NewsBlur

@MainActor final class Test_FeedToolbarLayout: XCTestCase {
    func test_duoArticleScrollIndicatorExcludesListHeaderAndKeepsBottomProtection() throws {
        let app = NewsBlurAppDelegate()
        let detail = DuoPhoneReaderLayout()
        detail.appDelegate = app
        app.detailViewController = detail
        let pages = DuoScrollingHeaderPages(nibName: nil, bundle: nil)
        pages.appDelegate = app
        detail.storyPagesViewController = pages
        let page = DuoScrollingHeaderPage(nibName: nil, bundle: nil)
        page.appDelegate = app
        page.loadViewIfNeeded()
        pages.currentPage = page
        page.view.frame.size = CGSize(width: 390, height: 669)
        let web = try XCTUnwrap(page.webView)
        web.frame = page.view.bounds
        let scroll = try XCTUnwrap(web.scrollView as? DuoScrollingHeaderScrollView)
        scroll.frame = web.bounds
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.contentSize = CGSize(width: 390, height: 1_511)
        web.addSubview(scroll)
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 25))
        page.feedTitleGradient = header
        web.addSubview(header)
        let window = DuoIndicatorWindow(frame: page.view.bounds)
        window.addSubview(page.view)
        window.isHidden = false
        defer {
            window.isHidden = true
            page.view.removeFromSuperview()
            page.webView = nil
            page.appDelegate = nil
            pages.currentPage = nil
            pages.appDelegate = nil
            detail.storyPagesViewController = nil
            detail.appDelegate = nil
            app.detailViewController = nil
        }

        func nativeVerticalIndicator() throws -> UIView {
            try XCTUnwrap(scroll.subviews.first {
                $0.bounds.width > 0 && $0.bounds.width <= 8 && $0.bounds.height > 20 &&
                $0.frame.maxX >= scroll.bounds.maxX - 12
            }, "The native scroll view must render its vertical indicator")
        }
        // FeedToolbarLayoutTests.swift measures the host screen's corner clearance separately from NewsBlur's header inset.
        scroll.simulatedSafeAreaInsets = .zero
        scroll.automaticallyAdjustsScrollIndicatorInsets = false
        scroll.verticalScrollIndicatorInsets = .zero
        scroll.flashScrollIndicators()
        scroll.layoutIfNeeded()
        let unobstructedIndicator = try nativeVerticalIndicator()
        let nativeMinimumTop = web.convert(unobstructedIndicator.bounds, from: unobstructedIndicator).minY
        XCTAssertLessThan(nativeMinimumTop, 58 + 10 + 2,
                          "The host must leave enough indicator travel to detect the unrelated 58pt story-list header")
        scroll.automaticallyAdjustsScrollIndicatorInsets = true

        for pose in [(vertical: true, compact: true), (vertical: true, compact: false),
                     (vertical: false, compact: false)] {
            detail.isCompact = pose.compact
            pages.verticalToolbar = pose.vertical
            for protectedTop in [CGFloat(0), 22] {
                window.protectedTop = protectedTop
                scroll.simulatedSafeAreaInsets = UIEdgeInsets(top: protectedTop + 58, left: 0, bottom: 34, right: 0)
                scroll.contentInset = UIEdgeInsets(top: protectedTop, left: 0, bottom: 0, right: 0)
                for headerHeight in [CGFloat(10), 25] {
                    header.frame.size.height = headerHeight
                    scroll.verticalScrollIndicatorInsets = UIEdgeInsets(top: headerHeight - 1, left: 0, bottom: 0, right: 0)
                    scroll.contentOffset = CGPoint(x: 0, y: -protectedTop)
                    page.updateFeedTitleGradientPosition()
                    scroll.flashScrollIndicators()
                    scroll.layoutIfNeeded()

                    XCTAssertFalse(scroll.automaticallyAdjustsScrollIndicatorInsets,
                                   "The independent Duo article must not inherit the story-list navigation bar's 58pt obstruction")
                    XCTAssertEqual(scroll.verticalScrollIndicatorInsets.top, protectedTop + headerHeight - 1, accuracy: 0.5)
                    XCTAssertEqual(scroll.verticalScrollIndicatorInsets.bottom, 34, accuracy: 0.5,
                                   "Removing the unrelated top obstruction must retain the window's real bottom protection")
                    XCTAssertEqual(scroll.horizontalScrollIndicatorInsets.bottom, 34, accuracy: 0.5,
                                   "The shared automatic-adjustment policy must also preserve horizontal indicator protection")
                    XCTAssertEqual(scroll.verticalScrollIndicatorInsets.right, 0, accuracy: 0.5,
                                   "The pager already excludes the native side toolbar")
                    let indicator = try nativeVerticalIndicator()
                    let topFrame = web.convert(indicator.bounds, from: indicator)
                    XCTAssertEqual(topFrame.minY, max(nativeMinimumTop, protectedTop + headerHeight + 2), accuracy: 1,
                                   "The native scrollbar must begin beside its own article header, not below the other column's title bar: \(pose)")

                    scroll.contentOffset.y = scroll.contentSize.height - scroll.bounds.height
                    scroll.flashScrollIndicators()
                    scroll.layoutIfNeeded()
                    let bottomFrame = web.convert(indicator.bounds, from: indicator)
                    XCTAssertLessThanOrEqual(bottomFrame.maxY, web.bounds.maxY - 34,
                                             "The scrollbar must stop above the device's protected bottom edge")
                }
            }
        }
    }

    func test_duoArticleIndicatorRestoresConventionalPhoneAndIPadPolicy() throws {
        for originallyAutomatic in [true, false] {
            let app = NewsBlurAppDelegate()
            let detail = DuoPhoneReaderLayout()
            detail.appDelegate = app
            app.detailViewController = detail
            let pages = DuoScrollingHeaderPages(nibName: nil, bundle: nil)
            pages.appDelegate = app
            detail.storyPagesViewController = pages
            let page = DuoScrollingHeaderPage(nibName: nil, bundle: nil)
            page.appDelegate = app
            page.loadViewIfNeeded()
            pages.currentPage = page
            let web = try XCTUnwrap(page.webView)
            let scroll = try XCTUnwrap(web.scrollView as? DuoScrollingHeaderScrollView)
            scroll.simulatedSafeAreaInsets = UIEdgeInsets(top: 58, left: 0, bottom: 34, right: 0)
            let originalInsets = UIEdgeInsets(top: 9, left: 2, bottom: 7, right: 3)
            let originalHorizontalInsets = UIEdgeInsets(top: 0, left: 4, bottom: 13, right: 5)
            scroll.verticalScrollIndicatorInsets = originalInsets
            scroll.horizontalScrollIndicatorInsets = originalHorizontalInsets
            scroll.automaticallyAdjustsScrollIndicatorInsets = originallyAutomatic
            let header = UIView(frame: CGRect(x: 0, y: 0, width: 360, height: 10))
            page.feedTitleGradient = header
            web.addSubview(header)
            defer {
                page.webView = nil
                page.appDelegate = nil
                pages.currentPage = nil
                pages.appDelegate = nil
                detail.storyPagesViewController = nil
                detail.appDelegate = nil
                app.detailViewController = nil
            }

            for legacy in [(phone: true, compact: true), (phone: false, compact: false)] {
                detail.simulatesPhone = true
                detail.isCompact = false
                pages.verticalToolbar = true
                page.updateFeedTitleGradientPosition()
                XCTAssertFalse(scroll.automaticallyAdjustsScrollIndicatorInsets)
                detail.simulatesPhone = legacy.phone
                detail.isCompact = legacy.compact
                pages.verticalToolbar = false
                page.updateFeedTitleGradientPosition()
                XCTAssertEqual(scroll.automaticallyAdjustsScrollIndicatorInsets, originallyAutomatic,
                               "Leaving Duo layout must restore the previous native indicator policy: \(legacy)")
                XCTAssertEqual(scroll.verticalScrollIndicatorInsets, originalInsets,
                               "Duo-only indicator geometry must not remain on a conventional phone or iPad")
                XCTAssertEqual(scroll.horizontalScrollIndicatorInsets, originalHorizontalInsets)
            }
        }
    }

    func test_activePagerDragResizePreservesSelectedArticleAndDocument() async throws {
        try await auditPagerResizeSelection(resizesViewport: true)
    }

    func test_freshPagerSwipeStillSelectsNextLoadedArticle() async throws {
        try await auditPagerResizeSelection(resizesViewport: false)
    }

    private func auditPagerResizeSelection(resizesViewport: Bool) async throws {
        let app = DuoPagerResizeApp()
        let detail = DuoPhoneReaderLayout()
        detail.appDelegate = app
        detail.isCompact = false
        app.detailViewController = detail
        app.readStories = NSMutableArray()
        let collection = StoriesCollection()
        collection.appDelegate = app
        collection.activeFeedStories = (0..<8).map {
            ["story_hash": "resize:\($0)", "story_title": "Article \($0)", "read_status": 1] as [String: Any]
        }
        collection.activeFeedStoryLocations = NSMutableArray(array: Array(0..<8))
        collection.activeFeedStoryLocationIds = NSMutableArray(array: (0..<8).map { "resize:\($0)" })
        collection.storyCount = 8
        collection.storyLocationsCount = 8
        app.storiesCollection = collection
        let pages = DuoPagerResizePages()
        pages.appDelegate = app
        detail.storyPagesViewController = pages
        pages.loadViewIfNeeded()
        let articles = (5...7).map { index -> DuoPagerResizePage in
            let page = DuoPagerResizePage()
            page.appDelegate = app
            page.loadViewIfNeeded()
            page.pageIndex = index
            page.activeStory = NSMutableDictionary(dictionary: collection.activeFeedStories[index] as! [AnyHashable: Any])
            page.activeStoryId = "resize:\(index)"
            page.hasStory = true
            page.view.frame.origin.x = CGFloat(index) * 474
            pages.scrollView.addSubview(page.view)
            return page
        }
        let selected = articles[1]
        let next = articles[2]
        pages.previousPage = articles[0]
        pages.currentPage = selected
        pages.nextPage = next
        pages.scrollingToPage = -1
        pages.scrollView.contentSize = CGSize(width: 8 * 474, height: 600)
        pages.scrollView.contentOffset = CGPoint(x: 6 * 474, y: 0)
        app.activeStory = collection.activeFeedStories[6] as? [AnyHashable: Any]
        let navigation = DuoPagerResizeNavigationDelegate()
        let loaded = expectation(description: "Three local pager documents loaded")
        loaded.expectedFulfillmentCount = articles.count
        navigation.didLoad = { loaded.fulfill() }
        var selectionObservation: NSKeyValueObservation?
        var observesPager = false
        defer {
            selectionObservation?.invalidate()
            pages.scrollView.delegate = nil
            if observesPager { pages.scrollView.removeObserver(pages, forKeyPath: "contentOffset") }
            for article in articles {
                article.webView.navigationDelegate = nil
                article.webView.stopLoading()
                article.view.removeFromSuperview()
                article.webView = nil
                article.appDelegate = nil
            }
            pages.currentPage = nil
            pages.nextPage = nil
            pages.previousPage = nil
            pages.appDelegate = nil
            detail.storyPagesViewController = nil
            detail.appDelegate = nil
            app.detailViewController = nil
            collection.appDelegate = nil
            app.storiesCollection = nil
        }
        for article in articles {
            article.webView.navigationDelegate = navigation
            article.webView.loadHTMLString("<html><body>Loaded article \(article.pageIndex)</body></html>", baseURL: nil)
        }
        await fulfillment(of: [loaded], timeout: 10)
        let originalDocument = try await selected.webView.evaluateJavaScript("document.body.innerText") as? String
        XCTAssertEqual(originalDocument, "Loaded article 6")
        let originalGeneration = selected.value(forKey: "storyLoadGeneration") as? UInt
        var changedHashes: [String] = []
        selectionObservation = app.observe(\.activeStory, options: [.old, .new]) { _, change in
            let oldHash = (change.oldValue ?? nil)?["story_hash"] as? String
            let newHash = (change.newValue ?? nil)?["story_hash"] as? String
            if oldHash != newHash { changedHashes.append(newHash ?? "nil") }
        }
        pages.scrollView.delegate = pages
        pages.scrollView.addObserver(pages, forKeyPath: "contentOffset", options: [.new], context: nil)
        observesPager = true
        pages.scrollViewWillBeginDragging(pages.scrollView)
        XCTAssertTrue(pages.isDraggingScrollview)

        if resizesViewport {
            // FeedToolbarLayoutTests.swift shrinks the rail-protected viewport while the pager still owns an unfinished drag.
            pages.scrollView.frame.size.width = 390
            pages.reorientPages()
            pages.scrollView.layoutIfNeeded()
            XCTAssertEqual(changedHashes, [], "A programmatic resize must never select a neighboring story, even transiently")
            XCTAssertEqual(app.activeStory?["story_hash"] as? String, "resize:6")
            XCTAssertTrue(pages.currentPage === selected, "Resizing must preserve the selected page controller")
            XCTAssertEqual(selected.pageIndex, 6)
            XCTAssertEqual(selected.activeStoryId, "resize:6")
            XCTAssertEqual(pages.scrollView.contentOffset.x, 6 * 390, accuracy: 0.5)
            XCTAssertEqual(selected.view.frame.minX, 6 * 390, accuracy: 0.5)
            XCTAssertEqual(selected.view.frame.width, 390, accuracy: 0.5)
            XCTAssertEqual(pages.value(forKey: "isRepositioningFirstPage") as? Bool, false,
                           "Relayout must restore ordinary gesture processing when it finishes")
            pages.setValue(true, forKey: "isRepositioningFirstPage")
            pages.reorientPages()
            XCTAssertEqual(pages.value(forKey: "isRepositioningFirstPage") as? Bool, true,
                           "Nested relayout must preserve its caller's repositioning guard")
            pages.setValue(false, forKey: "isRepositioningFirstPage")
            XCTAssertEqual(selected.value(forKey: "storyLoadGeneration") as? UInt, originalGeneration)
            let document = try await selected.webView.evaluateJavaScript("document.body.innerText") as? String
            XCTAssertEqual(app.activeStory?["story_hash"] as? String, "resize:6",
                           "A delayed resize callback must not leave the model on a different article than the document")
            XCTAssertEqual(document, originalDocument)
            XCTAssertEqual(selected.documentInvalidations, 0, "Relayout must not clear or redraw the loaded document")
        } else {
            // FeedToolbarLayoutTests.swift keeps real pager selection callbacks covered independently of layout preservation.
            pages.scrollView.contentOffset.x = 7 * 474
            pages.scrollViewDidScroll(pages.scrollView)
            pages.scrollViewDidEndDecelerating(pages.scrollView)
            XCTAssertEqual(app.activeStory?["story_hash"] as? String, "resize:7")
            XCTAssertTrue(pages.currentPage === next, "A new pager gesture must still promote the next loaded article")
            XCTAssertEqual(next.pageIndex, 7)
            XCTAssertEqual(next.activeStoryId, "resize:7")
            XCTAssertTrue(changedHashes.contains("resize:7"))
            let document = try await next.webView.evaluateJavaScript("document.body.innerText") as? String
            XCTAssertEqual(document, "Loaded article 7")
        }
    }

    func test_expandedPhonePagerDisablesSharedHeaderBlurAndRestoresOriginalEdgeEffect() throws {
        guard #available(iOS 26.0, *) else { throw XCTSkip("Native scroll edge effects require iOS26") }
        for originallyHidden in [false, true] {
            let app = NewsBlurAppDelegate()
            app.storiesCollection = StoriesCollection()
            let detail = DuoPhoneReaderLayout()
            detail.appDelegate = app
            app.detailViewController = detail
            let pages = DuoScrollingHeaderPages(nibName: nil, bundle: nil)
            pages.appDelegate = app
            detail.storyPagesViewController = pages
            pages.loadViewIfNeeded()
            pages.storyToolbar = StoryToolbar()
            pages.traverseView = UIView()
            pages.toolbarScrollHandler = StoryToolbarScrollHandler()
            pages.scrollView = UIScrollView(frame: pages.view.bounds)
            pages.view.addSubview(pages.scrollView)
            pages.scrollView.topEdgeEffect.isHidden = originallyHidden
            defer {
                pages.appDelegate = nil
                detail.storyPagesViewController = nil
                detail.appDelegate = nil
                app.detailViewController = nil
                app.storiesCollection = nil
            }

            for pose in [(phone: true, compact: true), (phone: true, compact: false),
                         (phone: true, compact: true), (phone: true, compact: false),
                         (phone: false, compact: false)] {
                pages.simulatesPhone = pose.phone
                detail.simulatesPhone = pose.phone
                detail.isCompact = pose.compact
                pages.verticalToolbar = false
                pages.perform(NSSelectorFromString("updateReaderToolbarPresentation"))
                XCTAssertEqual(pages.scrollView.topEdgeEffect.isHidden,
                               pose.phone && !pose.compact ? true : originallyHidden,
                               "The pager must not blur the independent article under the story-title header, and must restore its previous edge effect outside expanded phone layout: \(pose)")
            }
        }
    }

    func test_readerLayoutSuspendsBeforeTiledFeedsHidesItsHost() {
        let app = NewsBlurAppDelegate()
        let detail = DuoPendingTiledReaderDetail()
        detail.appDelegate = app
        app.detailViewController = detail
        let pages = DuoScrollingHeaderPages(nibName: nil, bundle: nil)
        pages.appDelegate = app
        detail.addChild(pages)
        detail.view.addSubview(pages.view)
        pages.didMove(toParent: detail)
        defer {
            pages.willMove(toParent: nil)
            pages.view.removeFromSuperview()
            pages.removeFromParent()
            pages.appDelegate = nil
            detail.appDelegate = nil
            app.detailViewController = nil
        }

        XCTAssertFalse(pages.view.isHidden)
        XCTAssertEqual(pages.value(forKey: "hasHiddenReaderAncestor") as? Bool, false)
        detail.resolvesTiledFeeds = true
        XCTAssertEqual(pages.value(forKey: "hasHiddenReaderAncestor") as? Bool, true,
                       "Native safe-area callbacks must stop resizing as soon as the resolved layout excludes the article, before the host's next hidden update")
        detail.resolvesTiledFeeds = false
        XCTAssertEqual(pages.value(forKey: "hasHiddenReaderAncestor") as? Bool, false,
                       "The normal reader must resume layout when the reading columns return")
    }

    func test_expandedDuoArticleFadeDoesNotChangeStoryTitlesHeader() {
        let app = NewsBlurAppDelegate()
        let detail = DuoPhoneReaderLayout()
        detail.appDelegate = app
        detail.isCompact = false
        app.detailViewController = detail
        let pages = DuoScrollingHeaderPages(nibName: nil, bundle: nil)
        pages.appDelegate = app
        defer {
            pages.appDelegate = nil
            detail.appDelegate = nil
            app.detailViewController = nil
        }
        pages.loadViewIfNeeded()
        for vertical in [true, false] {
            pages.verticalToolbar = vertical
            pages.setNavigationBarFadeAlpha(1)
            pages.setNavigationBarFadeAlpha(0)
            XCTAssertEqual(pages.navigationBarFadeAlpha, 1,
                           "Article scrolling must not fade the independent story-title header, vertical=\(vertical)")
        }
    }

    func test_duoArticleFeedHeaderRemainsPinnedDuringScrollingInBothDirections() throws {
        let app = NewsBlurAppDelegate()
        let detail = DuoPhoneReaderLayout()
        detail.appDelegate = app
        app.detailViewController = detail
        let pages = DuoScrollingHeaderPages(nibName: nil, bundle: nil)
        pages.appDelegate = app
        detail.storyPagesViewController = pages
        let page = DuoScrollingHeaderPage(nibName: nil, bundle: nil)
        page.appDelegate = app
        page.loadViewIfNeeded()
        pages.currentPage = page
        let web = try XCTUnwrap(page.webView)
        let scroll = try XCTUnwrap(web.scrollView as? DuoScrollingHeaderScrollView)
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 360, height: 25))
        page.feedTitleGradient = header
        web.addSubview(header)
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.contentSize = CGSize(width: 360, height: 2_000)
        defer {
            page.webView = nil
            page.appDelegate = nil
            pages.currentPage = nil
            pages.appDelegate = nil
            detail.storyPagesViewController = nil
            detail.appDelegate = nil
            app.detailViewController = nil
        }

        for pose in [(vertical: true, compact: true), (vertical: true, compact: false),
                     (vertical: false, compact: false)] {
            detail.isCompact = pose.compact
            pages.verticalToolbar = pose.vertical
            for protectedTop in [CGFloat(0), 22, 59] {
                web.scrollView.contentInset.top = protectedTop
                web.scrollView.contentOffset.y = -protectedTop
                page.updateFeedTitleGradientPosition()
                XCTAssertEqual(header.frame.minY, protectedTop, accuracy: 0.5)

                scroll.simulatesDragging = true
                web.scrollView.contentOffset.y = 180
                page.updateFeedTitleGradientPosition()
                XCTAssertEqual(header.frame.minY, protectedTop, accuracy: 0.5,
                               "The article feed header must remain pinned when scrolling down: \(pose)")

                web.scrollView.contentOffset.y = 140
                page.updateFeedTitleGradientPosition()
                XCTAssertEqual(header.frame.minY, protectedTop, accuracy: 0.5,
                               "The article feed header must remain pinned when scrolling back up")
                XCTAssertEqual(web.scrollView.contentInset.top, protectedTop,
                               "The pinned header must not reserve an extra blank strip")
                XCTAssertEqual(header.frame.height, 25, accuracy: 0.5)
                scroll.simulatesDragging = false
                web.scrollView.contentOffset.y = 400
                page.updateFeedTitleGradientPosition()
                XCTAssertEqual(header.frame.minY, protectedTop, accuracy: 0.5,
                               "Programmatic reading-position restoration must keep the article feed header pinned")
            }
        }
    }

    func test_duoArticleFeedHeaderFollowsTopPullAndPinsDuringBottomBounce() throws {
        let app = NewsBlurAppDelegate()
        let detail = DuoPhoneReaderLayout()
        detail.appDelegate = app
        app.detailViewController = detail
        let pages = DuoScrollingHeaderPages(nibName: nil, bundle: nil)
        pages.appDelegate = app
        detail.storyPagesViewController = pages
        let page = DuoScrollingHeaderPage(nibName: nil, bundle: nil)
        page.appDelegate = app
        page.loadViewIfNeeded()
        pages.currentPage = page
        let web = try XCTUnwrap(page.webView)
        let scroll = try XCTUnwrap(web.scrollView as? DuoScrollingHeaderScrollView)
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 360, height: 25))
        page.feedTitleGradient = header
        web.addSubview(header)
        scroll.frame = web.bounds
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.contentInset = UIEdgeInsets(top: 22, left: 0, bottom: 34, right: 0)
        scroll.contentSize = CGSize(width: 360, height: 2_000)
        let protectedTop = scroll.contentInset.top
        let maximumOffset = scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom
        defer {
            page.webView = nil
            page.appDelegate = nil
            pages.currentPage = nil
            pages.appDelegate = nil
            detail.storyPagesViewController = nil
            detail.appDelegate = nil
            app.detailViewController = nil
        }

        for pose in [(vertical: true, compact: true), (vertical: true, compact: false),
                     (vertical: false, compact: false)] {
            detail.isCompact = pose.compact
            pages.verticalToolbar = pose.vertical
            for gesture in [(tracking: true, dragging: true), (tracking: true, dragging: false),
                            (tracking: false, dragging: true)] {
                scroll.simulatesTracking = false
                scroll.simulatesDragging = false
                scroll.contentOffset.y = -protectedTop
                page.updateFeedTitleGradientPosition()
                XCTAssertEqual(header.frame.minY, protectedTop, accuracy: 0.5)

                scroll.simulatesTracking = gesture.tracking
                scroll.simulatesDragging = gesture.dragging
                page.lastDragDirectionDown = true
                for offset in [maximumOffset - 80, maximumOffset + 60, maximumOffset + 20, maximumOffset] {
                    scroll.contentOffset.y = offset
                    page.updateFeedTitleGradientPosition()
                    XCTAssertEqual(header.frame.minY, protectedTop, accuracy: 0.5,
                                   "Bottom rubber-banding must keep the article feed header pinned: pose=\(pose), gesture=\(gesture), offset=\(offset)")
                }

                scroll.contentOffset.y = maximumOffset - 40
                page.updateFeedTitleGradientPosition()
                XCTAssertEqual(header.frame.minY, protectedTop, accuracy: 0.5,
                               "A deliberate reverse scroll inside the article must keep its header pinned")
                for offset in [-protectedTop - 50, -protectedTop - 20, -protectedTop] {
                    scroll.contentOffset.y = offset
                    page.updateFeedTitleGradientPosition()
                    XCTAssertEqual(header.frame.minY, max(protectedTop, -offset), accuracy: 0.5,
                                   "The feed header must follow the page during a top pull, then settle pinned at its protected edge: pose=\(pose), gesture=\(gesture), offset=\(offset)")
                }
                XCTAssertEqual(scroll.contentInset.top, protectedTop,
                               "Overscroll handling must not add a blank header inset")
                XCTAssertEqual(scroll.contentInset.bottom, 34)
            }
        }
    }

    func test_departingFeedsPreservesAnotherColumnsPopover() throws {
        for source in ["story-view", "story-bar-item", "shared-navigation-view", "next-navigation-bar"] {
            let fixture = try feedDepartureFixture()
            defer { fixture.cleanup() }
            let foreignView = UIView()
            let foreignItem = UIBarButtonItem(title: "Story options", style: .plain, target: nil, action: nil)
            switch source {
            case "story-view":
                let storyView = UIView()
                storyView.addSubview(foreignView)
                fixture.feeds.view.superview?.addSubview(storyView)
                fixture.popover.sourceView = foreignView
            case "story-bar-item":
                fixture.popover.barButtonItem = foreignItem
            case "shared-navigation-view":
                fixture.navigation.view.addSubview(foreignView)
                fixture.popover.sourceView = foreignView
            default:
                fixture.navigation.simulatedTop = UIViewController()
                fixture.popover.sourceView = fixture.navigation.navigationBar
            }

            fixture.feeds.viewWillDisappear(true)

            XCTAssertEqual(fixture.dialog.dismissalCount, 0,
                           "Departing Feeds must preserve the new \(source) popover forwarded by the shared split presenter")
        }
    }

    func test_departingFeedsDismissesItsOwnViewAndBarItemPopovers() throws {
        for source in ["feed-view", "navigation-bar", "feed-toolbar", "navigation-item", "toolbar-item", "settings-item", "custom-item"] {
            let fixture = try feedDepartureFixture()
            defer { fixture.cleanup() }
            let item = UIBarButtonItem(title: "Feed action", style: .plain, target: nil, action: nil)
            switch source {
            case "feed-view":
                let button = UIButton()
                fixture.feeds.view.addSubview(button)
                fixture.popover.sourceView = button
            case "navigation-bar":
                fixture.popover.sourceView = fixture.navigation.navigationBar
            case "feed-toolbar":
                fixture.popover.sourceView = fixture.navigation.toolbar
            case "navigation-item":
                fixture.feeds.navigationItem.rightBarButtonItem = item
                fixture.popover.barButtonItem = item
            case "toolbar-item":
                fixture.feeds.toolbarItems = [item]
                fixture.popover.barButtonItem = item
            case "settings-item":
                fixture.feeds.settingsBarButton = item
                fixture.popover.barButtonItem = item
            default:
                let button = UIButton()
                fixture.feeds.view.addSubview(button)
                fixture.popover.barButtonItem = UIBarButtonItem(customView: button)
            }

            fixture.feeds.viewWillDisappear(true)

            XCTAssertEqual(fixture.dialog.dismissalCount, 1,
                           "Departing Feeds must still dismiss its own \(source) popover")
        }
    }

    func test_departingFeedsPreservesLegacyCleanupForUnanchoredPopover() throws {
        let fixture = try feedDepartureFixture()
        defer { fixture.cleanup() }
        XCTAssertNil(fixture.popover.sourceView)
        XCTAssertNil(fixture.popover.barButtonItem)

        fixture.feeds.viewWillDisappear(false)

        XCTAssertEqual(fixture.dialog.dismissalCount, 1,
                       "A legacy popover with no inspectable anchor keeps its existing departure cleanup")
    }

    private func feedDepartureFixture() throws -> (
        app: NewsBlurAppDelegate, feeds: FeedDepartureFeeds, navigation: FeedDepartureNavigation,
        dialog: FeedDepartureDialog, popover: UIPopoverPresentationController, cleanup: () -> Void
    ) {
        let app = NewsBlurAppDelegate()
        let feeds = FeedDepartureFeeds()
        feeds.appDelegate = app
        app.feedsViewController = feeds
        let navigation = FeedDepartureNavigation(rootViewController: feeds)
        navigation.simulatedTop = feeds
        app.feedsNavigationController = navigation
        navigation.loadViewIfNeeded()
        feeds.loadViewIfNeeded()
        let dialog = FeedDepartureDialog(rootViewController: UIViewController())
        dialog.modalPresentationStyle = .popover
        let popover = try XCTUnwrap(dialog.popoverPresentationController)
        XCTAssertEqual(dialog.presentationController?.presentationStyle, .popover)
        // FeedToolbarLayoutTests.swift models UIKit forwarding a shared split presentation through both sibling navigation controllers.
        navigation.forwardedPopover = dialog
        return (app, feeds, navigation, dialog, popover, {
            navigation.forwardedPopover = nil
            navigation.simulatedTop = nil
            navigation.setViewControllers([], animated: false)
            feeds.viewIfLoaded?.removeFromSuperview()
            app.feedsViewController = nil
            app.feedsNavigationController = nil
            feeds.appDelegate = nil
        })
    }

    private func waitForSettledView(_ controller: UIViewController) async throws {
        var stableSamples = 0
        for _ in 0..<200 {
            controller.view.window?.layoutIfNeeded()
            let navigation = controller.navigationController
            let transitioning = controller.transitionCoordinator != nil || navigation?.transitionCoordinator != nil
            let isTop = navigation == nil || navigation?.topViewController === controller || controller.parent is DetailViewController
            if controller.view.window != nil && !transitioning && isTop {
                stableSamples += 1
                if stableSamples >= 3 { return }
            } else {
                stableSamples = 0
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("The requested screen must finish its navigation transition")
    }

    @discardableResult
    private func openVisibleStory(_ stories: FeedDetailViewController, requiresArticleBody: Bool = false) async throws -> String {
        try await waitForSettledView(stories)
        let table = try XCTUnwrap(stories.storyTitlesTable)
        func articleLength(_ story: [AnyHashable: Any]) -> Int {
            let html = story["story_content"] as? String ?? ""
            return html.replacingOccurrences(of: "(?is)<(script|style)\\b[^>]*>.*?</\\1>", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines).count
        }
        for _ in 0..<300 {
            table.layoutIfNeeded()
            if !stories.pageFetching, !table.isHidden {
                // FeedToolbarLayoutTests.swift chooses the longest real body, rather than a short visible newsletter whose markup inflates its length.
                let articleCandidate = requiresArticleBody ? (0..<Int(stories.storiesCollection.storyLocationsCount))
                    .compactMap { location -> (location: Int, hash: String, length: Int)? in
                        guard let story = stories.getStoryAtLocation(location),
                              let hash = story["story_hash"] as? String else { return nil }
                        let length = articleLength(story)
                        return length > 1800 ? (location, hash, length) : nil
                    }.max(by: { $0.length < $1.length }) : nil
                for cell in table.visibleCells.compactMap({ $0 as? FeedDetailTableCell }) {
                    guard let path = table.indexPath(for: cell) else { continue }
                    let location = stories.storyLocation(for: path)
                    if location >= 0, location < stories.storiesCollection.storyLocationsCount,
                       let story = stories.getStoryAtLocation(location),
                       let hash = story["story_hash"] as? String, cell.storyHash == hash,
                       !requiresArticleBody || hash == articleCandidate?.hash {
                        // FeedToolbarLayoutTests.swift follows a visible row's real selection path after the list refreshes.
                        table.selectRow(at: path, animated: false, scrollPosition: .none)
                        table.delegate?.tableView?(table, didSelectRowAt: path)
                        return hash
                    }
                }
                if let articleCandidate,
                   let path = stories.indexPath(forStoryLocation: articleCandidate.location),
                   path.section < table.numberOfSections,
                   path.row < table.numberOfRows(inSection: path.section) {
                    // FeedToolbarLayoutTests.swift excludes legitimate link-only RSS entries from the article-scrolling audit.
                    table.scrollToRow(at: path, at: .middle, animated: false)
                }
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        let longestBody = (0..<Int(stories.storiesCollection.storyLocationsCount)).compactMap {
            stories.getStoryAtLocation($0)?["story_content"] as? String
        }.map(\.count).max() ?? 0
        XCTFail("A loaded, visible story row must be available before opening the reader; longest loaded body: \(longestBody)")
        throw NSError(domain: "DuoReaderAudit", code: 1)
    }

    func test_liveDuoReaderScrollAndSidebarRoundTrip() async throws {
        try await auditLiveDuoReader(river: false)
    }

    func test_liveDuoRiverFeedHeaderStaysVisibleWhileScrolling() async throws {
        try await auditLiveDuoReader(river: true)
    }

    func test_liveDuoReaderRoutesEachColumnScrollingToItsOwnHeader() async throws {
        try await auditLiveDuoReader(river: false, checksNativeHeaderMinimization: true)
    }

    private func auditLiveDuoReader(river: Bool, checksNativeHeaderMinimization: Bool = false) async throws {
        guard #available(iOS 27.1, *), UIDevice.current.name.localizedCaseInsensitiveContains("duo") else {
            throw XCTSkip("Run on the existing iPhone Duo simulator")
        }
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        app.showFeedsList(animated: false)
        try await waitForSettledView(app.feedsViewController)
        // FeedToolbarLayoutTests.swift audits both the single-feed strip and the named river header.
        let folders = try XCTUnwrap(app.dictFoldersArray as? [String])
        var selectedFeed = river
        if river {
            app.feedsViewController.selectEverything(nil)
        }
        for folder in folders where !selectedFeed {
            guard let feedIDs = app.dictFolders[folder] as? [Any] else { continue }
            guard let feedID = feedIDs.map({ String(describing: $0) }).first(where: {
                Int($0) != nil && app.dictFeeds[$0] != nil
            }) else { continue }
            app.feedsViewController.selectFeed(feedID, inFolder: folder)
            selectedFeed = true
            break
        }
        guard selectedFeed else { throw XCTSkip("A subscribed feed is required for the live article audit") }
        let stories = try XCTUnwrap(app.feedDetailViewController)
        let selectedHash = try await openVisibleStory(stories, requiresArticleBody: true)
        let pages = try XCTUnwrap(app.storyPagesViewController)
        try await waitForSettledView(pages)
        defer { app.showFeedsList(animated: false) }
        var articleText = ""
        var scrollableSamples = 0
        for _ in 0..<300 {
            if let page = pages.currentPage, page.activeStoryId == selectedHash,
               let web = page.webView, web.window != nil, !web.isHidden, web.alpha > 0.99 {
                let document = (try? await web.evaluateJavaScript("({text:document.querySelector('#NB-story')?.innerText || '',generation:document.querySelector('meta[name=\"newsblur-story-load\"]')?.content || ''})")) as? [String: Any]
                articleText = document?["text"] as? String ?? ""
                let maximum = web.scrollView.contentSize.height - web.scrollView.bounds.height + web.scrollView.adjustedContentInset.bottom
                let isCurrentDocument = document?["generation"] as? String == (page.value(forKey: "storyLoadGeneration") as? NSNumber)?.stringValue
                if articleText.count > 100 && isCurrentDocument && maximum > 100 && web.bounds.height > 200 {
                    scrollableSamples += 1
                    if scrollableSamples >= 3 { break }
                } else {
                    scrollableSamples = 0
                }
            } else {
                scrollableSamples = 0
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertGreaterThanOrEqual(scrollableSamples, 3,
                                    "The selected article must finish loading with more than 100 points of real scroll range; selected=\(selectedHash), current=\(pages.currentPage?.activeStoryId ?? "nil"), body=\(articleText.count), content=\(String(describing: pages.currentPage?.webView?.scrollView.contentSize)), viewport=\(String(describing: pages.currentPage?.webView?.bounds))")
        let page = try XCTUnwrap(pages.currentPage)
        let web = try XCTUnwrap(page.webView)
        let window = try XCTUnwrap(web.window)
        if checksNativeHeaderMinimization {
            let navigation = try XCTUnwrap(pages.navigationController)
            let owner = try XCTUnwrap(navigation.topViewController)
            let compactReader = app.detailViewController.isPhoneOrCompact
            let expectedScroll = compactReader ? web.scrollView : stories.storyTitlesTable
            XCTAssertTrue(owner.contentScrollView(for: .top) === expectedScroll,
                          "Each native header must observe its own column: compact article or expanded story-title list")
            // FeedToolbarLayoutTests.swift reads this public Objective-C configuration dynamically so the test still compiles with older SDKs.
            let configuration = try XCTUnwrap(owner.navigationItem.value(forKey: "navigationBarMinimization") as? NSObject)
            XCTAssertEqual(configuration.value(forKey: "minimizationBehavior") as? Int, 2,
                           "The native header must minimize only when its own column scrolls down")
            XCTAssertEqual(configuration.value(forKey: "safeAreaAdjustment") as? Int, 1,
                           "Native minimization must release the header's space instead of leaving a blank strip")
            XCTAssertFalse(navigation.hidesBarsOnSwipe,
                           "Reader header minimization must not hide the native side toolbar")
            if pages.usesVerticalReaderToolbar { XCTAssertFalse(navigation.isToolbarHidden) }

            let host = try XCTUnwrap(pages.view.superview)
            let originallyHidden = host.isHidden
            let originalWidth = web.bounds.width
            let updateChrome = NSSelectorFromString("updateReaderToolbarPresentation")
            host.isHidden = true
            defer {
                host.isHidden = originallyHidden
                pages.perform(updateChrome)
            }
            pages.perform(updateChrome)
            XCTAssertFalse(owner.contentScrollView(for: .top) === web.scrollView,
                           "A retained hidden reader must release the shared header's scroll source")
            if !compactReader {
                XCTAssertTrue(owner.contentScrollView(for: .top) === stories.storyTitlesTable,
                              "Hiding the article must preserve the story-title header's independent scroll source")
            }
            XCTAssertFalse(owner.toolbarItems?.contains { $0.accessibilityIdentifier?.hasPrefix("reader-") == true } == true,
                           "Feeds and story titles must not inherit the hidden reader's side controls")
            XCTAssertEqual(web.bounds.width, originalWidth, accuracy: 0.5,
                           "Releasing hidden reader chrome must preserve its retained article viewport")
        }
        if river {
            XCTAssertTrue(app.storiesCollection.isRiverView)
            let header = try XCTUnwrap(page.feedTitleGradient)
            XCTAssertGreaterThan(header.bounds.height, 10,
                                 "The river audit must show the named feed header, not a single-feed color strip")
            XCTAssertTrue(header.subviews.compactMap { $0 as? UILabel }.contains { !($0.text ?? "").isEmpty })
        }
        XCTAssertGreaterThan(articleText.count, 100, "Reader must visibly contain actual article text")
        let renderedGeneration = try await web.evaluateJavaScript("document.querySelector('meta[name=\"newsblur-story-load\"]')?.content || ''") as? String
        XCTAssertEqual(renderedGeneration, (page.value(forKey: "storyLoadGeneration") as? NSNumber)?.stringValue,
                       "The rendered article must belong to the current load, not a stale document")
        XCTAssertFalse(web.isHidden)
        XCTAssertGreaterThan(web.alpha, 0.99)
        XCTAssertGreaterThan(web.bounds.width, 250, "The article must retain readable width")
        let scroller = web.scrollView
        let originalOffset = scroller.contentOffset
        defer { scroller.setContentOffset(originalOffset, animated: false) }
        func capture(_ name: String) {
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
            let attachment = XCTAttachment(image: image)
            attachment.name = "duo-\(Int(window.bounds.width))x\(Int(window.bounds.height))-\(river ? "river-" : "")\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        scroller.setContentOffset(CGPoint(x: 0, y: -scroller.adjustedContentInset.top), animated: false)
        try await waitForSettledView(pages)
        capture("reader-top")
        let widths = try await web.evaluateJavaScript("({viewport:window.innerWidth,document:document.documentElement.clientWidth,scroll:document.documentElement.scrollWidth,story:document.querySelector('#NB-story').getBoundingClientRect().width,meta:document.querySelector('meta[name=viewport]').content})")
        let geometry = "web=\(web.bounds), page=\(page.view.bounds), pager=\(pages.scrollView.bounds)"
        let safeAreas = "safe=\(pages.view.safeAreaInsets), windowSafe=\(window.safeAreaInsets), webInsets=\(web.scrollView.adjustedContentInset)"
        let positions = "webInWindow=\(web.convert(web.bounds, to: window)), pageInWindow=\(page.view.convert(page.view.bounds, to: window)), pagerInWindow=\(pages.scrollView.convert(pages.scrollView.bounds, to: window))"
        let widthEvidence = XCTAttachment(string: "\(geometry)\n\(safeAreas)\n\(positions)\nDOM=\(String(describing: widths))")
        widthEvidence.name = "duo-reader-widths"
        widthEvidence.lifetime = .keepAlways
        add(widthEvidence)
        let metrics = try XCTUnwrap(widths as? [String: Any])
        let documentWidth = try XCTUnwrap(metrics["document"] as? NSNumber).doubleValue
        XCTAssertEqual(documentWidth, Double(web.bounds.width), accuracy: 1,
                       "The article must reflow to the visible web view instead of clipping text behind the side bar")
        let maximum = max(0, scroller.contentSize.height - scroller.bounds.height + scroller.adjustedContentInset.bottom)
        XCTAssertGreaterThan(maximum, 100, "The scrolling audit needs a real article taller than its viewport")
        scroller.setContentOffset(CGPoint(x: 0, y: min(320, maximum)), animated: false)
        try await waitForSettledView(pages)
        capture("reader-scrolled")
        if pages.usesVerticalReaderToolbar {
            let header = try XCTUnwrap(page.feedTitleGradient)
            XCTAssertEqual(header.convert(header.bounds, to: web).minY, scroller.contentInset.top, accuracy: 1,
                           "The live article's feed header must remain pinned after scrolling")
        }
        XCTAssertGreaterThanOrEqual(scroller.contentOffset.y, min(320, maximum) - 1)
        XCTAssertGreaterThan(web.bounds.height, 200)
        let articleBottom = max(0, scroller.contentSize.height - scroller.bounds.height + scroller.adjustedContentInset.bottom)
        scroller.setContentOffset(CGPoint(x: 0, y: articleBottom), animated: false)
        try await waitForSettledView(pages)
        capture("reader-bottom")
        if pages.usesVerticalReaderToolbar {
            let header = try XCTUnwrap(page.feedTitleGradient)
            XCTAssertEqual(header.convert(header.bounds, to: web).minY, scroller.contentInset.top, accuracy: 1,
                           "The feed header must remain visible at the article bottom")
            let readerTop = pages.view.convert(pages.view.bounds, to: window).minY
            let protectedTop = max(0, window.safeAreaInsets.top - readerTop)
            XCTAssertEqual(pages.topInset(forNavigationBarAlpha: 0), protectedTop, accuracy: 1,
                           "The side-bar reader must not reserve a phantom horizontal navigation-bar gap")
            XCTAssertTrue(pages.storyToolbar.isHidden)
        }
        let split = try XCTUnwrap(app.splitViewController)
        if !split.isCollapsed {
            for _ in 0..<2 {
                if !split.isFeedsListHidden { pages.toggleFeeds(nil) }
                for _ in 0..<100 {
                    if split.isFeedsListHidden && split.transitionCoordinator == nil { break }
                    try await Task.sleep(nanoseconds: 50_000_000)
                }
                XCTAssertTrue(split.isFeedsListHidden)
                XCTAssertGreaterThan(web.bounds.width, 300)
                pages.toggleFeeds(nil)
                for _ in 0..<100 {
                    if !split.isFeedsListHidden && split.transitionCoordinator == nil { break }
                    try await Task.sleep(nanoseconds: 50_000_000)
                }
                XCTAssertFalse(split.isFeedsListHidden, "Sidebar must reopen after it has been hidden")
                XCTAssertEqual(split.preferredSplitBehavior, .overlay)
            }
            capture("reader-sidebar-restored")
        }
    }

    func test_duoExpandedFeedSelectionMountsVisibleStories() async throws {
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        let split = try XCTUnwrap(app.splitViewController)
        guard UIDevice.current.userInterfaceIdiom == .phone, !split.isCollapsed else {
            throw XCTSkip("Run with iPhone Duo open in Device Hub")
        }
        let detail = try XCTUnwrap(app.detailViewController)
        app.feedsViewController.selectEverything(nil)
        let stories = try XCTUnwrap(app.feedDetailViewController)
        for _ in 0..<100 {
            if !stories.pageFetching && stories.storiesCollection.storyLocationsCount > 0 { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        for _ in 0..<100 {
            stories.view.layoutIfNeeded()
            if stories.storyTitlesTable.visibleCells.contains(where: { $0 is FeedDetailTableCell }) { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        split.view.layoutIfNeeded()
        XCTAssertFalse(detail.isPhoneOrCompact)
        XCTAssertTrue(stories.parent === detail)
        XCTAssertNotNil(stories.view.window)
        XCTAssertGreaterThan(stories.view.bounds.width, 200)
        XCTAssertGreaterThan(stories.view.bounds.height, 200)
        XCTAssertGreaterThan(stories.storiesCollection.storyLocationsCount, 0)
        let window = try XCTUnwrap(split.view.window)
        var ancestor: UIView? = stories.view
        while let view = ancestor {
            XCTAssertFalse(view.isHidden)
            XCTAssertGreaterThan(view.alpha, 0.99)
            ancestor = view.superview
        }
        if stories.isLegacyTable {
            XCTAssertFalse(stories.storyTitlesTable.isHidden)
            XCTAssertTrue(stories.storyTitlesTable.visibleCells.contains { $0 is FeedDetailTableCell }, "Loaded stories must render as visible rows, not just a loading placeholder")
        }
        XCTAssertGreaterThan(window.bounds.intersection(stories.view.convert(stories.view.bounds, to: window)).width, 200)
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        let attachment = XCTAttachment(image: image)
        attachment.name = "duo-open-reader-layout"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func test_duoClosedReaderMovesItsChromeToSystemBar() async throws {
        guard #available(iOS 27.1, *) else { throw XCTSkip("Requires Duo bar support") }
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        app.showFeedsList(animated: false)
        let feeds = try XCTUnwrap(app.feedsViewController)
        guard Utilities.usesSystemVerticalBar(feeds.traitCollection) else {
            throw XCTSkip("Run with iPhone Duo closed in Device Hub")
        }
        feeds.selectEverything(nil)
        let stories = try XCTUnwrap(app.feedDetailViewController)
        try await openVisibleStory(stories)
        let pages = try XCTUnwrap(app.storyPagesViewController)
        for _ in 0..<100 {
            if pages.viewIfLoaded?.window != nil { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        defer { app.showFeedsList(animated: false) }
        try await waitForSettledView(pages)
        for _ in 0..<200 {
            if pages.currentPage?.readyForPresentation == true { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        pages.view.layoutIfNeeded()
        let window = try XCTUnwrap(pages.view.window)
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "duo-closed-reader-chrome"
        attachment.lifetime = .keepAlways
        add(attachment)
        // FeedToolbarLayoutTests.swift ensures reader controls belong to UIKit's adaptive bar instead of overlaying content.
        XCTAssertFalse(pages.useCustomToolbar)
        XCTAssertTrue(pages.storyToolbar.isHidden)
        XCTAssertTrue(pages.traverseView.isHidden)
        XCTAssertFalse((pages.toolbarItems ?? []).isEmpty)
    }

    func test_duoClosedAccountHeaderScrollsWithFeedsWithoutTopBarGap() async throws {
        guard #available(iOS 27.1, *) else { throw XCTSkip("Requires Duo bar support") }
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        app.showFeedsList(animated: false)
        let feeds = try XCTUnwrap(app.feedsViewController)
        for _ in 0..<100 {
            if feeds.viewIfLoaded?.window != nil { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        guard Utilities.usesSystemVerticalBar(feeds.traitCollection) else {
            throw XCTSkip("Run with iPhone Duo closed in Device Hub")
        }
        let table = try XCTUnwrap(feeds.feedTitlesTable)
        try await waitForSettledView(feeds)
        let window = try XCTUnwrap(feeds.view.window)
        let header = try XCTUnwrap(feeds.value(forKey: "userInfoView") as? UIView)
        let originalOffset = table.contentOffset
        defer { table.setContentOffset(originalOffset, animated: false) }
        table.setContentOffset(CGPoint(x: 0, y: -table.adjustedContentInset.top), animated: false)
        feeds.view.layoutIfNeeded()
        let initialY = header.convert(header.bounds, to: window).minY
        table.setContentOffset(CGPoint(x: 0, y: table.contentOffset.y + 160), animated: false)
        feeds.view.layoutIfNeeded()
        // FeedToolbarLayoutTests.swift verifies the actual header moves with the scroll view rather than leaving a pinned blank strip.
        XCTAssertTrue(header.isDescendant(of: table))
        XCTAssertNil(feeds.navigationItem.titleView)
        XCTAssertEqual(initialY - header.convert(header.bounds, to: window).minY, 160, accuracy: 1)
        XCTAssertEqual(feeds.view.convert(feeds.view.bounds, to: window).minY, window.safeAreaInsets.top, accuracy: 1)
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "duo-scrolled-account-header"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func test_verticalStoryListFooterOnlyReservesSpaceForActiveSearch() {
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 440, height: 640))
        let header = StoryTitlesHeaderBar()
        header.setup(in: parent)
        header.addSearchField(UITextField())
        parent.layoutIfNeeded()
        let horizontalHeight = header.headerContainer.bounds.height
        header.setUsesSystemVerticalBar(true)
        parent.layoutIfNeeded()
        XCTAssertTrue(header.pillBar.isHidden)
        XCTAssertEqual(header.headerContainer.bounds.height, 0, accuracy: 0.5)
        UIView.performWithoutAnimation { header.setSearchActive(true) }
        parent.setNeedsLayout()
        parent.layoutIfNeeded()
        XCTAssertFalse(header.searchContainer.isHidden)
        XCTAssertEqual(header.headerContainer.bounds.height, 36, accuracy: 0.5)
        header.setSearchActive(false)
        header.setUsesSystemVerticalBar(false)
        parent.layoutIfNeeded()
        XCTAssertFalse(header.pillBar.isHidden)
        XCTAssertEqual(header.headerContainer.bounds.height, horizontalHeight, accuracy: 0.5)
    }

    func test_expandedPhoneUsesRegularReaderLayoutAndCollapsesAgain() {
        let detail = DuoPhoneReaderLayout()
        detail.traitOverrides.horizontalSizeClass = .regular
        detail.isCompact = false
        // FeedToolbarLayoutTests.swift models Duo's inner display without changing the device idiom.
        XCTAssertFalse(detail.isPhoneOrCompact, "An expanded phone must use the regular multi-pane reader")
        detail.isCompact = true
        detail.traitOverrides.horizontalSizeClass = .compact
        XCTAssertTrue(detail.isPhoneOrCompact, "Closing Duo must restore its compact navigation")
        detail.isCompact = false
        detail.traitOverrides.horizontalSizeClass = .regular
        XCTAssertFalse(detail.isPhoneOrCompact, "Reopening Duo must restore the regular reader")
    }

    func test_duoClosedFeedControlsParticipateInSystemVerticalBar() async throws {
        guard #available(iOS 27.1, *) else { throw XCTSkip("Requires Duo bar support") }
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        app.showFeedsList(animated: false)
        let feeds = try XCTUnwrap(app.feedsViewController)
        for _ in 0..<100 {
            if feeds.viewIfLoaded?.window != nil { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        guard Utilities.usesSystemVerticalBar(feeds.traitCollection) else {
            throw XCTSkip("Run with iPhone Duo closed in Device Hub")
        }
        feeds.view.setNeedsLayout()
        feeds.view.layoutIfNeeded()
        // FeedToolbarLayoutTests.swift requires container-owned controls so UIKit can move them to Duo's side bar.
        try await waitForSettledView(feeds)
        let items = feeds.toolbarItems ?? []
        XCTAssertTrue(items.contains { $0.accessibilityIdentifier == "feed-list-add" }, "Add Site must participate in the system bar")
        XCTAssertTrue(items.contains { $0.accessibilityIdentifier == "feed-list-settings" }, "Settings must participate in the system bar")
        XCTAssertTrue(items.contains { $0.accessibilityIdentifier?.hasPrefix("feed-list-intelligence") == true }, "Intelligence filters must participate in the system bar")
        let filters = items.filter { $0.accessibilityIdentifier?.hasPrefix("feed-list-intelligence-") == true }
        XCTAssertEqual(filters.map(\.title), ["All", "Unread", "Focus", "Saved"])
        for filter in filters {
            XCTAssertTrue(filter.sharesBackground, "All four intelligence filters must form one continuous native group")
            XCTAssertNil(filter.customView, "Native items must retain individual system overflow")
            XCTAssertNotNil(filter.image)
        }
        for identifier in ["feed-list-add", "feed-list-settings"] {
            XCTAssertFalse(try XCTUnwrap(items.first { $0.accessibilityIdentifier == identifier }).sharesBackground,
                           "Add Site and Settings each need a separate background")
        }
        XCTAssertTrue(feeds.feedViewToolbar.isHidden, "The horizontal footer must give way to the system vertical bar")
        let window = try XCTUnwrap(feeds.view.window)
        let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: screenshot)
        attachment.name = "duo-closed-feed-controls"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func test_duoClosedStoryListControlsParticipateInSystemVerticalBar() async throws {
        guard #available(iOS 27.1, *) else { throw XCTSkip("Requires Duo bar support") }
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        let feeds = try XCTUnwrap(app.feedsViewController)
        guard Utilities.usesSystemVerticalBar(feeds.traitCollection) else {
            throw XCTSkip("Run with iPhone Duo closed in Device Hub")
        }
        app.showFeedsList(animated: false)
        try await waitForSettledView(feeds)
        feeds.selectEverything(nil)
        let stories = try XCTUnwrap(app.feedDetailViewController)
        for _ in 0..<100 {
            if stories.viewIfLoaded?.window != nil { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        defer { app.showFeedsList(animated: false) }
        try await waitForSettledView(stories)
        let table = try XCTUnwrap(stories.storyTitlesTable)
        for _ in 0..<300 {
            table.layoutIfNeeded()
            if !stories.pageFetching && table.visibleCells.contains(where: { $0 is FeedDetailTableCell }) { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertTrue(table.visibleCells.contains { $0 is FeedDetailTableCell },
                      "FeedToolbarLayoutTests.swift captures loaded stories rather than a loading placeholder")
        let window = try XCTUnwrap(stories.view.window)
        stories.view.layoutIfNeeded()
        let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: screenshot)
        attachment.name = "duo-closed-story-list-controls"
        attachment.lifetime = .keepAlways
        add(attachment)
        let navigation = try XCTUnwrap(stories.navigationController)
        let geometry = XCTAttachment(string: "window=\(window.bounds), windowSafe=\(window.safeAreaInsets)\ncontroller=\(stories.view.convert(stories.view.bounds, to: window)), safe=\(stories.view.safeAreaInsets)\ntable=\(table.convert(table.bounds, to: window)), inset=\(table.contentInset), adjusted=\(table.adjustedContentInset)\nnav=\(navigation.view.convert(navigation.view.bounds, to: window)), bar=\(navigation.navigationBar.convert(navigation.navigationBar.bounds, to: window)), hidden=\(navigation.isNavigationBarHidden)")
        geometry.name = "duo-closed-story-list-geometry"
        geometry.lifetime = .keepAlways
        add(geometry)
        // FeedToolbarLayoutTests.swift checks the same container contract as the feed list without invoking read mutations.
        let items = stories.toolbarItems ?? []
        for identifier in ["story-list-options", "story-list-search", "story-list-mark-read"] {
            XCTAssertTrue(items.contains { $0.accessibilityIdentifier == identifier }, "\(identifier) must participate in the system bar")
        }
        XCTAssertTrue(stories.storyTitlesHeaderBar.pillBar.isHidden, "Story-list footer controls must move into the side bar")
        let bar = navigation.navigationBar
        XCTAssertEqual(bar.convert(bar.bounds, to: window).minY, window.safeAreaInsets.top, accuracy: 1,
                       "The actual story list must not keep the obsolete horizontal status-bar gap")
        table.setContentOffset(CGPoint(x: 0, y: 240), animated: false)
        try await waitForSettledView(stories)
        let scrolled = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let scrolledAttachment = XCTAttachment(image: scrolled)
        scrolledAttachment.name = "duo-closed-story-list-scrolled"
        scrolledAttachment.lifetime = .keepAlways
        add(scrolledAttachment)
        XCTAssertEqual(bar.convert(bar.bounds, to: window).minY, window.safeAreaInsets.top, accuracy: 1)
        let title = try XCTUnwrap(stories.navigationItem.titleView)
        XCTAssertFalse(title.isHidden)
        XCTAssertTrue(title.isDescendant(of: bar), "The title must remain visible while its stories scroll")
    }

    func test_livePhoneLandscapeNavigationUsesCompactHeader() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Requires the physical SE landscape safe area")
        #else
        guard Bundle.main.bundleIdentifier == "com.newsblur.NB-Alpha", UIDevice.current.userInterfaceIdiom == .phone else {
            throw XCTSkip("Requires NB Alpha on iPhone")
        }
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        app.showFeedsList(animated: false)
        let feeds = try XCTUnwrap(app.feedsViewController)
        let window = try XCTUnwrap(feeds.view.window)
        let scene = try XCTUnwrap(window.windowScene)
        let portraitBarHeight = feeds.navigationController?.navigationBar.bounds.height ?? 0
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeLeft))
        defer { scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) }
        for _ in 0..<40 {
            if scene.interfaceOrientation.isLandscape { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        try await Task.sleep(nanoseconds: 700_000_000)
        let nav = try XCTUnwrap(feeds.navigationController)
        let visibleBar = nav.view.subviews.compactMap { $0 as? UINavigationBar }.first { !$0.isHidden } ?? nav.navigationBar
        let bar = visibleBar.convert(visibleBar.bounds, to: window)
        print("LANDSCAPE_BAR sizing=\(nav.navigationBar.sizeThatFits(nav.view.bounds.size)) intrinsic=\(nav.navigationBar.intrinsicContentSize) safe=\(nav.navigationBar.safeAreaInsets) margins=\(nav.navigationBar.layoutMargins) class=\(type(of: nav.navigationBar))")
        let contentTop = feeds.view.convert(feeds.view.bounds, to: window).minY + feeds.view.safeAreaInsets.top
        print("LANDSCAPE_CONTENT top=\(contentTop) view=\(feeds.view.frame) parent=\(String(describing: nav.navigationBar.superview?.frame))")
        print("LANDSCAPE_HEADER bar=\(bar) windowSafe=\(window.safeAreaInsets) navSafe=\(nav.view.safeAreaInsets) feedSafe=\(feeds.view.safeAreaInsets) additional=\(nav.additionalSafeAreaInsets) status=\(String(describing: scene.statusBarManager?.statusBarFrame)) hidden=\(String(describing: scene.statusBarManager?.isStatusBarHidden)) vertical=\(nav.traitCollection.verticalSizeClass.rawValue) title=\(String(describing: feeds.navigationItem.titleView?.frame))")
        let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        let attachment = XCTAttachment(image: screenshot)
        attachment.name = "live-SE-landscape-header"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(scene.interfaceOrientation.isLandscape)
        XCTAssertLessThanOrEqual(bar.maxY, 44.5)
        XCTAssertEqual(contentTop, bar.maxY, accuracy: 1)
        feeds.selectEverything(nil)
        let stories = try XCTUnwrap(app.feedDetailViewController)
        for _ in 0..<150 {
            if stories.viewIfLoaded?.window != nil && !stories.pageFetching && stories.storiesCollection.storyLocationsCount > 0 { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        try await Task.sleep(nanoseconds: 400_000_000)
        let storyBar = nav.view.subviews.compactMap { $0 as? UINavigationBar }.first { !$0.isHidden } ?? nav.navigationBar
        XCTAssertLessThanOrEqual(storyBar.convert(storyBar.bounds, to: window).maxY, 44.5)
        let storyTop = stories.view.convert(stories.view.bounds, to: window).minY + stories.view.safeAreaInsets.top
        XCTAssertEqual(storyTop, 44, accuracy: 1)
        let listImage = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        let listAttachment = XCTAttachment(image: listImage)
        listAttachment.name = "live-SE-landscape-story-list"
        listAttachment.lifetime = .keepAlways
        add(listAttachment)
        app.showFeedsList(animated: false)
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        for _ in 0..<40 {
            if scene.interfaceOrientation.isPortrait { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(nav.navigationBar.bounds.height, portraitBarHeight, accuracy: 1)
        #endif
    }

    func test_landscapeReaderKeepsZeroStatusBarInset() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = LandscapeReaderWindow(windowScene: scene)
        let pages = LandscapeReaderPages()
        pages.appDelegate = LandscapeReaderAppDelegate()
        pages.toolbarScrollHandler = StoryToolbarScrollHandler()
        window.rootViewController = pages
        window.isHidden = false
        defer { window.isHidden = true }
        XCTAssertTrue(pages.view.window === window)
        XCTAssertEqual(pages.topInset(forNavigationBarAlpha: 1), 44, accuracy: 0.5)
        XCTAssertEqual(pages.topInset(forNavigationBarAlpha: 0), 44, accuracy: 0.5)
    }

    func test_headerCountIconsStartAtTheirFinalSizeDuringRotation() throws {
        let storyboard = UIStoryboard(name: "MainInterface", bundle: nil)
        let controller = try XCTUnwrap(storyboard.instantiateViewController(withIdentifier: "FeedsViewController") as? FeedsViewController)
        controller.appDelegate = NewsBlurAppDelegate.shared()
        controller.loadViewIfNeeded()
        let navigation = UINavigationController(rootViewController: controller)
        navigation.view.frame = CGRect(x: 0, y: 0, width: 667, height: 375)
        for orientation in [UIInterfaceOrientation.portrait, .landscapeLeft, .portrait] {
            controller.layoutHeaderCounts(orientation)
            for key in ["greenIcon", "yellowIcon"] {
                let icon = try XCTUnwrap(controller.value(forKey: key) as? UIImageView)
                XCTAssertEqual(icon.bounds.width, 10, accuracy: 0.01,
                               "Rotation must never animate a full-size asset down to the count icon size")
                XCTAssertEqual(icon.bounds.height, 10, accuracy: 0.01)
            }
        }
    }

    func test_footerGroupsStayAtOppositeEdgesWithoutStretchingControls() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "story_toolbar_position")
        defaults.set("bottom", forKey: "story_toolbar_position")
        defer { defaults.set(saved, forKey: "story_toolbar_position") }
        for showsDiscovery in [false, true] {
            let parent = UIView(frame: CGRect(x: 0, y: 0, width: 667, height: 375))
            let header = StoryTitlesHeaderBar()
            header.setup(in: parent)
            header.discoverPill.isHidden = !showsDiscovery
            header.updateOptionsPill(order: "newest", readFilter: "unread")
            header.addSearchField(UITextField())
            header.setSearchActive(true)
            var wideGroupWidth: CGFloat?
            var previousWideGap: CGFloat?
            for width: CGFloat in [667, 1024, 500, 375, 330, 284, 1024] {
                parent.frame.size.width = width
                parent.setNeedsLayout()
                parent.layoutIfNeeded()
                header.relayoutPills()
                parent.layoutIfNeeded()
                let bar = header.pillBar.frame
                XCTAssertEqual(bar.midX, width / 2, accuracy: 0.5)
                XCTAssertLessThanOrEqual(bar.width, width)
                XCTAssertEqual(header.searchContainer.frame.minX, bar.minX + 16, accuracy: 0.5)
                XCTAssertEqual(header.searchContainer.frame.maxX, bar.maxX - 16, accuracy: 0.5)
                XCTAssertGreaterThanOrEqual(header.markReadPill.bounds.width, 52)
                let left = header.leadingToolbarGroup.convert(header.leadingToolbarGroup.bounds, to: header.pillBar)
                let right = header.trailingToolbarGroup.convert(header.trailingToolbarGroup.bounds, to: header.pillBar)
                XCTAssertEqual(left.minX, 16, accuracy: 0.5)
                XCTAssertEqual(right.maxX, bar.width - 16, accuracy: 0.5)
                XCTAssertGreaterThanOrEqual(right.minX - left.maxX, 7.5)
                XCTAssertEqual(left.height, 44, accuracy: 0.5)
                XCTAssertEqual(right.height, 44, accuracy: 0.5)
                if width == 500 {
                    XCTAssertEqual(header.searchPill.configuration?.title, "SEARCH",
                                   "Search text should fit even if Related Sites uses only its icon")
                }
                if width >= 330 {
                    XCTAssertFalse(header.usesMergedToolbar, "Hiding the Search label must not merge the footer")
                    XCTAssertNil(header.mergedToolbarGroup.effect)
                    XCTAssertNotNil(header.leadingToolbarGroup.effect)
                    XCTAssertNotNil(header.trailingToolbarGroup.effect)
                }
                if width >= 667 {
                    XCTAssertFalse(header.usesMergedToolbar)
                    XCTAssertNil(header.mergedToolbarGroup.effect)
                    if let wideGroupWidth { XCTAssertEqual(left.width, wideGroupWidth, accuracy: 0.5) }
                    else { wideGroupWidth = left.width }
                    if width == 1024, let previousWideGap {
                        XCTAssertGreaterThanOrEqual(right.minX - left.maxX, previousWideGap)
                    }
                    previousWideGap = right.minX - left.maxX
                    XCTAssertEqual(header.optionsPill.configuration?.title, "UNREAD · NEWEST")
                    XCTAssertEqual(header.searchPill.configuration?.title, "SEARCH")
                }
            }
        }
    }

    func test_optionsTextDisappearsBeforeWrappingWhenPaneNarrows() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "story_toolbar_position")
        defaults.set("bottom", forKey: "story_toolbar_position")
        defer { defaults.set(saved, forKey: "story_toolbar_position") }
        for filter in ["unread", "all"] {
            let parent = UIView(frame: CGRect(x: 0, y: 0, width: 600, height: 667))
            let header = StoryTitlesHeaderBar()
            header.setup(in: parent)
            header.updateOptionsPill(order: "newest", readFilter: filter)
            for width: CGFloat in [600, 330, 284, 600] {
                parent.frame.size.width = width
                parent.setNeedsLayout()
                parent.layoutIfNeeded()
                header.relayoutPills()
                parent.layoutIfNeeded()
                let title = header.optionsPill.configuration?.title ?? ""
                if width == 284 {
                    XCTAssertTrue(title.isEmpty, "A narrow four-control toolbar must use the dropdown icon instead of vertical text")
                    XCTAssertNotNil(header.optionsPill.configuration?.image)
                }
                if width == 600 {
                    XCTAssertEqual(title, "\(filter.uppercased()) · NEWEST", "Widening the pane must restore the full label")
                }
                if let label = header.optionsPill.titleLabel { XCTAssertEqual(label.numberOfLines, 1) }
                XCTAssertLessThanOrEqual(header.searchPill.bounds.width, 100, "Search must not expand into the flexible space")
                XCTAssertEqual(header.optionsPill.accessibilityLabel, "\(filter.uppercased()) · NEWEST")
            }
        }
    }

    func test_markReadPlusPresentsAboveFooterWithoutChangingGlass() async throws {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "story_toolbar_position")
        defaults.set("bottom", forKey: "story_toolbar_position")
        defer { defaults.set(saved, forKey: "story_toolbar_position") }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let owner = UIViewController()
        let navigation = UINavigationController(rootViewController: owner)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKey() }
        let header = StoryTitlesHeaderBar()
        header.setup(in: owner.view)
        header.updateMarkReadMenuFull(title: "NPR News", showVisibleOption: true, visibleCount: 3)
        var markCalls = 0
        header.markReadHandler = { _ in markCalls += 1 }
        header.markReadVisibleHandler = { markCalls += 1 }
        window.layoutIfNeeded()
        await Task.yield()
        owner.view.layoutIfNeeded()
        let originalFrame = header.headerContainer.frame
        header.markReadExpandButton.sendActions(for: .touchUpInside)
        try await Task.sleep(nanoseconds: 500_000_000)
        let menu = try XCTUnwrap(navigation.presentedViewController ?? owner.presentedViewController,
                                "The + action should present a separate popover instead of a context menu on the shared glass")
        let popover = try XCTUnwrap(menu.popoverPresentationController)
        XCTAssertEqual(menu.modalPresentationStyle, .popover)
        XCTAssertNil(popover.sourceItem)
        XCTAssertEqual(header.headerContainer.frame, originalFrame)
        let menuFrame = menu.view.convert(menu.view.bounds, to: window)
        let barFrame = header.pillBar.convert(header.pillBar.bounds, to: window)
        XCTAssertLessThan(menuFrame.maxY, barFrame.minY + 4)
        XCTAssertTrue(popover.passthroughViews?.isEmpty ?? true)
        XCTAssertEqual(markCalls, 0, "Opening the menu must not mark any stories read")
        let menuController = try XCTUnwrap((menu as? UINavigationController)?.topViewController as? MenuViewController)
        for cell in menuController.menuTableView.visibleCells {
            let icon = try XCTUnwrap(cell.imageView?.image)
            XCTAssertLessThanOrEqual(icon.size.width, 20)
            XCTAssertLessThanOrEqual(icon.size.height, 20)
        }
        let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: screenshot)
        attachment.name = "mark-read-popover-above-unified-footer"
        attachment.lifetime = .keepAlways
        add(attachment)
        menu.dismiss(animated: false)
        owner.view.layoutIfNeeded()
        XCTAssertEqual(header.headerContainer.frame, originalFrame)
        XCTAssertEqual(markCalls, 0)
    }

    func test_liveAlphaSearchFooterAndReturnToolbar() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Requires the connected NB Alpha device")
        #else
        guard Bundle.main.bundleIdentifier == "com.newsblur.NB-Alpha" else {
            throw XCTSkip("Requires NB Alpha")
        }
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        let feeds = try XCTUnwrap(app.feedsViewController)
        for _ in 0..<100 {
            if feeds.viewIfLoaded?.window != nil { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        app.showFeedsList(animated: false)
        feeds.selectEverything(nil)
        let detail = try XCTUnwrap(app.feedDetailViewController)
        // FeedToolbarLayoutTests.swift waits for initial reader routing before testing keyboard focus.
        for _ in 0..<300 {
            if detail.viewIfLoaded?.window != nil && detail.transitionCoordinator == nil &&
                !detail.pageFetching && detail.storiesCollection.storyLocationsCount > 0 &&
                (UIDevice.current.userInterfaceIdiom == .phone || app.activeStory != nil) { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertFalse(detail.pageFetching, "Initial story loading must finish before opening Search")
        if UIDevice.current.userInterfaceIdiom == .pad {
            var readySamples = 0
            for _ in 0..<100 {
                let readerReady = !detail.pageFetching && !detail.isShowingFetching &&
                    detail.transitionCoordinator == nil && detail.storiesCollection.storyLocationsCount > 0
                readySamples = readerReady ? readySamples + 1 : 0
                if readySamples >= 10 { break }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            XCTAssertGreaterThanOrEqual(readySamples, 10, "Initial story list loading must settle before opening Search")
        }
        let window = try XCTUnwrap(detail.view.window)
        let header = try XCTUnwrap(detail.storyTitlesHeaderBar)
        XCTAssertTrue(header.usesFloatingBottomBar)
        if !header.isSearchActive { header.searchPill.sendActions(for: .touchUpInside) }
        defer { detail.searchField.resignFirstResponder(); header.setSearchActive(false) }
        try await Task.sleep(nanoseconds: 600_000_000)
        detail.view.layoutIfNeeded()
        XCTAssertTrue(detail.searchField.isFirstResponder)
        XCTAssertEqual(header.searchContainer.frame.minX, header.pillBar.frame.minX + 16, accuracy: 0.5)
        XCTAssertEqual(header.searchContainer.frame.maxX, header.pillBar.frame.maxX - 16, accuracy: 0.5)
        let field = try XCTUnwrap(detail.searchField)
        XCTAssertEqual(field.frame.minY, header.searchContainer.bounds.height - field.frame.maxY, accuracy: 0.5)
        XCTAssertEqual(field.frame.minX, header.searchContainer.bounds.width - header.searchCancelButton.frame.maxX, accuracy: 0.5)
        let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: screenshot)
        attachment.name = "live-search-footer-even-margins"
        attachment.lifetime = .keepAlways
        add(attachment)
        header.searchCancelButton.sendActions(for: .touchUpInside)
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertFalse(field.isFirstResponder)
        XCTAssertFalse(header.isSearchActive)
        let footerFrame = header.headerContainer.frame
        header.markReadExpandButton.sendActions(for: .touchUpInside)
        try await Task.sleep(nanoseconds: 500_000_000)
        let menu = try XCTUnwrap(detail.navigationController?.presentedViewController)
        XCTAssertEqual(menu.modalPresentationStyle, .popover)
        XCTAssertNil(menu.popoverPresentationController?.sourceItem)
        XCTAssertEqual(header.headerContainer.frame, footerFrame)
        let menuFrame = menu.view.convert(menu.view.bounds, to: window)
        let barFrame = header.pillBar.convert(header.pillBar.bounds, to: window)
        XCTAssertLessThan(menuFrame.maxY, barFrame.minY + 4)
        let menuImage = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let menuAttachment = XCTAttachment(image: menuImage)
        menuAttachment.name = "live-mark-read-popover-keeps-footer"
        menuAttachment.lifetime = .keepAlways
        add(menuAttachment)
        // FeedToolbarLayoutTests.swift dismisses without choosing an action to preserve unread stories.
        menu.dismiss(animated: false)
        detail.view.layoutIfNeeded()
        XCTAssertEqual(header.headerContainer.frame, footerFrame)
        if UIDevice.current.userInterfaceIdiom == .phone {
            let toolbar = try XCTUnwrap(feeds.feedViewToolbar)
            var widths = [CGFloat]()
            app.showFeedsList(animated: true)
            for _ in 0..<60 {
                widths.append(toolbar.bounds.width)
                try await Task.sleep(nanoseconds: 16_000_000)
            }
            XCTAssertLessThanOrEqual((widths.max() ?? 0) - (widths.min() ?? 0), 1,
                                     "The toolbar must keep its width throughout native Back: \(widths)")
            XCTAssertEqual(feeds.intelligenceControl.widthForSegment(at: 1), 68)
        }
        #endif
    }

    func test_searchRowMatchesToolbarMarginsAndCentersItsContents() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "story_toolbar_position")
        defaults.set("bottom", forKey: "story_toolbar_position")
        defer { defaults.set(saved, forKey: "story_toolbar_position") }
        for width: CGFloat in [320, 375, 430, 600] {
            let parent = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 667))
            let header = StoryTitlesHeaderBar()
            header.setup(in: parent)
            let field = UITextField()
            field.placeholder = "Search stories"
            header.addSearchField(field)
            header.setSearchActive(true)
            parent.layoutIfNeeded()
            let row = header.searchContainer
            XCTAssertEqual(row.frame.minX, header.pillBar.frame.minX + 16, accuracy: 0.5)
            XCTAssertEqual(row.frame.maxX, header.pillBar.frame.maxX - 16, accuracy: 0.5)
            XCTAssertEqual(field.frame.minY, row.bounds.height - field.frame.maxY, accuracy: 0.5,
                           "Search input needs equal top and bottom padding")
            XCTAssertEqual(field.frame.minX, row.bounds.width - header.searchCancelButton.frame.maxX, accuracy: 0.5,
                           "Input and close button need equal outer padding")
            XCTAssertEqual(field.frame.midY, header.searchCancelButton.frame.midY, accuracy: 0.5)
            XCTAssertGreaterThan(header.searchCancelButton.frame.minX, field.frame.maxX)
        }
    }

    func test_markReadTapTargetHasBalancedPaddingAtNarrowWidths() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "story_toolbar_position")
        defaults.set("bottom", forKey: "story_toolbar_position")
        defer { defaults.set(saved, forKey: "story_toolbar_position") }
        for width: CGFloat in [320, 330, 375, 430] {
            let parent = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 667))
            let header = StoryTitlesHeaderBar()
            header.setup(in: parent)
            header.updateOptionsPill(order: "newest", readFilter: "unread")
            parent.layoutIfNeeded()
            let mark = header.markReadPill
            XCTAssertGreaterThanOrEqual(mark.bounds.width, 52, "Mark Read needs a generous target even with Related Sites visible")
            if let insets = mark.configuration?.contentInsets {
                XCTAssertEqual(insets.leading, insets.trailing, accuracy: 0.5)
            }
            let markFrame = mark.convert(mark.bounds, to: parent)
            let plusFrame = header.markReadExpandButton.convert(header.markReadExpandButton.bounds, to: parent)
            XCTAssertGreaterThanOrEqual(markFrame.minX, plusFrame.maxX)
            XCTAssertLessThanOrEqual(markFrame.maxX, parent.bounds.maxX - 16)
            XCTAssertGreaterThanOrEqual(header.searchPill.bounds.width, 44)
            XCTAssertGreaterThanOrEqual(header.discoverPill.bounds.width, 44)
        }
    }

    func test_feedToolbarKeepsLabelsWhenBackRestoresLayoutMargins() throws {
        let storyboard = UIStoryboard(name: "MainInterface", bundle: Bundle(for: FeedsViewController.self))
        let controller = storyboard.instantiateViewController(identifier: "FeedsViewController") { HorizontalToolbarFeeds(coder: $0) }
        controller.loadViewIfNeeded()
        controller.appDelegate = NewsBlurAppDelegate()
        let parent = try XCTUnwrap(controller.view)
        parent.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        let navigation = UINavigationController(rootViewController: controller)
        navigation.view.frame = parent.frame
        let toolbar = try XCTUnwrap(controller.feedViewToolbar)
        // FeedToolbarLayoutTests.swift uses the real storyboard/controller constraints and the margins
        // captured during ClayPhone SE's native interactive Back, including the final restoration to 16.
        for right: CGFloat in [16, 0, 1, 1.5, 2.5, 16] {
            parent.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: right)
            parent.setNeedsLayout()
            parent.layoutIfNeeded()
            controller.viewDidLayoutSubviews()
            parent.layoutIfNeeded()
            let expectedWidth: CGFloat
            if #available(iOS 27.0, *) { expectedWidth = 375 } else { expectedWidth = 359 }
            XCTAssertEqual(toolbar.bounds.width, expectedWidth, accuracy: 0.5)
            XCTAssertEqual(controller.intelligenceControl.widthForSegment(at: 1), 68,
                           "Changing child margins must not change the toolbar's available width")
        }
        withExtendedLifetime(navigation) {}
    }

    func test_storyToolbarDefaultsToBottomAndHonorsExplicitTopPreference() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "story_toolbar_position")
        defer { defaults.set(saved, forKey: "story_toolbar_position") }
        defaults.removeObject(forKey: "story_toolbar_position")
        #if !targetEnvironment(macCatalyst)
        XCTAssertTrue(StoryTitlesHeaderBar().usesFloatingBottomBar,
                      "Both iPhone and iPad should default to the bottom toolbar")
        defaults.set("top", forKey: "story_toolbar_position")
        XCTAssertFalse(StoryTitlesHeaderBar().usesFloatingBottomBar)
        defaults.set("bottom", forKey: "story_toolbar_position")
        XCTAssertTrue(StoryTitlesHeaderBar().usesFloatingBottomBar)
        #endif
    }

    func test_livePadSettingsPopoverLeavesToolbarVisible() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Requires the connected iPad Alpha app")
        #else
        guard UIDevice.current.userInterfaceIdiom == .pad,
              Bundle.main.bundleIdentifier == "com.newsblur.NB-Alpha" else {
            throw XCTSkip("Requires NB Alpha on iPad")
        }
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        let feeds = try XCTUnwrap(app.feedsViewController)
        for _ in 0..<100 {
            if feeds.viewIfLoaded?.window != nil { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        let window = try XCTUnwrap(feeds.view.window)
        feeds.showSettingsPopover(nil)
        try await Task.sleep(nanoseconds: 600_000_000)
        let menu = try XCTUnwrap(feeds.navigationController?.presentedViewController ?? feeds.presentedViewController)
        defer { menu.dismiss(animated: false) }
        let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: screenshot)
        attachment.name = "claypad-settings-above-feed-toolbar"
        attachment.lifetime = .keepAlways
        add(attachment)
        let popover = try XCTUnwrap(menu.popoverPresentationController)
        XCTAssertNil(popover.sourceItem, "A bar item source morphs the shared toolbar into the menu on iOS 26+")
        let toolbar = try XCTUnwrap(feeds.feedViewToolbar)
        let toolbarFrame = toolbar.convert(toolbar.bounds, to: window)
        let menuFrame = menu.view.convert(menu.view.bounds, to: window)
        XCTAssertLessThan(menuFrame.maxY, toolbarFrame.minY, "Settings must float above the full feed toolbar")
        if #available(iOS 17.0, *), let source = popover.sourceView {
            let anchor = source.convert(popover.sourceRect, to: window)
            let gear = try XCTUnwrap(feeds.settingsBarButton.frame(in: window))
            XCTAssertEqual(anchor.midX, gear.midX, accuracy: 1, "The popover must point to Settings, not the middle of the bar")
        }
        XCTAssertTrue(popover.passthroughViews?.isEmpty ?? true, "Tapping the bar should dismiss settings")
        #endif
    }

    func test_floatingToolbarGlassAppearanceAcrossThemes() async throws {
        let defaults = UserDefaults.standard
        let keys = ["story_toolbar_position", "theme_style", "theme_light", "theme_dark", "discover_display"]
        let saved = keys.map { defaults.object(forKey: $0) }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            previousWindow?.makeKey()
            for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) }
        }
        defaults.set("bottom", forKey: "story_toolbar_position")
        defaults.set("with_icons", forKey: "discover_display")
        for theme in ["light", "sepia", "medium", "dark"] {
            let dark = theme == "medium" || theme == "dark"
            defaults.set(dark ? "dark" : "light", forKey: "theme_style")
            defaults.set(theme, forKey: dark ? "theme_dark" : "theme_light")
            controller.overrideUserInterfaceStyle = dark ? .dark : .light
            controller.view.subviews.forEach { $0.removeFromSuperview() }
            controller.view.backgroundColor = ThemeManager.shared?.color(fromLightRGB: 0xECEEEA, sepiaRGB: 0xFAF5ED, mediumRGB: 0x444444, darkRGB: 0x222222)
            var headers = [StoryTitlesHeaderBar]()
            for (index, width) in [CGFloat(330), 375].enumerated() {
                let parent = UIView(frame: CGRect(x: 16, y: CGFloat(80 + index * 220), width: min(width, window.bounds.width - 32), height: 180))
                controller.view.addSubview(parent)
                let background = UILabel(frame: parent.bounds.insetBy(dx: 12, dy: 12))
                background.text = "\(theme.capitalized) • \(index == 0 ? "Related Sites" : "All Site Stories")\n\nStory content behind the floating toolbar"
                background.numberOfLines = 0
                background.textColor = dark ? .lightGray : .darkGray
                parent.addSubview(background)
                let header = StoryTitlesHeaderBar()
                header.setup(in: parent)
                header.updateOptionsPill(order: "newest", readFilter: "unread")
                header.updateDiscoverVisibility(isRiver: true, isEverything: index == 1, isSocial: false, isSaved: false, isRead: false, isWidget: false, isInfrequent: false)
                parent.layoutIfNeeded()
                for button in [header.optionsPill, header.searchPill, header.markReadExpandButton, header.markReadPill] {
                    let center = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: parent)
                    let hit = parent.hitTest(center, with: nil)
                    XCTAssertTrue(hit === button || hit?.isDescendant(of: button) == true)
                    XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
                }
                XCTAssertGreaterThanOrEqual(header.searchPill.bounds.width, 44,
                                            "The icon-only Search action must retain a full touch target")
                if !header.discoverPill.isHidden {
                    XCTAssertGreaterThanOrEqual(header.discoverPill.bounds.width, 44)
                }
                headers.append(header)
            }
            func capture(_ state: String) -> Data? {
                let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                let attachment = XCTAttachment(image: screenshot)
                attachment.name = "story-toolbar-\(theme)-\(state)"
                attachment.lifetime = .keepAlways
                add(attachment)
                return screenshot.pngData()
            }
            try await Task.sleep(nanoseconds: 300_000_000)
            let normal = capture("normal")
            headers.forEach { $0.optionsPill.isHighlighted = true }
            try await Task.sleep(nanoseconds: 300_000_000)
            XCTAssertNotEqual(normal, capture("pressed"), "Touching the options control must have visible feedback")
            headers.forEach { $0.optionsPill.isHighlighted = false }
        }
    }

    func test_floatingToolbarControlsSupportPointerFeedbackAndPreserveDisabledState() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "story_toolbar_position")
        defaults.set("bottom", forKey: "story_toolbar_position")
        defer { defaults.set(saved, forKey: "story_toolbar_position") }
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
        let header = StoryTitlesHeaderBar()
        header.setup(in: parent)
        parent.layoutIfNeeded()
        for button in [header.discoverPill, header.optionsPill, header.searchPill,
                       header.markReadExpandButton, header.markReadPill] {
            XCTAssertTrue(button.isPointerInteractionEnabled,
                          "Every enabled story toolbar action should provide native pointer feedback")
            XCTAssertTrue(button.isEnabled)
            if #available(iOS 26.0, *) {
                var ancestor: UIView? = button.superview
                while ancestor != nil && (ancestor as? UIVisualEffectView)?.effect == nil { ancestor = ancestor?.superview }
                let surface = ancestor as? UIVisualEffectView
                XCTAssertNotNil(surface, "Controls must sit inside the interactive glass surface")
                XCTAssertEqual((surface?.effect as? UIGlassEffect)?.isInteractive, true)
                let isMarkRead = button === header.markReadExpandButton || button === header.markReadPill
                let expected = header.usesMergedToolbar ? header.mergedToolbarGroup :
                    (isMarkRead ? header.trailingToolbarGroup : header.leadingToolbarGroup)
                XCTAssertTrue(surface === expected,
                              "Controls must share the glass surface for their side of the footer")
            }
        }
        header.updateMarkReadEnabled(false)
        XCTAssertFalse(header.markReadPill.isEnabled)
        XCTAssertFalse(header.markReadExpandButton.isEnabled)
        XCTAssertTrue(header.optionsPill.isEnabled)
        XCTAssertTrue(header.searchPill.isEnabled)
        header.updateMarkReadEnabled(true)
        XCTAssertTrue(header.markReadPill.isEnabled)
        XCTAssertEqual(header.markReadContainer.alpha, 1)
    }

    func test_floatingToolbarRefreshNeverAppliesOpaqueInactiveButtonBackgrounds() {
        assertRefreshPreservesButtonBackgrounds(searchActive: false)
    }

    func test_floatingToolbarRefreshKeepsActiveSearchHighlight() {
        assertRefreshPreservesButtonBackgrounds(searchActive: true)
    }

    private func assertRefreshPreservesButtonBackgrounds(searchActive: Bool) {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "story_toolbar_position")
        defaults.set("bottom", forKey: "story_toolbar_position")
        defer { defaults.set(saved, forKey: "story_toolbar_position") }
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
        let header = StoryTitlesHeaderBar()
        header.setup(in: parent)
        header.setSearchActive(searchActive)
        parent.layoutIfNeeded()
        let buttons = [header.optionsPill, header.searchPill]
        let expected = buttons.map { $0.backgroundColor ?? .clear }
        var intermediateColors = [[UIColor](), [UIColor]()]
        let observations = buttons.enumerated().map { index, button in
            button.observe(\.backgroundColor, options: [.new]) { observed, _ in
                intermediateColors[index].append(observed.backgroundColor ?? .clear)
            }
        }
        withExtendedLifetime(observations) {
            for _ in 0..<3 {
                // FeedToolbarLayoutTests.swift mirrors the header updates made by each received story page.
                header.setDailyBriefingMode(false)
                header.updateOptionsPill(order: "newest", readFilter: "unread")
                header.updateTheme()
            }
        }
        for index in buttons.indices {
            XCTAssertTrue(intermediateColors[index].allSatisfy { $0.isEqual(expected[index]) },
                          "Button \(index) must never briefly receive a different background during page refresh: \(intermediateColors[index])")
            XCTAssertEqual(buttons[index].backgroundColor, expected[index])
        }
    }

    func test_regularSidebarUsesOneGroupAndKeepsLabelsAt375Points() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("Requires the iOS 27 native toolbar") }
        let storyboard = UIStoryboard(name: "MainInterface", bundle: Bundle(for: FeedsViewController.self))
        let controller = storyboard.instantiateViewController(identifier: "FeedsViewController") { HorizontalToolbarFeeds(coder: $0) }
        controller.loadViewIfNeeded()
        let app = NewsBlurAppDelegate()
        let detail = ToolbarRegularWidthDetail()
        app.detailViewController = detail
        controller.appDelegate = app
        controller.view.frame = CGRect(x: 0, y: 0, width: 375, height: 820)
        controller.viewDidLayoutSubviews()
        // FeedToolbarLayoutTests.swift resolves toolbar edge constraints without a host window.
        let leading = controller.toolbarLeadingConstraint.constant
        let trailing = controller.toolbarTrailingConstraint.constant
        controller.feedViewToolbar.frame = CGRect(x: leading, y: 0, width: 375 - leading - trailing, height: 48)
        controller.layout(for: .landscapeLeft)
        XCTAssertEqual(controller.feedViewToolbar.items?.count, 3, "Spacers split the toolbar into separate glass groups")
        XCTAssertTrue(controller.feedViewToolbar.items?.first === controller.addBarButton)
        XCTAssertTrue(controller.feedViewToolbar.items?.last === controller.settingsBarButton)
        XCTAssertEqual(controller.intelligenceControl.widthForSegment(at: 1), 68)
        XCTAssertEqual(controller.intelligenceControl.widthForSegment(at: 2), 62)
        XCTAssertEqual(controller.intelligenceControl.widthForSegment(at: 3), 60)

        controller.feedViewToolbar.frame.size.width = 286
        controller.layout(for: .landscapeLeft)
        XCTAssertEqual(controller.feedViewToolbar.items?.count, 3)
        XCTAssertLessThan(controller.intelligenceControl.widthForSegment(at: 1), 68)
        XCTAssertEqual(controller.intelligenceControl.numberOfSegments, 4)

        controller.feedViewToolbar.frame.size.width = 375
        controller.layout(for: .landscapeLeft)
        XCTAssertEqual(controller.intelligenceControl.widthForSegment(at: 1), 68,
                       "Widening the sidebar must restore the text labels")
    }

    func test_livePadToolbarUsesOneGroup() async throws {
#if targetEnvironment(simulator)
        throw XCTSkip("Requires the connected iPad Alpha app")
#else
        guard #available(iOS 27.0, *), UIDevice.current.userInterfaceIdiom == .pad,
              Bundle.main.bundleIdentifier == "com.newsblur.NB-Alpha" else {
            throw XCTSkip("Requires NewsBlur Alpha on iPad with iOS 27")
        }
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        for _ in 0..<100 {
            if app.feedsViewController?.viewIfLoaded?.window != nil { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        let feeds = try XCTUnwrap(app.feedsViewController)
        feeds.view.layoutIfNeeded()
        XCTAssertEqual(feeds.feedViewToolbar.items?.count, 3)
        XCTAssertTrue(feeds.feedViewToolbar.items?.first === feeds.addBarButton)
        XCTAssertTrue(feeds.feedViewToolbar.items?.last === feeds.settingsBarButton)
        // FeedToolbarLayoutTests.swift checks rendered hit targets because items can exist while UIKit puts them in overflow.
        let control = try XCTUnwrap(feeds.intelligenceControl)
        let toolbar = try XCTUnwrap(feeds.feedViewToolbar)
        func assertFiltersAreTappable() {
            for index in 0..<control.numberOfSegments {
                let segmentWidth = control.bounds.width / CGFloat(control.numberOfSegments)
                let point = control.convert(CGPoint(x: (CGFloat(index) + 0.5) * segmentWidth, y: control.bounds.midY), to: toolbar)
                let hit = toolbar.hitTest(point, with: nil)
                XCTAssertTrue(hit === control || hit?.isDescendant(of: control) == true,
                              "Intelligence segment \(index) must be directly tappable, not hidden in overflow")
            }
        }
        let window = try XCTUnwrap(feeds.view.window)
        func capture(_ name: String) {
            let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: screenshot)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        assertFiltersAreTappable()
        capture("claypad-single-toolbar-group")
        let split = try XCTUnwrap(app.splitViewController)
        let previousWidth = split.preferredPrimaryColumnWidth
        let previousMinimum = split.minimumPrimaryColumnWidth
        let previousMaximum = split.maximumPrimaryColumnWidth
        let previousSavedWidth = UserDefaults.standard.object(forKey: "split_primary_width")
        defer {
            split.minimumPrimaryColumnWidth = previousMinimum
            split.maximumPrimaryColumnWidth = previousMaximum
            split.preferredPrimaryColumnWidth = previousWidth
            split.view.setNeedsLayout()
            split.view.layoutIfNeeded()
            UserDefaults.standard.set(previousSavedWidth, forKey: "split_primary_width")
        }
        split.maximumPrimaryColumnWidth = 375
        split.minimumPrimaryColumnWidth = 375
        split.preferredPrimaryColumnWidth = 375
        split.view.setNeedsLayout()
        split.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(toolbar.bounds.width, 375, accuracy: 1, "The live resize fixture must reach the labeled width")
        XCTAssertEqual(control.widthForSegment(at: 1), 68)
        XCTAssertEqual(control.widthForSegment(at: 2), 62)
        XCTAssertEqual(control.widthForSegment(at: 3), 60)
        assertFiltersAreTappable()
        capture("claypad-single-toolbar-full-labels")
#endif
    }
}

@MainActor private final class ToolbarRegularWidthDetail: DetailViewController {
    override var isPhoneOrCompact: Bool { false }
}

@MainActor private final class FeedDepartureFeeds: FeedsViewController {
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 600)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
}

@MainActor private final class FeedDepartureNavigation: UINavigationController {
    var forwardedPopover: UIViewController?
    var simulatedTop: UIViewController?
    override var presentedViewController: UIViewController? { forwardedPopover }
    override var topViewController: UIViewController? { simulatedTop ?? super.topViewController }
}

@MainActor private final class FeedDepartureDialog: UINavigationController {
    var dismissalCount = 0
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        dismissalCount += 1
        completion?()
    }
}

@MainActor private final class DuoPhoneReaderLayout: DetailViewController {
    var simulatesPhone = true
    override var isPhone: Bool { simulatesPhone }
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        if #available(iOS 17.0, *) { traitOverrides.verticalSizeClass = .regular }
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        if #available(iOS 17.0, *) { traitOverrides.verticalSizeClass = .regular }
    }
}

@MainActor private final class DuoPendingTiledReaderDetail: DetailViewController {
    var resolvesTiledFeeds = false
    override var showsStoryTitlesBesideTiledFeeds: Bool { resolvesTiledFeeds }
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 474, height: 669)) }
    override func viewDidLoad() {}
}

@MainActor private final class DuoPagerResizeApp: NewsBlurAppDelegate {
    override var feedDetailViewController: FeedDetailViewController! { nil }
    override func changeActiveFeedDetailRow() {}
    override func show(_ column: UISplitViewController.Column, debugInfo: String!, animated: Bool) {}
}

@MainActor private final class DuoPagerResizePages: StoryPagesViewController {
    override var isHorizontal: Bool { true }
    override var useCustomToolbar: Bool { false }
    override var usesVerticalReaderToolbar: Bool { true }
    override func loadView() {
        view = UIView(frame: CGRect(x: 0, y: 0, width: 474, height: 600))
        scrollView = UIScrollView(frame: view.bounds)
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.isPagingEnabled = true
        view.addSubview(scrollView)
    }
    override func viewDidLoad() {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
    override func updateStoryTitleNavigationButtons() {}
    override func setNextPreviousButtons() {}
    override func setTextButton() {}
    override func setTextButton(_ storyViewController: StoryDetailViewController!) {}
}

@MainActor private final class DuoPagerResizePage: StoryDetailViewController {
    var documentInvalidations = 0
    override func loadView() {
        view = UIView(frame: CGRect(x: 0, y: 0, width: 474, height: 600))
        webView = WKWebView(frame: view.bounds)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)
    }
    override func viewDidLoad() {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
    override func clearStory() { documentInvalidations += 1 }
    override func initStory() { documentInvalidations += 1 }
    override func drawStory() { documentInvalidations += 1 }
    override func showTextOrStoryView() {}
    override func drawFeedGradient() {}
    override func refreshHeader() {}
    override func refreshSideOptions() {}
    deinit { webView = nil }
}

@MainActor private final class DuoPagerResizeNavigationDelegate: NSObject, WKNavigationDelegate {
    var didLoad: (() -> Void)?
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { didLoad?() }
}

@MainActor private final class DuoScrollingHeaderPages: StoryPagesViewController {
    var verticalToolbar = true
    var simulatesPhone = true
    override var isPhone: Bool { simulatesPhone }
    override var usesVerticalReaderToolbar: Bool { verticalToolbar }
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 360, height: 600)) }
    override func viewDidLoad() {}
    override func updateStoryTitleNavigationButtons() {}
    override func updateStatusBarState() {}
    override func setNextPreviousButtons() {}
}

@MainActor private final class DuoScrollingHeaderPage: StoryDetailViewController {
    override func loadView() {
        view = UIView(frame: CGRect(x: 0, y: 0, width: 360, height: 600))
        webView = DuoScrollingHeaderWebView(frame: view.bounds)
        view.addSubview(webView)
    }
    override func viewDidLoad() {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
    deinit { webView = nil }
}

@MainActor private final class DuoScrollingHeaderWebView: WKWebView {
    private let testScrollView = DuoScrollingHeaderScrollView()
    override var scrollView: UIScrollView { testScrollView }
}

@MainActor private final class DuoScrollingHeaderScrollView: UIScrollView {
    var simulatedSafeAreaInsets: UIEdgeInsets?
    var simulatesTracking = false
    var simulatesDragging = false
    override var safeAreaInsets: UIEdgeInsets { simulatedSafeAreaInsets ?? super.safeAreaInsets }
    override var isTracking: Bool { simulatesTracking }
    override var isDragging: Bool { simulatesDragging }
}

@MainActor private final class DuoIndicatorWindow: UIWindow {
    var protectedTop: CGFloat = 0
    override var safeAreaInsets: UIEdgeInsets {
        UIEdgeInsets(top: protectedTop, left: 0, bottom: 34, right: 0)
    }
}

@MainActor private final class LandscapeReaderWindow: UIWindow {
    override var safeAreaInsets: UIEdgeInsets { .zero }
}

@MainActor private final class LandscapeReaderAppDelegate: NewsBlurAppDelegate {
    // FeedToolbarLayoutTests.swift exercises the compact landscape toolbar regardless of the test host's idiom.
    override var isCompactWidth: Bool { true }
}

@MainActor private final class LandscapeReaderPages: StoryPagesViewController {
    override var useCustomToolbar: Bool { true }
    override var usesVerticalReaderToolbar: Bool { false }
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 667, height: 375)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
}

@MainActor private final class HorizontalToolbarFeeds: FeedsViewController {
    // FeedToolbarLayoutTests.swift exercises the ordinary horizontal toolbar on any test host.
    @objc func usesVerticalFeedToolbar() -> Bool { false }
}
