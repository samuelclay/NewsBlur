import XCTest
import UIKit
import WebKit

@testable import NewsBlur

// DuoPresentationTests.swift sends the divider's real action deterministic positions while UIKit owns the mounted column layout.
private final class DuoSidebarResizePan: FeedsSidebarResizePanGestureRecognizer {
    var simulatedState: UIGestureRecognizer.State = .possible
    var simulatedLocation = CGPoint.zero
    var simulatedTranslation = CGPoint.zero
    var simulatedTouchDownLocation: CGPoint?
    override var state: UIGestureRecognizer.State {
        get { simulatedState }
        set { simulatedState = newValue }
    }
    override func location(in view: UIView?) -> CGPoint { simulatedLocation }
    override func translation(in view: UIView?) -> CGPoint { simulatedTranslation }
    override func touchDownLocation(in view: UIView) -> CGPoint? { simulatedTouchDownLocation }
}

@MainActor final class Test_DuoReaderReparenting: XCTestCase {
    func test_completedCollapseRestoresReaderAfterUIKitPopsTheEarlyRestoredStack() async {
        let fixture = makeCollapseCompletionFixture()
        defer { fixture.releaseControllers() }
        let callbacks: UISplitViewControllerDelegate = fixture.delegate
        _ = fixture.delegate.splitViewController(fixture.split, topColumnForCollapsingToProposedTopColumn: .secondary)
        await drainCollapseCallbacks()

        // DuoPresentationTests.swift reproduces fold95: UIKit pops the app's early restored stack in its next layout pass.
        fixture.detail.restoreCompactNavigationAfterSplitCollapse(showFeed: true, showStory: true)
        fixture.navigation.popToRootViewController(animated: false)
        fixture.page.viewDidDisappear(false)
        XCTAssertEqual(fixture.page.clearStoryCount, 0, "The exact article awaiting collapse completion must survive temporary detachment")
        callbacks.splitViewControllerDidCollapse?(fixture.split)
        await drainCollapseCallbacks()

        XCTAssertEqual(fixture.navigation.viewControllers.map(ObjectIdentifier.init),
                       [fixture.feeds, fixture.titles, fixture.pages].map(ObjectIdentifier.init))
        XCTAssertTrue(fixture.pages.currentPage === fixture.page)
        XCTAssertTrue(fixture.page.hasStory)
        XCTAssertEqual(fixture.page.activeStoryId, "collapse:article")
        XCTAssertEqual(fixture.page.webView.scrollView.contentOffset.y, 700, accuracy: 0.5)
        XCTAssertEqual(fixture.page.value(forKey: "storyLoadGeneration") as? NSNumber, 9)
    }

    func test_completedCollapseCannotOverrideExplicitBackExpansionOrANewSource() async {
        for cancellation in ["back", "expand", "source", "article", "page"] {
            let fixture = makeCollapseCompletionFixture()
            defer { fixture.releaseControllers() }
            let callbacks: UISplitViewControllerDelegate = fixture.delegate
            _ = fixture.delegate.splitViewController(fixture.split, topColumnForCollapsingToProposedTopColumn: .secondary)
            await drainCollapseCallbacks()
            fixture.detail.restoreCompactNavigationAfterSplitCollapse(showFeed: true, showStory: true)
            switch cancellation {
            case "back":
                fixture.app.showFeedsList(animated: false)
            case "expand":
                fixture.split.simulatesCollapsed = false
                _ = fixture.delegate.splitViewController(fixture.split, displayModeForExpandingToProposedDisplayMode: .secondaryOnly)
            case "source":
                let replacement = StoriesCollection()
                replacement.appDelegate = fixture.app
                replacement.activeFeed = ["id": 2, "feed_title": "Another source"]
                fixture.app.storiesCollection = replacement
                fixture.navigation.popToRootViewController(animated: false)
            case "page":
                let replacement = DuoReparentPage()
                replacement.appDelegate = fixture.app
                replacement.activeStoryId = "collapse:article"
                fixture.pages.currentPage = replacement
                fixture.navigation.popToRootViewController(animated: false)
            default:
                fixture.app.activeStory = ["story_hash": "collapse:replacement"]
                fixture.navigation.popToRootViewController(animated: false)
            }
            fixture.page.viewDidDisappear(false)
            callbacks.splitViewControllerDidCollapse?(fixture.split)
            await drainCollapseCallbacks()

            XCTAssertTrue(fixture.navigation.topViewController === fixture.feeds, cancellation)
            XCTAssertEqual(fixture.page.clearStoryCount, 1, "Cancelled \(cancellation) handoff must not exempt an abandoned article from cleanup")
            XCTAssertFalse(fixture.page.hasStory, cancellation)
        }
    }

    func test_completedCollapseRetainsArticleWhenTransientTitlesAppearanceClearsSelection() async {
        let fixture = makeCollapseCompletionFixture()
        defer { fixture.releaseControllers() }
        let callbacks: UISplitViewControllerDelegate = fixture.delegate
        _ = fixture.delegate.splitViewController(fixture.split, topColumnForCollapsingToProposedTopColumn: .secondary)
        await drainCollapseCallbacks()
        fixture.detail.restoreCompactNavigationAfterSplitCollapse(showFeed: true, showStory: true)
        fixture.navigation.popToRootViewController(animated: false)
        // FeedDetailObjCViewController.m's compact viewDidAppear clears this selection through fadeSelectedCell:YES.
        fixture.app.activeStory = nil
        fixture.page.viewDidDisappear(false)
        XCTAssertEqual(fixture.page.clearStoryCount, 0)
        callbacks.splitViewControllerDidCollapse?(fixture.split)
        await drainCollapseCallbacks()

        XCTAssertTrue(fixture.navigation.topViewController === fixture.pages)
        XCTAssertEqual(fixture.app.activeStory?["story_hash"] as? String, "collapse:article")
        XCTAssertTrue(fixture.page.hasStory)
        XCTAssertEqual(fixture.page.webView.scrollView.contentOffset.y, 700, accuracy: 0.5)
        XCTAssertEqual(fixture.page.value(forKey: "storyLoadGeneration") as? NSNumber, 9)
    }

    private func drainCollapseCallbacks() async {
        let drained = expectation(description: "The queued collapse callback has run")
        DispatchQueue.main.async { drained.fulfill() }
        await fulfillment(of: [drained], timeout: 1)
    }

    private func makeCollapseCompletionFixture() -> DuoCollapseCompletionFixture {
        let app = NewsBlurAppDelegate()
        let collection = StoriesCollection()
        collection.appDelegate = app
        collection.activeFeed = ["id": 1, "feed_title": "Collapse source"]
        app.storiesCollection = collection
        app.activeStory = ["story_hash": "collapse:article"]
        let detail = DuoCollapseCompletionDetail()
        detail.traitOverrides.verticalSizeClass = .regular
        detail.appDelegate = app
        detail.isCompact = false
        app.detailViewController = detail
        detail.loadViewIfNeeded()
        let titles = DuoCollapseCompletionTitles()
        titles.appDelegate = app
        titles.storiesCollection = collection
        detail.feedDetailViewController = titles
        let pages = DuoReparentPages()
        pages.appDelegate = app
        pages.loadViewIfNeeded()
        detail.storyPagesViewController = pages
        let page = pages.currentPage as! DuoReparentPage
        page.appDelegate = app
        page.activeStory = ["story_hash": "collapse:article"]
        page.activeStoryId = "collapse:article"
        page.hasStory = true
        page.setValue(9, forKey: "storyLoadGeneration")
        page.webView.scrollView.contentSize = CGSize(width: 450, height: 2500)
        page.webView.scrollView.contentOffset = CGPoint(x: 0, y: 700)
        pages.addChild(page)
        pages.view.addSubview(page.view)
        page.didMove(toParent: pages)
        let feeds = DuoReparentFeeds()
        feeds.appDelegate = app
        app.feedsViewController = feeds
        let navigation = UINavigationController(rootViewController: feeds)
        app.feedsNavigationController = navigation
        let split = DuoCollapseCompletionSplit(style: .doubleColumn)
        split.secondaryNavigation = UINavigationController(rootViewController: detail)
        app.splitViewController = split
        return DuoCollapseCompletionFixture(app: app, detail: detail, pages: pages, page: page,
                                            feeds: feeds, titles: titles, navigation: navigation,
                                            split: split, delegate: SplitViewDelegate())
    }

    func test_compactReaderAdoptsNavigationViewportAfterExpandedColumnCollapses() {
        assertCompactReaderAdoptsNavigationViewport(directShow: false)
    }

    func test_directCompactSecondaryPresentationDetachesExpandedReaderBeforePush() {
        assertCompactReaderAdoptsNavigationViewport(directShow: true)
    }

    func test_delayedCompactRestoreDoesNotRefreshReaderAfterImmediateBack() async {
        await assertDelayedCompactRestoreRespectsNavigationOwnership(goBack: true)
    }

    func test_delayedCompactRestoreRefreshesReaderStillOwnedByNavigation() async {
        await assertDelayedCompactRestoreRespectsNavigationOwnership(goBack: false)
    }

    func test_foldDisappearanceRetainsArticleOwnedByCompactOrExpandedReader() {
        for compact in [true, false] {
            let (app, detail, pages, page, navigation) = makeArticleDisappearanceFixture()
            detail.isCompact = compact
            if compact { navigation.pushViewController(pages, animated: false) }
            else { detail.moveStoriesToDetailContainer() }

            page.viewDidDisappear(false)

            XCTAssertEqual(page.clearStoryCount, 0, "A split handoff must retain its still-owned active document")
            XCTAssertTrue(page.hasStory)
            XCTAssertEqual(app.activeStory?["story_hash"] as? String, page.activeStoryId)
        }
    }

    func test_actualBackStillClearsTheDepartedArticle() {
        let (app, detail, pages, page, navigation) = makeArticleDisappearanceFixture()
        detail.isCompact = true
        navigation.pushViewController(pages, animated: false)
        navigation.popToRootViewController(animated: false)

        page.viewDidDisappear(false)

        XCTAssertEqual(page.clearStoryCount, 1, "The retained reader must not keep a document after actual Back")
        XCTAssertFalse(page.hasStory)
        XCTAssertTrue(app.feedsNavigationController === navigation)
    }

    private func makeArticleDisappearanceFixture() -> (NewsBlurAppDelegate, DuoReparentDetail, DuoReparentPages, DuoReparentPage, UINavigationController) {
        let app = NewsBlurAppDelegate()
        let collection = StoriesCollection()
        collection.appDelegate = app
        app.storiesCollection = collection
        app.activeStory = ["story_hash": "layout-only:story"]
        let detail = DuoReparentDetail()
        detail.traitOverrides.verticalSizeClass = .regular
        detail.appDelegate = app
        app.detailViewController = detail
        detail.loadViewIfNeeded()
        let pages = DuoReparentPages()
        pages.appDelegate = app
        pages.loadViewIfNeeded()
        detail.storyPagesViewController = pages
        let page = pages.currentPage as! DuoReparentPage
        page.appDelegate = app
        page.activeStoryId = "layout-only:story"
        page.hasStory = true
        pages.addChild(page)
        pages.view.addSubview(page.view)
        page.didMove(toParent: pages)
        let navigation = UINavigationController(rootViewController: UIViewController())
        app.feedsNavigationController = navigation
        return (app, detail, pages, page, navigation)
    }

    private func assertDelayedCompactRestoreRespectsNavigationOwnership(goBack: Bool) async {
        let app = NewsBlurAppDelegate()
        let collection = StoriesCollection()
        collection.appDelegate = app
        app.storiesCollection = collection
        app.activeStory = ["story_hash": "layout-only:story"]
        let detail = DuoReparentDetail()
        detail.traitOverrides.verticalSizeClass = .regular
        detail.appDelegate = app
        detail.isCompact = true
        app.detailViewController = detail
        detail.loadViewIfNeeded()
        let pages = DuoReparentPages()
        pages.appDelegate = app
        pages.loadViewIfNeeded()
        detail.storyPagesViewController = pages
        let feeds = DuoReparentFeeds()
        feeds.appDelegate = app
        app.feedsViewController = feeds
        let navigation = UINavigationController(rootViewController: feeds)
        navigation.setNavigationBarHidden(true, animated: false)
        app.feedsNavigationController = navigation
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 678, height: 466))
        window.rootViewController = navigation
        window.isHidden = false
        defer { window.isHidden = true }

        let refresh = expectation(description: "The delayed restore refreshes only its currently visible reader")
        refresh.isInverted = goBack
        pages.onUpdatePage = { refresh.fulfill() }
        detail.restoreCompactNavigationAfterSplitCollapse(showFeed: false, showStory: true)
        XCTAssertTrue(navigation.topViewController === pages)
        if goBack {
            navigation.popToRootViewController(animated: false)
            XCTAssertTrue(navigation.topViewController === feeds)
        }

        // DuoPresentationTests.swift waits across the production 50ms callback to verify that Back cancels its ownership.
        await fulfillment(of: [refresh], timeout: 0.25)
        XCTAssertEqual(pages.updatePageCount, goBack ? 0 : 1)
        XCTAssertEqual(pages.refreshPagesCount, goBack ? 0 : 1)
        XCTAssertEqual(pages.reorientPagesCount, goBack ? 0 : 1)
        let expectedController: UIViewController = goBack ? feeds : pages
        XCTAssertTrue(navigation.topViewController === expectedController)
    }

    private func assertCompactReaderAdoptsNavigationViewport(directShow: Bool) {
        let app = NewsBlurAppDelegate()
        let collection = StoriesCollection()
        collection.appDelegate = app
        app.storiesCollection = collection
        app.activeStory = ["story_hash": "layout-only:story"]
        let detail = DuoReparentDetail()
        detail.traitOverrides.verticalSizeClass = .regular
        detail.appDelegate = app
        app.detailViewController = detail
        detail.isCompact = false
        detail.loadViewIfNeeded()
        let pages = DuoReparentPages()
        pages.appDelegate = app
        pages.loadViewIfNeeded()
        detail.storyPagesViewController = pages
        let navigation = UINavigationController(rootViewController: UIViewController())
        navigation.setNavigationBarHidden(true, animated: false)
        app.feedsNavigationController = navigation
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 678, height: 466))
        window.rootViewController = navigation
        window.isHidden = false
        defer { window.isHidden = true }
        navigation.view.frame = window.bounds
        navigation.view.layoutIfNeeded()

        detail.moveStoriesToDetailContainer()
        detail.view.layoutIfNeeded()
        XCTAssertTrue(pages.parent === detail)
        XCTAssertGreaterThan(pages.view.bounds.height, 400)
        // DuoPresentationTests.swift reproduces the old column shrinking during UIKit's fold before the reader is pushed.
        detail.topContainerView.frame.size.height = 0
        detail.topContainerView.layoutIfNeeded()
        XCTAssertEqual(pages.view.bounds.height, 0, accuracy: 0.5)

        detail.isCompact = true
        if directShow {
            // DuoPresentationTests.swift reproduces changePage requesting the secondary column during the fold handoff.
            detail.show(column: .secondary, animated: false)
        } else {
            detail.moveStoriesToDetailContainer()
        }
        window.layoutIfNeeded()
        navigation.view.setNeedsLayout()
        navigation.view.layoutIfNeeded()
        XCTAssertTrue(navigation.topViewController === pages)
        XCTAssertTrue(pages.parent === navigation)
        XCTAssertGreaterThan(pages.view.bounds.height, 400,
                             "The compact reader must not keep its departed column's zero height")
        XCTAssertEqual(pages.view.bounds.height, navigation.view.bounds.height, accuracy: 1)
        XCTAssertEqual(pages.view.bounds.width, navigation.view.bounds.width, accuracy: 1)

        navigation.popToRootViewController(animated: false)
        detail.isCompact = false
        detail.topContainerView.frame.size.height = 700
        detail.moveStoriesToDetailContainer()
        detail.view.layoutIfNeeded()
        XCTAssertTrue(pages.parent === detail)
        XCTAssertTrue(pages.view.superview === detail.topContainerView)
        XCTAssertEqual(pages.view.bounds.size, detail.topContainerView.bounds.size,
                       "Expanded layout must regain ownership after a compact visit")
        detail.topContainerView.frame.size.height = 0
        detail.topContainerView.layoutIfNeeded()
        detail.isCompact = true
        if directShow { detail.show(column: .secondary, animated: false) }
        else { detail.moveStoriesToDetailContainer() }
        navigation.view.setNeedsLayout()
        navigation.view.layoutIfNeeded()
        XCTAssertEqual(pages.view.bounds.size, navigation.view.bounds.size,
                       "A second compact handoff must retain the navigation viewport")
    }
}

@MainActor private struct DuoCollapseCompletionFixture {
    let app: NewsBlurAppDelegate
    let detail: DuoCollapseCompletionDetail
    let pages: DuoReparentPages
    let page: DuoReparentPage
    let feeds: DuoReparentFeeds
    let titles: DuoCollapseCompletionTitles
    let navigation: UINavigationController
    let split: DuoCollapseCompletionSplit
    let delegate: SplitViewDelegate

    func releaseControllers() {
        detail.cancelCompactNavigationRestoration()
        navigation.setViewControllers([], animated: false)
        split.secondaryNavigation?.setViewControllers([], animated: false)
        split.secondaryNavigation = nil
        app.detailViewController = nil
        app.feedsNavigationController = nil
        app.feedsViewController = nil
        app.splitViewController = nil
        app.storiesCollection = nil
    }
}

@MainActor private final class DuoCollapseCompletionSplit: SplitViewController {
    var secondaryNavigation: UINavigationController?
    var simulatesCollapsed = true
    override var isCollapsed: Bool { simulatesCollapsed }
    override func viewController(for column: UISplitViewController.Column) -> UIViewController? {
        column == .secondary ? secondaryNavigation : super.viewController(for: column)
    }
}

@MainActor private final class DuoCollapseCompletionDetail: DetailViewController {
    override var layout: Layout {
        get { .left }
        set {}
    }
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 951, height: 669)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
    // DuoPresentationTests.swift isolates delegate completion ordering from unrelated storyboard construction.
    override func collapseToSingleColumn() { isCompact = true }
    override func expandToTwoColumns() {
        isCompact = false
        appDelegate.feedsNavigationController.popToRootViewController(animated: false)
    }
}

@MainActor private final class DuoCollapseCompletionTitles: FeedDetailViewController {
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 450, height: 700)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillDisappear(_ animated: Bool) {}
    override func viewDidDisappear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
    override func viewSafeAreaInsetsDidChange() {}
}

@MainActor private final class DuoReparentDetail: DetailViewController {
    override var layout: Layout {
        get { .left }
        set {}
    }
    override func loadView() {
        view = UIView(frame: CGRect(x: 0, y: 0, width: 900, height: 700))
        let column = UIView(frame: CGRect(x: 450, y: 0, width: 450, height: 700))
        view.addSubview(column)
        topContainerView = column
    }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
    override func adjustForAutoscroll() {}
}

@MainActor private final class DuoReparentPages: StoryPagesViewController {
    var onUpdatePage: (() -> Void)?
    var updatePageCount = 0
    var refreshPagesCount = 0
    var reorientPagesCount = 0

    override func loadView() {
        view = UIView(frame: CGRect(x: 0, y: 0, width: 450, height: 700))
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let page = DuoReparentPage()
        page.loadViewIfNeeded()
        currentPage = page
    }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillDisappear(_ animated: Bool) {}
    override func viewDidDisappear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
    override func viewSafeAreaInsetsDidChange() {}
    override func updatePage(withActiveStory location: Int, updateFeedDetail: Bool) {
        updatePageCount += 1
        onUpdatePage?()
    }
    override func refreshPages() { refreshPagesCount += 1 }
    override func reorientPages() { reorientPagesCount += 1 }
}

@MainActor private final class DuoReparentFeeds: FeedsViewController {
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 678, height: 466)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillDisappear(_ animated: Bool) {}
    override func viewDidDisappear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
    override func viewSafeAreaInsetsDidChange() {}
}

@MainActor private final class DuoReparentPage: StoryDetailViewController {
    var clearStoryCount = 0

    override func loadView() {
        view = UIView(frame: CGRect(x: 0, y: 0, width: 450, height: 700))
        webView = WKWebView(frame: view.bounds)
        view.addSubview(webView)
    }
    override func viewDidLoad() {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
    override func clearStory() {
        clearStoryCount += 1
        hasStory = false
    }
    deinit {
        // DuoPresentationTests.swift's isolated layout page does not install the production web-view KVO observers.
        webView = nil
    }
}

@MainActor final class Test_FindFriendsRendering: XCTestCase {
    func test_suggestedProfilesRenderTheirNamesWithoutEnteringSearch() throws {
        let controller = try makeController()
        // DuoPresentationTests.swift uses a local-only URL so badge rendering cannot send a remote image request.
        let profiles = [["user_id": 4242, "username": "duo-friend", "bio": "A suggested reader",
                         "location": "", "photo_url": "file:///dev/null", "followed_by_you": 0] as [String: Any]]
        controller.setValue(profiles, forKey: "suggestedUserProfiles")
        controller.setValue(false, forKey: "inSearch_")
        let table = try XCTUnwrap(controller.value(forKey: "friendsTable") as? UITableView)
        table.reloadData()
        XCTAssertEqual(table.numberOfRows(inSection: 0), 1)
        let cell = try XCTUnwrap(table.dataSource?.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)))
        XCTAssertTrue(labels(in: cell).contains { $0.text == "duo-friend" },
                      "A loaded suggested profile must render its username instead of an empty row")
        XCTAssertEqual(cell.accessoryType, .detailDisclosureButton)
    }

    func test_emptySuggestionsAndSearchResultsRenderAnExplicitMessage() throws {
        for searching in [false, true] {
            let controller = try makeController()
            controller.setValue([], forKey: "suggestedUserProfiles")
            controller.setValue([], forKey: "userProfiles")
            controller.setValue(searching, forKey: "inSearch_")
            let table = try XCTUnwrap(controller.value(forKey: "friendsTable") as? UITableView)
            table.reloadData()
            XCTAssertEqual(table.numberOfRows(inSection: 0), 1,
                           "An empty result must display one explanatory row, not blank placeholders")
            let cell = try XCTUnwrap(table.dataSource?.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)))
            let expected = searching ? "No results." : "No friends to suggest."
            XCTAssertTrue(labels(in: cell).contains { $0.text == expected }, expected)
            XCTAssertEqual(cell.accessoryType, .none)
        }
    }

    private func makeController() throws -> UIViewController {
        let type = try XCTUnwrap(NSClassFromString("FriendsListViewController") as? UIViewController.Type)
        let controller = type.init(nibName: nil, bundle: nil)
        controller.loadViewIfNeeded()
        // DuoPresentationTests.swift isolates controller state after its legacy viewDidLoad assigns the application delegate.
        controller.setValue(NewsBlurAppDelegate(), forKey: "appDelegate")
        controller.view.frame = CGRect(x: 0, y: 0, width: 450, height: 600)
        controller.view.layoutIfNeeded()
        return controller
    }

    private func labels(in view: UIView) -> [UILabel] {
        (view as? UILabel).map { [$0] } ?? view.subviews.flatMap { labels(in: $0) }
    }
}

@MainActor final class Test_DuoDialogRouting: XCTestCase {
    func test_expandedPhoneSharesFromSplitWithOriginalBarOrViewAnchor() throws {
        for compact in [true, false] {
            for usesBarButton in [false, true] {
                let fixture = makeApp(compact: compact)
                let source = UIView(frame: CGRect(x: 20, y: 30, width: 44, height: 44))
                let sourceParent = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
                sourceParent.addSubview(source)
                let item = UIBarButtonItem(title: "Share", style: .plain, target: nil, action: nil)
                let sender: Any = usesBarButton ? item : source

                fixture.app.showSend(to: UIViewController(), sender: sender)

                XCTAssertEqual(fixture.navigation.presentations.count, compact ? 1 : 0,
                               "Expanded Duo must use the iPad sharing route instead of its hidden feed stack")
                XCTAssertEqual(fixture.split.presentations.count, compact ? 0 : 1)
                let activity = try XCTUnwrap((compact ? fixture.navigation.presentations.first : fixture.split.presentations.first)
                    as? UIActivityViewController)
                if !compact {
                    XCTAssertEqual(activity.modalPresentationStyle, .popover)
                    let popover = try XCTUnwrap(activity.popoverPresentationController)
                    if usesBarButton {
                        XCTAssertTrue(popover.barButtonItem === item)
                    } else {
                        XCTAssertTrue(popover.sourceView === sourceParent)
                        XCTAssertEqual(popover.sourceRect, source.frame)
                    }
                }
            }
        }
    }

    func test_expandedPhoneTrainerAndNotificationsKeepSuppliedPopoverAnchors() throws {
        for compact in [true, false] {
            for route in ["site-training", "story-training", "notifications"] {
                for usesBarButton in [false, true] {
                    let fixture = makeApp(compact: compact)
                    let source = UIView(frame: CGRect(x: 20, y: 30, width: 44, height: 44))
                    let item = UIBarButtonItem(title: route, style: .plain, target: nil, action: nil)
                    let sender: Any = usesBarButton ? item : source
                    let expected: UIViewController
                    if route == "notifications" {
                        expected = fixture.notifications
                        fixture.app.openNotifications(withFeed: "1", sender: sender)
                    } else {
                        expected = fixture.app.trainerViewController
                        if route == "site-training" {
                            fixture.app.openTrainSite(withFeedLoaded: true, from: sender)
                        } else {
                            fixture.app.openTrainStory(sender)
                        }
                    }

                    XCTAssertEqual(fixture.app.popovers.count, compact ? 0 : 1, route)
                    XCTAssertEqual(fixture.navigation.presentations.count, compact ? 1 : 0, route)
                    if compact {
                        let navigation = try XCTUnwrap(fixture.navigation.presentations.first as? UINavigationController)
                        XCTAssertTrue(navigation.topViewController === expected)
                        XCTAssertEqual(navigation.modalPresentationStyle, .pageSheet)
                    } else {
                        let captured = try XCTUnwrap(fixture.app.popovers.first, route)
                        XCTAssertTrue(captured.controller === expected)
                        XCTAssertTrue(captured.sender === (sender as AnyObject), "\(route) must keep its original visible anchor")
                    }
                }
            }
        }
    }

    func test_dialogWrappersRetainTheirContentAcrossFoldRoundTrips() throws {
        for route in ["site-training", "story-training", "notifications"] {
            let fixture = makeApp(compact: true)
            let item = UIBarButtonItem(title: route, style: .plain, target: nil, action: nil)
            let content: UIViewController = route == "notifications" ? fixture.notifications : fixture.app.trainerViewController
            let open = {
                if route == "notifications" {
                    fixture.app.openNotifications(withFeed: "1", sender: item)
                } else if route == "site-training" {
                    fixture.app.openTrainSite(withFeedLoaded: true, from: item)
                } else {
                    fixture.app.openTrainStory(item)
                }
            }

            open()
            let wrapper = try XCTUnwrap(fixture.navigation.presentations.last as? UINavigationController)
            XCTAssertTrue(content.parent === wrapper)

            fixture.app.detailViewController.isCompact = false
            open()
            let popover = try XCTUnwrap(fixture.app.popovers.last, "Expanded \(route) must use the supplied anchor")
            XCTAssertTrue(popover.controller === wrapper, "An existing navigation wrapper must own the popover instead of presenting its child")
            XCTAssertTrue(popover.sender === item)
            XCTAssertTrue(wrapper.topViewController === content)
            XCTAssertTrue(content.parent === wrapper)

            fixture.app.detailViewController.isCompact = true
            open()
            XCTAssertTrue(fixture.navigation.presentations.last === wrapper)
            XCTAssertEqual(wrapper.modalPresentationStyle, .pageSheet)
            XCTAssertTrue(wrapper.topViewController === content)
            XCTAssertTrue(content.parent === wrapper)
        }
    }

    private func makeApp(compact: Bool) -> (app: DuoDialogRoutingApp, navigation: DuoDialogRoutingNavigation, split: DuoDialogRoutingSplit, notifications: UIViewController) {
        let app = DuoDialogRoutingApp()
        let detail = DetailViewController()
        detail.appDelegate = app
        detail.isCompact = compact
        app.detailViewController = detail
        let navigation = DuoDialogRoutingNavigation(rootViewController: UIViewController())
        app.feedsNavigationController = navigation
        let split = DuoDialogRoutingSplit(style: .doubleColumn)
        app.splitViewController = split
        app.storiesCollection = StoriesCollection()
        app.dictFeeds = ["1": ["id": 1, "feed_title": "Synthetic feed"]]
        app.activeStory = ["story_hash": "1:fixture", "story_feed_id": 1, "story_title": "Synthetic article",
                           "story_permalink": "https://example.com/article", "story_content": "Synthetic content"]
        let trainer = DuoDialogRoutingTrainer()
        trainer.appDelegate = app
        app.trainerViewController = trainer
        let notifications = DuoDialogRoutingNotifications()
        notifications.appDelegate = app
        // DuoPresentationTests.swift injects the declared Objective-C property whose concrete header is not in the Swift bridge.
        app.setValue(notifications, forKey: "notificationsViewController")
        return (app, navigation, split, notifications)
    }
}

@MainActor private final class DuoDialogRoutingApp: NewsBlurAppDelegate {
    var popovers: [(controller: UIViewController, sender: AnyObject)] = []
    override var isPhone: Bool { true }
    // DuoPresentationTests.swift records the shared iPad route without creating network-backed presentation content.
    override func showPopover(with viewController: UIViewController!, contentSize: CGSize, sender: Any!) {
        popovers.append((viewController, sender as AnyObject))
    }
}

@MainActor private final class DuoDialogRoutingNavigation: UINavigationController {
    var presentations: [UIViewController] = []
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        presentations.append(viewControllerToPresent)
    }
}

@MainActor private final class DuoDialogRoutingSplit: SplitViewController {
    var presentations: [UIViewController] = []
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        presentations.append(viewControllerToPresent)
    }
}

@MainActor private final class DuoDialogRoutingTrainer: TrainerViewController {
    override func reload() {}
    override func loadView() { view = UIView() }
    override func viewDidLoad() {}
}

@MainActor private final class DuoDialogRoutingNotifications: BaseViewController {
    @objc var feedId: String?
    override func loadView() { view = UIView() }
    override func viewDidLoad() {}
}

@MainActor final class Test_DuoThemeObservation: XCTestCase {
    func test_unchangedDefaultsDoNotInvalidateTheTheme() {
        let observer = AskAIThemeObserver()
        let originalVersion = observer.themeVersion
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: UserDefaults.standard)
        XCTAssertEqual(observer.themeVersion, originalVersion,
                       "Unrelated defaults notifications must not recreate theme-aware editors")
    }

    func test_supportedThemeChangesStillInvalidateTheDisplayedTheme() throws {
        let manager = try XCTUnwrap(ThemeManager.shared)
        let originalTheme = try XCTUnwrap(manager.theme)
        let defaults = UserDefaults.standard
        let domainName = try XCTUnwrap(Bundle.main.bundleIdentifier)
        let domain = defaults.persistentDomain(forName: domainName) ?? [:]
        let keys = ["theme_style", "theme_light", "theme_dark"]
        let originalPreferences = keys.map { domain[$0] }
        func restorePreferences() {
            for (key, value) in zip(keys, originalPreferences) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        defer {
            manager.theme = originalTheme
            restorePreferences()
            manager.updateTheme()
            restorePreferences()
            XCTAssertEqual(manager.theme, originalTheme)
            for (key, value) in zip(keys, originalPreferences) {
                XCTAssertEqual(defaults.persistentDomain(forName: domainName)?[key] as? NSObject,
                               value as? NSObject, "The theme test must restore the original \(key) preference")
            }
        }
        let observer = AskAIThemeObserver()
        for theme in [ThemeStyleLight, ThemeStyleSepia, ThemeStyleMedium, ThemeStyleDark, ThemeStyleLight] {
            let previousTheme = manager.effectiveTheme
            let previousVersion = observer.themeVersion
            manager.theme = theme
            NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
            XCTAssertEqual(manager.effectiveTheme, theme)
            if previousTheme != theme {
                XCTAssertGreaterThan(observer.themeVersion, previousVersion,
                                     "Changing the displayed theme to \(theme) must refresh SwiftUI colors")
            }
            let currentVersion = observer.themeVersion
            NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
            XCTAssertEqual(observer.themeVersion, currentVersion,
                           "Repeated \(theme) notifications must preserve editor identity")
        }
    }
}

/// DuoPresentationTests.swift exercises the logged-in Alpha app in the pose selected in Device Hub.
@MainActor final class Test_DuoPresentation: XCTestCase {
    private var liveApp: NewsBlurAppDelegate?
    private var initialUsername: String?
    private var keyboardFrameInScreen: CGRect?
    private var journeyScrolledStories = Set<String>()

    override func tearDown() async throws {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidChangeFrameNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidShowNotification, object: nil)
        if let app = liveApp {
            app.window?.endEditing(true)
            await dismissPresentations(app)
            app.feedDetailViewController?.deactivateSearch()
            app.detailViewController?.dismissDiscoverSites()
            app.showFeedsList(animated: false)
            XCTAssertEqual(app.activeUsername, initialUsername, "Presentation checks must preserve the logged-in account")
        }
        liveApp = nil
        initialUsername = nil
        keyboardFrameInScreen = nil
        try await super.tearDown()
    }

    func test_feedSettingsAndManagementDialogsFitCurrentDuoPose() async throws {
        let app = try await prepareApp()
        let feeds = try XCTUnwrap(app.feedsViewController)
        for title in ["Preferences", "Mute Sites", "Organize Sites", "Widget Sites",
                      "Notifications", "Interactions", "Find Friends"] {
            feeds.showSettingsPopover(nil)
            let settings = try await waitForPresentation(app)
            if title == "Preferences" { try await audit(settings, named: "feed-settings", app: app) }
            let menu = try XCTUnwrap(descendant(of: MenuViewController.self, in: settings))
            try selectMenuRow(title, in: menu)
            let dialog = try await waitForPresentation(app, excluding: settings)
            try await waitForManagementContent(title, in: dialog, app: app)
            try await audit(dialog, named: "feed-\(slug(title))", app: app)
            await dismissPresentations(app)
        }

        // DuoPresentationTests.swift opens subscription information without selecting a purchase or restore action.
        app.showPremiumDialog()
        try await audit(try await waitForPresentation(app), named: "subscription", app: app)
    }

    func test_findFriendsPresentsControllerReceivingSuggestedProfiles() async throws {
        let app = try await prepareApp()
        app.showFindFriends()
        let dialog = try await waitForPresentation(app)
        let navigation = try XCTUnwrap(dialog as? UINavigationController)
        let requested = try XCTUnwrap(app.value(forKey: "friendsListViewController") as? UIViewController)
        XCTAssertTrue(navigation.viewControllers.first === requested,
                      "The visible Find Friends controller must receive the suggested-friends response")
        capture(try XCTUnwrap(dialog.view.window), named: "find-friends-request-owner", controller: dialog)
    }

    func test_liveFriendBadgesStayInsideCellContentAndBelowSearchAtTop() async throws {
        let app = try await prepareApp()
        app.feedsViewController.showSettingsPopover(nil)
        let settings = try await waitForPresentation(app)
        let menu = try XCTUnwrap(descendant(of: MenuViewController.self, in: settings))
        try selectMenuRow("Find Friends", in: menu)
        let dialog = try await waitForPresentation(app, excluding: settings)
        try await waitForManagementContent("Find Friends", in: dialog, app: app)
        let friends = try XCTUnwrap(descendant(named: "FriendsListViewController", in: dialog))
        let profiles = try XCTUnwrap(friends.value(forKey: "suggestedUserProfiles") as? [[String: Any]])
        guard !profiles.isEmpty else { throw XCTSkip("The account has no suggested friends to measure") }
        let table = try XCTUnwrap(friends.value(forKey: "friendsTable") as? UITableView)
        let search = try XCTUnwrap(friends.value(forKey: "friendSearchBar") as? UISearchBar)
        let window = try XCTUnwrap(dialog.view.window)
        var geometry = ["initialOffset=\(table.contentOffset) table=\(table.frame) safe=\(table.safeAreaInsets) adjusted=\(table.adjustedContentInset) search=\(search.convert(search.bounds, to: window))"]
        capture(window, named: "friends-badges-initial-scroll-position", controller: dialog)
        window.endEditing(true)
        try await waitUntil("Find Friends keyboard must finish dismissal before measuring the top row") {
            !search.isFirstResponder && self.activeTextField(in: dialog) == nil && self.visibleKeyboardFrame(in: window).height <= 1
        }
        // DuoPresentationTests.swift normalizes the scroll position before classifying first-row clipping as a defect.
        table.setContentOffset(CGPoint(x: table.contentOffset.x, y: -table.adjustedContentInset.top), animated: false)
        try await settle(dialog)
        table.layoutIfNeeded()
        let firstCell = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 0, section: 0)))
        let firstName = try XCTUnwrap(profiles[0]["username"] as? String)
        let firstLabel = try XCTUnwrap(allViews(in: firstCell).compactMap { $0 as? UILabel }.first { $0.text == firstName })
        let firstLabelFrame = firstLabel.convert(firstLabel.bounds, to: window)
        let searchFrame = search.convert(search.bounds, to: window)
        XCTAssertGreaterThanOrEqual(firstLabelFrame.minY, searchFrame.maxY - 1,
                                    "At the actual top, the first friend's username must not sit behind Search")
        geometry.append("normalizedOffset=\(table.contentOffset) firstRow=\(firstCell.frame) firstName=\(firstLabelFrame) search=\(searchFrame)")
        for cell in table.visibleCells {
            guard let path = table.indexPath(for: cell), path.row < profiles.count,
                  let badge = cell.contentView.subviews.first(where: { String(describing: type(of: $0)) == "ProfileBadge" }) else { continue }
            cell.layoutIfNeeded()
            badge.layoutIfNeeded()
            let badgeFrame = badge.convert(badge.bounds, to: cell.contentView)
            geometry.append("row=\(path.row) cell=\(cell.frame) content=\(cell.contentView.frame) cellSafe=\(cell.safeAreaInsets) badge=\(badgeFrame)")
            XCTAssertTrue(cell.contentView.bounds.insetBy(dx: -1, dy: -1).contains(badgeFrame),
                          "Friend badge \(path.row) must stay before the native accessory and safe-area region")
            for label in allViews(in: badge).compactMap({ $0 as? UILabel }) where !(label.text ?? "").isEmpty {
                let labelFrame = label.convert(label.bounds, to: cell.contentView)
                geometry.append("row=\(path.row) label=\(labelFrame) textLength=\(label.text?.count ?? 0)")
                XCTAssertTrue(cell.contentView.bounds.insetBy(dx: -1, dy: -1).contains(labelFrame),
                              "Friend text in row \(path.row) must use the actual content width")
            }
        }
        capture(window, named: "friends-badges-at-actual-top", controller: dialog)
        let attachment = XCTAttachment(string: geometry.joined(separator: "\n"))
        attachment.name = "friends-actual-badge-content-geometry"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("DUO_FRIENDS_GEOMETRY \(geometry.joined(separator: "\n"))")
    }

    func test_liveInteractionRowsFitTheirRenderedTextWithoutExcessPadding() async throws {
        let app = try await prepareApp()
        app.feedsViewController.showSettingsPopover(nil)
        let settings = try await waitForPresentation(app)
        let menu = try XCTUnwrap(descendant(of: MenuViewController.self, in: settings))
        try selectMenuRow("Interactions", in: menu)
        let dialog = try await waitForPresentation(app, excluding: settings)
        let module = try XCTUnwrap(allViews(in: dialog.view).first {
            String(describing: type(of: $0)) == "InteractionsModule"
        })
        let table = try XCTUnwrap(module.value(forKey: "interactionsTable") as? UITableView)
        try await waitUntil("Interactions must load actual rows before measuring their padding", timeout: 30) {
            (app.userInteractionsArray?.count ?? 0) > 0 &&
                (module.value(forKey: "pageFetching") as? NSNumber)?.boolValue == false &&
                !table.hasUncommittedUpdates && !table.visibleCells.isEmpty
        }
        let interactions = try XCTUnwrap(app.userInteractionsArray as? [[String: Any]])
        let longRows = interactions.indices.filter {
            (interactions[$0]["content"] as? String ?? "").count > 250
        }
        guard !longRows.isEmpty else {
            throw XCTSkip("The loaded account has no long interaction reply for a meaningful row-padding check")
        }
        let selectedRows = Array(longRows.prefix(3)) + Array(interactions.indices.filter { !longRows.contains($0) }.prefix(2))
        let originalOffset = table.contentOffset
        defer { table.setContentOffset(originalOffset, animated: false) }
        var measurements: [String] = []
        for row in selectedRows {
            let path = IndexPath(row: row, section: 0)
            guard row < table.numberOfRows(inSection: 0) else {
                XCTFail("Loaded interaction row \(row) is missing from the visible table")
                continue
            }
            table.scrollToRow(at: path, at: .top, animated: false)
            try await settle(dialog)
            try await waitUntil("Interaction row \(row) must be visible and laid out") {
                table.layoutIfNeeded()
                guard let cell = table.cellForRow(at: path) else { return false }
                cell.layoutIfNeeded()
                return self.visibleViewport(of: cell).height > 40 && !table.hasUncommittedUpdates
            }
            let cell = try XCTUnwrap(table.cellForRow(at: path))
            let label = try XCTUnwrap(cell.value(forKey: "interactionLabel") as? UILabel)
            let avatar = try XCTUnwrap(cell.value(forKey: "avatarView") as? UIImageView)
            let top = CGFloat(try XCTUnwrap(cell.value(forKey: "topMargin") as? NSNumber).doubleValue)
            let bottom = CGFloat(try XCTUnwrap(cell.value(forKey: "bottomMargin") as? NSNumber).doubleValue)
            let textSize = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
            let minimumHeight: CGFloat = app.isPhone ? 54 : 78
            let neededHeight = max(minimumHeight, max(ceil(textSize.height), avatar.bounds.height) + top + bottom)
            let geometry = "row=\(row) table=\(table.frame) tableBounds=\(table.bounds) safe=\(table.safeAreaInsets) adjusted=\(table.adjustedContentInset) cell=\(cell.frame) cellSafe=\(cell.safeAreaInsets) content=\(cell.contentView.frame) label=\(label.frame) measuredText=\(textSize) top=\(top) bottom=\(bottom) avatar=\(avatar.frame) minimum=\(minimumHeight) needed=\(neededHeight) excess=\(cell.bounds.height - neededHeight)"
            measurements.append(geometry)
            print("DUO_INTERACTION_GEOMETRY \(geometry)")
            capture(try XCTUnwrap(dialog.view.window), named: "interactions-measured-row-\(row)", controller: dialog)
            XCTAssertGreaterThan(label.bounds.width, 40)
            XCTAssertGreaterThanOrEqual(cell.bounds.height + 2, neededHeight,
                                        "Interaction row \(row) must fit its actual text and avatar")
            XCTAssertLessThanOrEqual(cell.bounds.height, neededHeight + 4,
                                     "Interaction row \(row) must not reserve unused text height above and below the reply")
        }
        let attachment = XCTAttachment(string: measurements.joined(separator: "\n"))
        attachment.name = "interactions-actual-visible-row-geometry"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func test_liveFeedFiltersAcrossThemesPreserveSelectionAndAccount() async throws {
        #if targetEnvironment(macCatalyst)
        throw XCTSkip("The Duo feed theme audit requires the iOS simulator")
        #else
        guard #available(iOS 27.1, *) else { throw XCTSkip("The Duo feed theme audit requires iOS 27.1") }
        let app = try await prepareApp()
        let feeds = try XCTUnwrap(app.feedsViewController)
        let themeManager = try XCTUnwrap(ThemeManager.shared)
        let originalTheme = try XCTUnwrap(themeManager.theme)
        let originalIndex = feeds.intelligenceControl.selectedSegmentIndex
        let originalIntelligence = app.selectedIntelligence
        let originalShowingAll = feeds.viewShowingAllFeeds
        let originalOffset = feeds.feedTitlesTable.contentOffset
        let defaults = UserDefaults.standard
        let domain = defaults.persistentDomain(forName: try XCTUnwrap(Bundle.main.bundleIdentifier)) ?? [:]
        let keys = ["theme_style", "theme_light", "theme_dark", "selectedIntelligence"]
        let savedPreferences = keys.map { domain[$0] }
        let filterNames = ["all", "unread", "focus", "saved"]
        let expectedIntelligence = [0, 0, 1, 2]

        func restorePreferences() {
            for (key, value) in zip(keys, savedPreferences) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }

        func restoreAppearanceAndFilter() async throws {
            // DuoPresentationTests.swift restores through the real setters before restoring absent/default keys exactly.
            themeManager.theme = originalTheme
            feeds.intelligenceControl.selectedSegmentIndex = originalIndex
            feeds.selectIntelligence()
            restorePreferences()
            themeManager.updateTheme()
            restorePreferences()
            try await settleFeedList(feeds, app: app)
            feeds.feedTitlesTable.setContentOffset(originalOffset, animated: false)
            try await settleFeedList(feeds, app: app)
            XCTAssertEqual(themeManager.theme, originalTheme)
            XCTAssertEqual(feeds.intelligenceControl.selectedSegmentIndex, originalIndex)
            XCTAssertEqual(app.selectedIntelligence, originalIntelligence)
            XCTAssertEqual(feeds.viewShowingAllFeeds, originalShowingAll)
            for (key, value) in zip(keys, savedPreferences) {
                XCTAssertEqual(defaults.persistentDomain(forName: Bundle.main.bundleIdentifier!)?[key] as? NSObject,
                               value as? NSObject, "The theme audit must restore the original \(key) preference")
            }
        }

        var failure: Error?
        do {
            for theme in ["light", "sepia", "medium", "dark"] {
                themeManager.theme = theme
                try await settleFeedList(feeds, app: app)
                XCTAssertEqual(themeManager.effectiveTheme, theme)
                for (index, name) in filterNames.enumerated() {
                    let vertical = Utilities.usesSystemVerticalBar(feeds.traitCollection)
                    if vertical {
                        let item = try XCTUnwrap(feeds.toolbarItems?.first {
                            $0.accessibilityIdentifier == "feed-list-intelligence-\(name)"
                        })
                        let action = try XCTUnwrap(item.action)
                        XCTAssertTrue(UIApplication.shared.sendAction(action, to: item.target, from: item, for: nil),
                                      "The native \(name) filter must retain its action")
                    } else {
                        feeds.intelligenceControl.selectedSegmentIndex = index
                        feeds.intelligenceControl.sendActions(for: .valueChanged)
                    }
                    try await settleFeedList(feeds, app: app)
                    XCTAssertEqual(feeds.intelligenceControl.selectedSegmentIndex, index)
                    XCTAssertEqual(app.selectedIntelligence, expectedIntelligence[index])
                    XCTAssertEqual(feeds.viewShowingAllFeeds, index == 0)
                    XCTAssertEqual(defaults.integer(forKey: "selectedIntelligence"), index - 1)
                    if vertical {
                        let items = feeds.toolbarItems ?? []
                        let filters = items.filter { $0.accessibilityIdentifier?.hasPrefix("feed-list-intelligence-") == true }
                        XCTAssertEqual(filters.count, 4)
                        XCTAssertEqual(filters.filter(\.isSelected).map(\.tag), [index],
                                       "Exactly the active intelligence filter must be selected")
                        XCTAssertTrue(filters.allSatisfy(\.sharesBackground), "The four filters must keep their shared native group")
                        for filter in filters {
                            XCTAssertNil(filter.customView, "Native filters must fit the system rail and overflow")
                            XCTAssertNotNil(filter.image)
                            if filter.tag > 0 {
                                XCTAssertEqual(filter.image?.renderingMode, .alwaysOriginal,
                                               "Intelligence artwork must retain its original colors in \(theme)")
                            }
                        }
                        for identifier in ["feed-list-add", "feed-list-settings"] {
                            XCTAssertFalse(try XCTUnwrap(items.first { $0.accessibilityIdentifier == identifier }).sharesBackground)
                        }
                    }
                    try await audit(feeds, named: "feed-\(theme)-\(name)", app: app, scroll: false)
                }
            }
        } catch {
            failure = error
        }
        try await restoreAppearanceAndFilter()
        if let failure { throw failure }
        #endif
    }

    func test_addSiteSheetAndKeyboardFitCurrentDuoPose() async throws {
        let app = try await prepareApp()
        let feeds = try XCTUnwrap(app.feedsViewController)
        feeds.tapAddSite(nil)
        let dialog = try await waitForPresentation(app)
        try await audit(dialog, named: "add-site-compact", app: app, scroll: false)
        let input = try await waitForTextField(in: dialog)
        XCTAssertTrue(input.becomeFirstResponder())
        let window = try XCTUnwrap(dialog.view.window)
        try await waitUntil("Add Site keyboard must become visible") {
            self.activeTextField(in: dialog) != nil && self.visibleKeyboardFrame(in: window).height > 100
        }
        try await settle(dialog)
        let activeInput = try XCTUnwrap(activeTextField(in: dialog), "The live Add Site input must retain focus")
        let fieldFrame = activeInput.convert(activeInput.bounds, to: window)
        let keyboardFrame = visibleKeyboardFrame(in: window)
        XCTAssertLessThanOrEqual(fieldFrame.maxY, keyboardFrame.minY + 1,
                                 "Add Site input must stay above the keyboard")
        try await audit(dialog, named: "add-site-keyboard", app: app, scroll: false)
        window.endEditing(true)
        if let sheet = dialog.sheetPresentationController {
            // DuoPresentationTests.swift waits for AddSiteSheetViewController's keyboard-dismiss shrink before expanding.
            try await waitUntil("Add Site keyboard dismissal must finish shrinking the sheet") {
                self.activeTextField(in: dialog) == nil && self.visibleKeyboardFrame(in: window).height <= 1 &&
                    sheet.selectedDetentIdentifier != .large
            }
            try await settle(dialog)
            let compactFrame = dialog.view.convert(dialog.view.bounds, to: window)
            sheet.animateChanges { sheet.selectedDetentIdentifier = .large }
            try await waitUntil("Add Site must reach the large sheet detent") {
                let frame = dialog.view.convert(dialog.view.bounds, to: window)
                return sheet.selectedDetentIdentifier == .large && frame.height > compactFrame.height + 40 &&
                    frame.minY < compactFrame.minY - 40
            }
            try await settle(dialog)
            XCTAssertEqual(sheet.selectedDetentIdentifier, .large)
            try await audit(dialog, named: "add-site-expanded", app: app)
        }
    }

    func test_addSiteEditorPreservesFocusWhenDefaultsHaveNotChanged() async throws {
        let app = try await prepareApp()
        let feeds = try XCTUnwrap(app.feedsViewController)
        feeds.tapAddSite(nil)
        let dialog = try await waitForPresentation(app)
        try await settle(dialog)
        let input = try await waitForTextField(in: dialog)
        let originalText = input.text
        XCTAssertTrue(input.becomeFirstResponder())
        XCTAssertTrue(input.isFirstResponder, "Add Site must accept focus before the unrelated notification")
        // DuoPresentationTests.swift posts a no-change notification without writing any account or app preferences.
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: UserDefaults.standard)
        try await settle(dialog)
        let currentInput = try await waitForTextField(in: dialog)
        XCTAssertTrue(currentInput === input, "An unchanged theme must preserve the live Add Site editor")
        XCTAssertTrue(input.isFirstResponder, "An unrelated defaults notification must preserve Add Site focus")
        XCTAssertEqual(currentInput.text, originalText, "The Add Site draft must remain unchanged")
        try await audit(dialog, named: "add-site-after-unchanged-defaults", app: app, scroll: false)
    }

    func test_verticalFeedListRespectsAdditionalBottomSafeArea() async throws {
        #if targetEnvironment(macCatalyst)
        throw XCTSkip("The Duo feed safe-area audit requires the iOS simulator")
        #else
        guard #available(iOS 27.1, *) else { throw XCTSkip("The Duo feed safe-area audit requires iOS 27.1") }
        let app = try await prepareApp()
        let feeds = try XCTUnwrap(app.feedsViewController)
        guard Utilities.usesSystemVerticalBar(feeds.traitCollection) else {
            throw XCTSkip("Select a Duo pose with a system vertical bar for this safe-area regression")
        }
        let table = try XCTUnwrap(feeds.feedTitlesTable)
        let window = try XCTUnwrap(feeds.view.window)
        let originalInsets = feeds.additionalSafeAreaInsets
        let originalOffset = table.contentOffset
        defer {
            feeds.additionalSafeAreaInsets = originalInsets
            window.layoutIfNeeded()
            table.setContentOffset(originalOffset, animated: false)
        }
        // DuoPresentationTests.swift uses UIKit's public safe-area API to model a bottom-obscuring system surface.
        var insets = originalInsets
        insets.bottom += 34
        feeds.additionalSafeAreaInsets = insets
        window.setNeedsLayout()
        window.layoutIfNeeded()
        try await settle(feeds)
        XCTAssertGreaterThanOrEqual(feeds.view.safeAreaInsets.bottom, 34)
        let maximum = max(-table.adjustedContentInset.top,
                          table.contentSize.height - table.bounds.height + table.adjustedContentInset.bottom)
        table.setContentOffset(CGPoint(x: originalOffset.x, y: maximum), animated: false)
        try await settle(feeds)
        let safeViewport = feeds.view.convert(feeds.view.safeAreaLayoutGuide.layoutFrame, to: window)
        let contentBottom = table.convert(CGPoint(x: table.bounds.midX,
                                                 y: table.bounds.maxY - table.adjustedContentInset.bottom), to: window).y
        capture(window, named: "feed-additional-bottom-safe-area", controller: feeds)
        XCTAssertLessThanOrEqual(contentBottom, safeViewport.maxY + 1,
                                 "The final feed row must scroll above the Duo bottom safe area")
        #endif
    }

    func test_profileAndKeyboardShortcutsFitCurrentDuoPose() async throws {
        let app = try await prepareApp()
        app.feedsViewController.showUserProfile()
        let profileDialog = try await waitForPresentation(app)
        let profile = try XCTUnwrap(descendant(named: "UserProfileViewController", in: profileDialog))
        let profileGetter = NSSelectorFromString("userProfile")
        XCTAssertTrue(profile.responds(to: profileGetter))
        try await waitUntil("Account profile must load its badge and activity content", timeout: 30) {
            // DuoPresentationTests.swift calls the property getter directly; KVC would invoke the getUserProfile network action.
            guard let data = profile.perform(profileGetter)?.takeUnretainedValue() as? [String: Any],
                  data["user_id"] != nil,
                  let table = profile.value(forKey: "profileTable") as? UITableView else { return false }
            return !self.hasVisibleLoadingIndicator(in: profile.view) && self.visibleViewport(of: table).height > 80 &&
                !table.visibleCells.isEmpty
        }
        try await audit(profileDialog, named: "account-profile", app: app)
        await dismissPresentations(app)
        app.showKeyboardShortcuts()
        try await audit(try await waitForPresentation(app), named: "keyboard-shortcuts", app: app)
    }

    func test_discoverSourcesFitCurrentDuoPose() async throws {
        let app = try await prepareApp()
        let model = DiscoverSitesViewModel()
        let originalFactory = DiscoverSitesViewController.viewModelFactory
        // DuoPresentationTests.swift observes an ordinary network-backed model, without replacing its data or account.
        DiscoverSitesViewController.viewModelFactory = { model }
        defer { DiscoverSitesViewController.viewModelFactory = originalFactory }
        let discover = DiscoverSitesViewController()
        app.detailViewController.showDiscoverSites(discover)
        let root = try XCTUnwrap(app.window?.rootViewController)
        try await waitUntil("Discover Sites must be mounted") {
            self.descendant(of: DiscoverSitesViewController.self, in: root)?.viewIfLoaded?.window != nil
        }
        let pager = try XCTUnwrap(discover.sourcePager)
        for tab in DiscoverTab.allCases {
            // DuoPresentationTests.swift uses the same pager selection entry point as the visible source tabs.
            pager.select(tab, animated: false)
            try await waitForDiscoverContent(tab, model: model)
            try await settle(discover)
            try await audit(discover, named: "discover-\(tab.rawValue)", app: app, scroll: false)
        }
    }

    func test_storyListOptionsSearchAndRelatedSitesFitCurrentDuoPose() async throws {
        let app = try await prepareApp()
        let stories = try await openSubscribedFeed(app)
        let options = stories.toolbarItems?.first { $0.accessibilityIdentifier == "story-list-options" }
        stories.doOpenOptionsMenu(options as Any? ?? stories.storyTitlesHeaderBar.optionsPill)
        try await audit(try await waitForPresentation(app), named: "story-list-options", app: app)
        await dismissPresentations(app)

        stories.doActivateSearch(nil)
        let input = try XCTUnwrap(stories.searchField)
        try await waitUntil("Story search must become first responder") { input.isFirstResponder }
        try await settle(stories)
        let window = try XCTUnwrap(stories.view.window)
        let frame = input.convert(input.bounds, to: window)
        XCTAssertTrue(window.bounds.insetBy(dx: -1, dy: -1).contains(frame), "Story search must be on screen")
        try await audit(stories, named: "story-search-keyboard", app: app, scroll: false)
        stories.deactivateSearch()

        let related = stories.toolbarItems?.first { $0.accessibilityIdentifier == "story-list-discover" }
        try invoke("doOpenDiscoverFromPill:", on: stories,
                   sender: related as Any? ?? stories.storyTitlesHeaderBar.discoverPill)
        try await audit(try await waitForPresentation(app), named: "related-sites", app: app)
    }

    func test_siteSettingsTrainerNotificationsAndStatisticsFitCurrentDuoPose() async throws {
        let app = try await prepareApp()
        let stories = try await openSubscribedFeed(app)
        for title in ["Train this site", "Notifications", "Statistics"] {
            openSiteSettings(stories)
            let settings = try await waitForPresentation(app)
            if title == "Train this site" { try await audit(settings, named: "site-settings", app: app) }
            let menu = try XCTUnwrap(descendant(of: MenuViewController.self, in: settings))
            try selectMenuRow(title, in: menu)
            let dialog: UIViewController
            if title == "Statistics" {
                // DuoPresentationTests.swift follows the phone browser push as well as the iPad popover route.
                try await waitUntil("Statistics browser must be visible") {
                    guard let browser = app.originalStoryViewController else { return false }
                    return self.isVisible(browser) && !browser.isBeingDismissed
                }
                dialog = try XCTUnwrap(app.originalStoryViewController)
                try await waitForStatisticsContent(app.originalStoryViewController)
            } else {
                dialog = try await waitForPresentation(app, excluding: settings)
            }
            try await audit(dialog, named: "site-\(slug(title))", app: app)
            await dismissPresentations(app)
        }
    }

    func test_siteManagementNestedDialogsFitCurrentDuoPoseWithoutSaving() async throws {
        let app = try await prepareApp()
        let stories = try await openSubscribedFeed(app)
        let originalFeedID = stories.storiesCollection.activeFeedIdStr
        let originalFeed = try XCTUnwrap(stories.storiesCollection.activeFeed)
        let originalFolder = stories.storiesCollection.activeFolder
        var routes = ["Move to another folder", "Rename this site", "Delete this site"]
        if (stories.storiesCollection.activeFeed["active"] as? NSNumber)?.boolValue == true {
            routes.append("Mute this site")
        }
        for title in routes {
            openSiteSettings(stories)
            let settings = try await waitForPresentation(app)
            let rootMenu = try XCTUnwrap(descendant(of: MenuViewController.self, in: settings))
            try selectMenuRow("Manage this site…", in: rootMenu)
            let management = try await waitForNextMenu(after: rootMenu)
            if title == routes.first { try await audit(management, named: "site-management", app: app) }
            try selectMenuRow(title, in: management)
            if title == "Rename this site" {
                let rename = try await waitForPresentation(app, excluding: settings)
                XCTAssertTrue(rename is UIAlertController, "Rename must open its confirmation alert")
                try await audit(rename, named: "site-rename", app: app, scroll: false)
            } else {
                let nested = try await waitForNextMenu(after: management)
                try await audit(nested, named: "site-\(slug(title))", app: app)
                if title == "Move to another folder" {
                    try selectMenuRow("New Folder", in: nested)
                    try await audit(try await waitForPresentation(app, excluding: settings),
                                    named: "site-new-folder", app: app, scroll: false)
                }
            }
            // DuoPresentationTests.swift dismisses confirmation UI without selecting rename, move, delete, or mute.
            await dismissPresentations(app)
            XCTAssertEqual(stories.storiesCollection.activeFeedIdStr, originalFeedID)
            XCTAssertEqual(stories.storiesCollection.activeFolder, originalFolder)
            for key in ["id", "feed_title", "active"] {
                XCTAssertEqual(stories.storiesCollection.activeFeed[key] as? NSObject, originalFeed[key] as? NSObject)
            }
        }
    }

    func test_dailyBriefingSettingsFitCurrentDuoPoseWithoutSaving() async throws {
        let app = try await prepareApp()
        guard app.briefingEnabled else { throw XCTSkip("Daily Briefing is unavailable for the logged-in account") }
        app.openDailyBriefing(withStoryHash: nil)
        let stories = try XCTUnwrap(app.feedDetailViewController)
        try await waitUntil("Daily Briefing must be the visible story list", timeout: 30) {
            stories.storiesCollection.isDailyBriefing && self.isVisible(stories) && !stories.pageFetching
        }
        try await settle(stories)
        let settings = stories.toolbarItems?.first { $0.accessibilityIdentifier == "story-list-discover" }
        try invoke("doOpenDiscoverFromPill:", on: stories,
                   sender: settings as Any? ?? stories.storyTitlesHeaderBar.discoverPill)
        let dialog = try await waitForPresentation(app)
        try await waitUntil("Daily Briefing settings must render its complete form", timeout: 30) {
            self.allViews(in: dialog.view).compactMap { $0 as? UIScrollView }.contains {
                $0.contentSize.height > $0.bounds.height + 200 && self.visibleViewport(of: $0).height > 80
            }
        }
        try await audit(dialog, named: "daily-briefing-settings", app: app)
        try await auditBottom(of: dialog, named: "daily-briefing-settings-bottom")
    }

    func test_siteMarkReadTimingPopoverFitsWithoutMarkingStories() async throws {
        let app = try await prepareApp()
        let stories = try await openSubscribedFeed(app)
        let feedID = try XCTUnwrap(stories.storiesCollection.activeFeed?["id"])
        let nativeOptions = stories.toolbarItems?.first { $0.accessibilityIdentifier == "story-list-mark-read-options" }
        var completionCalled = false
        let completion: (Bool) -> Void = { marked in
            completionCalled = true
            XCTAssertFalse(marked, "Inspecting mark-read options must never mark stories")
        }
        if let nativeOptions {
            let menu = try XCTUnwrap(nativeOptions.menu)
            for days in [1, 3, 7, 14] {
                XCTAssertTrue(menu.children.contains { $0.title == "Older than \(days) \(days == 1 ? "day" : "days")" })
            }
            // DuoPresentationTests.swift audits the existing timing popover; native UIMenu activation needs separate UI coverage.
            app.showMarkReadMenu(withFeedIds: [feedID], collectionTitle: "this site", visibleUnreadCount: 0,
                                 barButtonItem: nativeOptions, completionHandler: completion)
        } else {
            let source = stories.storyTitlesHeaderBar.markReadExpandButton
            app.showMarkReadMenu(withFeedIds: [feedID], collectionTitle: "this site",
                                 sourceView: source, sourceRect: source.bounds, completionHandler: completion)
        }
        let dialog = try await waitForPresentation(app)
        let table = try XCTUnwrap(allViews(in: dialog.view).compactMap { $0 as? UITableView }.first)
        let labels = tableCellTitles(table)
        for days in [1, 3, 7, 14] {
            XCTAssertTrue(labels.contains("Mark read older than \(days) \(days == 1 ? "day" : "days")"))
        }
        try await audit(dialog, named: "site-mark-read-timing", app: app)
        await dismissPresentations(app)
        XCTAssertTrue(completionCalled, "Dismissing timing options must finish without applying a choice")
    }

    func test_readerAskAIStartsWithoutSendingAQuestion() async throws {
        let app = try await prepareApp()
        let pages = try await openReadableReader(app)
        let originalModel = UserDefaults.standard.object(forKey: "askAIModel") as? NSObject
        pages.toggleFontSize(nil)
        let fontDialog = try await waitForPresentation(app)
        let table = try XCTUnwrap(allViews(in: fontDialog.view).compactMap { $0 as? UITableView }.first)
        try selectTableRow("Ask AI", in: table)
        let dialog = try await waitForPresentation(app, excluding: fontDialog)
        let askAI = try XCTUnwrap(descendant(of: AskAIViewController.self, in: dialog))
        let model = try XCTUnwrap(askAI.viewModel)
        XCTAssertFalse(model.hasAskedQuestion)
        try await audit(dialog, named: "reader-ask-ai", app: app)
        if let sheet = dialog.sheetPresentationController {
            sheet.animateChanges { sheet.selectedDetentIdentifier = .large }
            try await audit(dialog, named: "reader-ask-ai-expanded", app: app)
        }
        XCTAssertFalse(model.hasAskedQuestion, "Opening and resizing Ask AI must not send a question")
        XCTAssertEqual(UserDefaults.standard.object(forKey: "askAIModel") as? NSObject, originalModel)
    }

    func test_readerNewsBlurShareComposerFitsWithoutSubmitting() async throws {
        let app = try await prepareApp()
        let pages = try await openReadableReader(app)
        let page = try XCTUnwrap(pages.currentPage)
        page.openShareDialog()
        let dialog = try await waitForPresentation(app)
        try await auditCommentComposer(dialog, named: "reader-newsblur-share", app: app)
    }

    func test_liveFoldPreservesLoadedScrolledStory() async throws {
        try await runLiveFoldPreservingStory(fullscreen: false)
    }

    func test_liveFoldAndReaderBackPreserveFullscreenTitleColors() async throws {
        guard ProcessInfo.processInfo.environment["NEWSBLUR_LIVE_DUO_FOLD_TESTS"] == "1" else {
            throw XCTSkip("Drive the actual Device Hub fold with NEWSBLUR_LIVE_DUO_FOLD_TESTS=1")
        }
        let app = try await prepareApp()
        guard !app.detailViewController.isPhoneOrCompact else { throw XCTSkip("Begin with Duo open") }
        let pages = try await openReadableReader(app)
        print("DUO_TITLE_READY_CLOSE")
        fflush(nil)
        try await waitUntil("Close Duo with the reader visible", timeout: 120) {
            app.splitViewController.isCollapsed && app.detailViewController.isPhoneOrCompact
        }
        await waitForLiveFoldLayout(app)
        let titles = try XCTUnwrap(app.feedDetailViewController)
        let navigation = try XCTUnwrap(app.feedsNavigationController)
        navigation.popToViewController(titles, animated: false)
        try await settle(titles)
        XCTAssertTrue(navigation.topViewController === titles)
        print("DUO_TITLE_READY_OPEN")
        fflush(nil)
        try await waitUntil("Reopen Duo after returning to story titles", timeout: 120) {
            !app.splitViewController.isCollapsed && !app.detailViewController.isPhoneOrCompact
        }
        await waitForLiveFoldLayout(app)
        if !app.detailViewController.isDuoFullscreenReader {
            app.detailViewController.toggleTemporaryFullScreen(nil)
            try await settle(pages)
        }
        defer {
            if app.detailViewController.isDuoFullscreenReader { app.detailViewController.toggleTemporaryFullScreen(nil) }
        }
        app.detailViewController.toggleStoryTitles(nil)
        try await settle(titles)
        XCTAssertTrue(navigation.topViewController === titles)
        // DuoPresentationTests.swift uses diagnostic favicon pixels in the real reused overlay title host after reader Back and folding.
        defer { titles.navigationItem.titleView = app.makeFeedTitle(app.storiesCollection.activeFeed) }
        let source = UILabel()
        source.text = "     Color feed"
        source.font = .systemFont(ofSize: 17, weight: .medium)
        source.textColor = .brown
        source.shadowColor = .white
        source.shadowOffset = CGSize(width: 0, height: 1)
        source.sizeToFit()
        let icon = UIImageView(image: UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 16))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 8, y: 0, width: 8, height: 16))
        })
        icon.frame = CGRect(x: 0, y: 2, width: 16, height: 16)
        source.addSubview(icon)
        titles.navigationItem.titleView = source
        titles.view.setNeedsLayout()
        titles.view.layoutIfNeeded()
        try await settle(titles)
        let window = try XCTUnwrap(titles.view.window)
        // DuoPresentationTests.swift waits for the native title host's own animation, which can outlast the list controller's layout.
        var stableTitleSamples = 0
        try await waitUntil("The overlay favicon must reach its committed position") {
            window.layoutIfNeeded()
            guard let displayedIcon = icon.layer.presentation(), let displayedWindow = window.layer.presentation() else { return false }
            let displayed = displayedIcon.convert(icon.bounds, to: displayedWindow)
            let committed = icon.convert(icon.bounds, to: window)
            stableTitleSamples = abs(displayed.minX - committed.minX) < 0.5 &&
                abs(displayed.minY - committed.minY) < 0.5 ? stableTitleSamples + 1 : 0
            return stableTitleSamples >= 3
        }
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "folded-reader-back-overlay-favicon"
        attachment.lifetime = .keepAlways
        add(attachment)
        func rgb(_ point: CGPoint) throws -> [UInt8] {
            let pixel = icon.convert(point, to: window)
            let cgImage = try XCTUnwrap(image.cgImage?.cropping(to: CGRect(x: pixel.x * image.scale, y: pixel.y * image.scale, width: 1, height: 1)))
            var bytes = [UInt8](repeating: 0, count: 4)
            try bytes.withUnsafeMutableBytes { buffer in
                let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                                     bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            }
            return bytes
        }
        let red = try rgb(CGPoint(x: 4, y: 8))
        let blue = try rgb(CGPoint(x: 12, y: 8))
        XCTAssertGreaterThan(red[0], 230)
        XCTAssertLessThan(red[2], 25)
        XCTAssertGreaterThan(blue[2], 230)
        XCTAssertLessThan(blue[0], 25)
    }

    func test_liveFoldPreservesFullscreenReaderAndSidebarPreference() async throws {
        try await runLiveFoldPreservingStory(fullscreen: true)
    }

    private func runLiveFoldPreservingStory(fullscreen: Bool) async throws {
        guard ProcessInfo.processInfo.environment["NEWSBLUR_LIVE_DUO_FOLD_TESTS"] == "1" else {
            throw XCTSkip("Opt in with NEWSBLUR_LIVE_DUO_FOLD_TESTS=1 and drive the actual Device Hub fold when prompted")
        }
        continueAfterFailure = true
        let app = try await prepareApp()
        guard !app.detailViewController.isPhoneOrCompact, app.splitViewController.isCollapsed == false else {
            throw XCTSkip("Begin the live fold test with iPhone Duo open")
        }
        let feeds = try XCTUnwrap(app.feedsViewController)
        let stories = try XCTUnwrap(app.feedDetailViewController)
        let folders = try XCTUnwrap(app.dictFoldersArray as? [String])
        var realFeeds: [(id: String, folder: String, rank: Int)] = []
        var seen = Set<String>()
        for folder in folders {
            for value in app.dictFolders[folder] as? [Any] ?? [] {
                let id = String(describing: value)
                guard Int(id) != nil, seen.insert(id).inserted,
                      let metadata = app.dictFeeds[id] as? [String: Any] else { continue }
                let title = (metadata["feed_title"] as? String ?? "").lowercased()
                let rank = title.contains("futurism") ? 0 : title.contains("daring fireball") ? 1 : 2
                realFeeds.append((id, folder, rank))
            }
        }
        realFeeds.sort { $0.rank < $1.rank }
        var selectedHash: String?
        for feed in realFeeds.prefix(6) {
            try await revealFeedsForJourney(app)
            feeds.selectFeed(feed.id, inFolder: feed.folder)
            try await waitUntil("The live fold source feed must load its real stories", timeout: 30) {
                stories.storiesCollection.activeFeedIdStr == feed.id && !stories.pageFetching &&
                    (stories.storiesCollection.storyLocationsCount > 0 || stories.pageFinished) && self.isVisible(stories)
            }
            let lengths = journeyBodyLengths(stories)
            guard let location = lengths.indices.filter({ lengths[$0] > 2500 }).max(by: { lengths[$0] < lengths[$1] }),
                  let hash = stories.getStoryAtLocation(location)?["story_hash"] as? String else { continue }
            let path = try await waitForJourneyRow(hash: hash, in: stories)
            let table = try XCTUnwrap(stories.storyTitlesTable)
            table.scrollToRow(at: path, at: .middle, animated: false)
            try await settle(stories)
            XCTAssertEqual((table.cellForRow(at: path) as? FeedDetailTableCell)?.storyHash, hash)
            table.selectRow(at: path, animated: false, scrollPosition: .none)
            table.delegate?.tableView?(table, didSelectRowAt: path)
            selectedHash = hash
            break
        }
        let hash = try XCTUnwrap(selectedHash, "The live fold must begin with a real long-form article")
        let pages = try XCTUnwrap(app.storyPagesViewController)
        try await waitForReadableArticle(pages, app: app, selectedHash: hash)
        try await waitUntil("The live fold must start after story presentation has finished") {
            pages.value(forKey: "pendingPresentationPage") == nil && pages.value(forKey: "storySelectionTransitionHost") == nil &&
                pages.value(forKey: "storySelectionRedrawCover") == nil
        }
        let web = try XCTUnwrap(pages.currentPage?.webView)
        if fullscreen {
            app.detailViewController.toggleTemporaryFullScreen(nil)
            try await settle(pages)
            XCTAssertTrue(app.detailViewController.isDuoFullscreenReader)
            XCTAssertGreaterThan(web.bounds.width, 650, "Full-screen reading must fill the expanded reader before folding")
        }
        defer {
            if fullscreen && app.detailViewController.isDuoFullscreenReader {
                app.detailViewController.toggleTemporaryFullScreen(nil)
            }
        }
        let scroll = web.scrollView
        let top = -scroll.adjustedContentInset.top
        let bottom = scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom
        XCTAssertGreaterThan(bottom - top, 500, "The article must be scrollable before folding")
        scroll.setContentOffset(CGPoint(x: 0, y: min(top + 700, bottom - 100)), animated: false)
        try await settle(pages)
        let originalOffset = scroll.contentOffset.y + scroll.adjustedContentInset.top
        XCTAssertGreaterThan(originalOffset, 200)
        let originalPage = try XCTUnwrap(pages.currentPage)
        let originalGeneration = originalPage.value(forKey: "storyLoadGeneration") as? NSNumber
        await auditLiveFoldState(app, hash: hash, originalOffset: originalOffset, name: "before-close")
        print("DUO_FOLD_READY_CLOSE hash=\(hash) offset=\(originalOffset)")
        fflush(nil)
        try await waitUntil("Device Hub must close the live iPhone Duo", timeout: 120) {
            app.detailViewController.isPhoneOrCompact && app.splitViewController.isCollapsed
        }
        await waitForLiveFoldLayout(app)
        await auditLiveFoldState(app, hash: hash, originalOffset: originalOffset, name: "closed")
        XCTAssertTrue(pages.currentPage === originalPage, "Closing must retain the active article controller")
        XCTAssertEqual(pages.currentPage.value(forKey: "storyLoadGeneration") as? NSNumber, originalGeneration,
                       "Closing must resize the loaded article instead of clearing and redrawing it")
        print("DUO_FOLD_READY_OPEN hash=\(hash)")
        fflush(nil)
        try await waitUntil("Device Hub must reopen the live iPhone Duo", timeout: 120) {
            !app.detailViewController.isPhoneOrCompact && !app.splitViewController.isCollapsed
        }
        await waitForLiveFoldLayout(app)
        await auditLiveFoldState(app, hash: hash, originalOffset: originalOffset, name: "reopened")
        XCTAssertTrue(pages.currentPage === originalPage, "Reopening must retain the active article controller")
        XCTAssertEqual(pages.currentPage.value(forKey: "storyLoadGeneration") as? NSNumber, originalGeneration,
                       "Reopening must resize the loaded article instead of clearing and redrawing it")
        if fullscreen {
            XCTAssertTrue(app.detailViewController.isDuoFullscreenReader,
                          "Reopening must restore the user's full-screen reading choice")
            XCTAssertGreaterThan(web.bounds.width, 650)
            let fullWidth = web.bounds.width
            app.detailViewController.toggleStoryTitles(nil)
            try await settle(pages)
            XCTAssertTrue(isVisible(app.feedDetailViewController))
            XCTAssertEqual(web.bounds.width, fullWidth, accuracy: 1,
                           "The reopened reader must still show titles as an overlay")
            app.detailViewController.toggleStoryTitles(nil)
            try await settle(pages)
        }
    }

    private func waitForLiveFoldLayout(_ app: NewsBlurAppDelegate) async {
        let deadline = Date().addingTimeInterval(15)
        var previous = ""
        var stable = 0
        while Date() < deadline {
            let state = liveFoldGeometry(app)
            let transitioning = app.splitViewController.transitionCoordinator != nil ||
                app.feedsNavigationController.transitionCoordinator != nil
            stable = !transitioning && state == previous ? stable + 1 : 0
            previous = state
            if stable >= 10 { return }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func liveFoldGeometry(_ app: NewsBlurAppDelegate) -> String {
        guard let pages = app.storyPagesViewController, let page = pages.currentPage, let web = page.webView else {
            return "Reader or current page missing"
        }
        var ancestors: [String] = []
        var view: UIView? = web
        while let current = view {
            ancestors.append("\(type(of: current)) frame=\(current.frame) bounds=\(current.bounds) hidden=\(current.isHidden) alpha=\(current.alpha) auto=\(current.translatesAutoresizingMaskIntoConstraints)")
            view = current.superview
        }
        return "compact=\(app.detailViewController.isPhoneOrCompact) collapsed=\(app.splitViewController.isCollapsed) " +
            "detailRoot=\(String(describing: app.detailViewController.viewIfLoaded)) " +
            "topContainer=\(String(describing: app.detailViewController.topContainerView)) " +
            "topConstraint=\(String(describing: app.detailViewController.topContainerTopConstraint)) " +
            "navTop=\(String(describing: app.feedsNavigationController.topViewController)) parent=\(String(describing: pages.parent)) " +
            "hash=\(page.activeStoryId ?? "nil") index=\(page.pageIndex) hasStory=\(page.hasStory) " +
            "pageIdentity=\(ObjectIdentifier(page)) generation=\(String(describing: page.value(forKey: "storyLoadGeneration"))) " +
            "liveFraction=\(String(describing: page.value(forKey: "hasLiveScrollFraction"))) scrollPct=\(String(describing: page.value(forKey: "scrollPct"))) " +
            "hasScrolled=\(String(describing: page.value(forKey: "hasScrolled"))) awaitingScroll=\(String(describing: page.value(forKey: "awaitingStoryScrollRestoration"))) " +
            "pagerOffset=\(pages.scrollView.contentOffset) pagerBounds=\(pages.scrollView.bounds) " +
            "webOffset=\(web.scrollView.contentOffset) webContent=\(web.scrollView.contentSize) insets=\(web.scrollView.adjustedContentInset) " +
            "pending=\(String(describing: pages.value(forKey: "pendingPresentationPage"))) " +
            "transition=\(String(describing: pages.value(forKey: "storySelectionTransitionHost"))) " +
            "cover=\(String(describing: pages.value(forKey: "storySelectionRedrawCover"))) " +
            "visibleWeb=\(visibleViewport(of: web)) ancestors=\(ancestors)"
    }

    private func auditLiveFoldState(_ app: NewsBlurAppDelegate, hash: String,
                                    originalOffset: CGFloat, name: String) async {
        let geometry = liveFoldGeometry(app)
        print("DUO_FOLD_GEOMETRY \(name) \(geometry)")
        let attachment = XCTAttachment(string: geometry)
        attachment.name = "fold-\(name)-geometry"
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let pages = app.storyPagesViewController, let page = pages.currentPage, let web = page.webView,
              let window = app.window else {
            XCTFail("\(name): the same live reader must survive the fold")
            return
        }
        capture(window, named: "fold-\(name)", controller: pages)
        XCTAssertEqual(app.activeStory?["story_hash"] as? String, hash, name)
        XCTAssertEqual(page.activeStoryId, hash, name)
        XCTAssertTrue(isVisible(pages), "\(name): the reader must remain visible")
        XCTAssertGreaterThan(visibleViewport(of: web).width, 200, "\(name): article ancestors must not hide or clip the web view")
        XCTAssertGreaterThan(visibleViewport(of: web).height, 200, name)
        XCTAssertEqual(visibleViewport(of: web).width, web.bounds.width, accuracy: 2, name)
        XCTAssertNil(pages.value(forKey: "pendingPresentationPage"), name)
        XCTAssertNil(pages.value(forKey: "storySelectionTransitionHost"), name)
        XCTAssertNil(pages.value(forKey: "storySelectionRedrawCover"), name)
        XCTAssertGreaterThan(web.scrollView.contentOffset.y + web.scrollView.adjustedContentInset.top, 100,
                             "\(name): folding must preserve a scrolled reading position, originally \(originalOffset)")
        let document = (try? await web.evaluateJavaScript("({bodyLength:(document.querySelector('#NB-story')?.innerText || '').length,width:document.documentElement.clientWidth,generation:document.querySelector('meta[name=\"newsblur-story-load\"]')?.content || ''})")) as? [String: Any]
        XCTAssertGreaterThan((document?["bodyLength"] as? NSNumber)?.intValue ?? 0, 100, "\(name): the loaded article must remain readable")
        XCTAssertEqual((document?["width"] as? NSNumber)?.doubleValue ?? 0, Double(web.bounds.width), accuracy: 2, name)
        XCTAssertEqual(document?["generation"] as? String,
                       (page.value(forKey: "storyLoadGeneration") as? NSNumber)?.stringValue, name)
    }

    func test_nativeReaderPagingArrowsFollowOrientationAndShareTheirBackground() async throws {
        guard #available(iOS 27.1, *) else { throw XCTSkip("Requires native Duo bars") }
        let app = try await prepareApp()
        let pages = try await openReadableReader(app)
        guard pages.usesVerticalReaderToolbar else { throw XCTSkip("Requires Duo side controls") }
        let defaults = UserDefaults.standard
        let original = defaults.object(forKey: "scroll_stories_horizontally")
        defer {
            defaults.set(original, forKey: "scroll_stories_horizontally")
            pages.setNextPreviousButtons()
        }
        let previous = try XCTUnwrap(pages.value(forKey: "verticalPreviousButton") as? UIBarButtonItem)
        let next = try XCTUnwrap(pages.value(forKey: "verticalNextButton") as? UIBarButtonItem)
        let items = try XCTUnwrap(pages.value(forKey: "verticalReaderToolbarItems") as? [UIBarButtonItem])
        XCTAssertTrue(previous.sharesBackground)
        XCTAssertTrue(next.sharesBackground, "Previous and Next must form one continuous native group")
        XCTAssertEqual(try XCTUnwrap(items.firstIndex(of: next)), try XCTUnwrap(items.firstIndex(of: previous)) + 1)
        for horizontal in [true, false, true] {
            defaults.set(horizontal, forKey: "scroll_stories_horizontally")
            pages.setNextPreviousButtons()
            XCTAssertNotNil(previous.image?.pngData())
            XCTAssertNotNil(next.image?.pngData())
            XCTAssertEqual(previous.image?.pngData(), UIImage(systemName: horizontal ? "chevron.left" : "chevron.up")?.pngData())
            let symbol = next.title == "Done" ? "checkmark" : (horizontal ? "chevron.right" : "chevron.down")
            XCTAssertEqual(next.image?.pngData(), UIImage(systemName: symbol)?.pngData(),
                           "Refreshing unread state must retain the selected paging direction")
        }
    }

    func test_nativeFeedSidebarDividerResizesTheRenderedOverlay() async throws {
        let app = try await prepareApp()
        let detail = try XCTUnwrap(app.detailViewController)
        let split = try XCTUnwrap(app.splitViewController)
        guard !detail.isPhoneOrCompact, !split.isCollapsed, split.style == .doubleColumn else {
            throw XCTSkip("Requires expanded Duo")
        }
        let originalWidth = split.preferredPrimaryColumnWidth
        let savedWidth = UserDefaults.standard.object(forKey: "split_primary_width")
        defer {
            split.preferredPrimaryColumnWidth = originalWidth
            UserDefaults.standard.set(savedWidth, forKey: "split_primary_width")
            split.view.setNeedsLayout()
            split.view.layoutIfNeeded()
        }
        let pages = try await openReadableReader(app)
        let page = try XCTUnwrap(pages.currentPage)
        let web = try XCTUnwrap(page.webView)
        let generation = page.value(forKey: "storyLoadGeneration") as? NSNumber
        let articleWidth = web.bounds.width
        detail.show(column: .primary, animated: false)
        try await waitUntil("The native feed overlay must finish opening") {
            split.displayMode == .oneOverSecondary && split.transitionCoordinator == nil
        }
        try await settle(split)
        let primary = try XCTUnwrap(split.viewController(for: .primary)?.view)
        let before = primary.convert(primary.bounds, to: split.view)
        let divider = try XCTUnwrap(split.view.subviews.compactMap { $0 as? DividerView }.first)
        capture(try XCTUnwrap(app.window), named: "sidebar-resize-before", controller: split)
        XCTAssertFalse(divider.isHidden, "The visible primary overlay must expose its own resize handle")
        XCTAssertEqual(divider.frame.midX, before.maxX, accuracy: 3,
                       "The draggable separator must track the actual feed-list edge")
        let destination = before.width + 80
        let pan = DuoSidebarResizePan()
        // DuoPresentationTests.swift reproduces UIKit resetting translation after the first 10pt of real touch movement.
        pan.simulatedTouchDownLocation = CGPoint(x: before.maxX, y: before.midY)
        pan.simulatedLocation = CGPoint(x: before.maxX + 10, y: before.midY)
        pan.simulatedTranslation = .zero
        pan.simulatedState = .began
        split.perform(NSSelectorFromString("handleFeedsDividerPan:"), with: pan)
        pan.simulatedLocation.x = before.maxX + 60
        pan.simulatedTranslation.x = 50
        pan.simulatedState = .changed
        split.perform(NSSelectorFromString("handleFeedsDividerPan:"), with: pan)
        try await waitUntil("Dragging must include movement before recognition") {
            abs(primary.bounds.width - (before.width + 60)) < 2
        }
        // DuoPresentationTests.swift delivers the last 20pt only in .ended, as a lifted finger can finish between changed events.
        pan.simulatedLocation.x = before.minX + destination
        pan.simulatedTranslation.x = 70
        pan.simulatedState = .ended
        split.perform(NSSelectorFromString("handleFeedsDividerPan:"), with: pan)
        try await waitUntil("Dragging must resize the primary content, not just its handle") {
            abs(primary.bounds.width - destination) < 2
        }
        try await settle(split)
        XCTAssertEqual(divider.frame.midX, primary.convert(primary.bounds, to: split.view).maxX, accuracy: 3)
        XCTAssertEqual(web.bounds.width, articleWidth, accuracy: 1)
        XCTAssertTrue(pages.currentPage === page)
        XCTAssertEqual(page.value(forKey: "storyLoadGeneration") as? NSNumber, generation)
        capture(try XCTUnwrap(app.window), named: "sidebar-resize-after", controller: split)
        split.hide(.primary)
        try await settle(split)
        detail.show(column: .primary, animated: false)
        try await settle(split)
        XCTAssertEqual(primary.bounds.width, destination, accuracy: 2,
                       "The chosen width must survive closing and reopening the sidebar")
    }

    func test_expandedFeedsRevealPreservesReadableArticleViewport() async throws {
        let app = try await prepareApp()
        let detail = try XCTUnwrap(app.detailViewController)
        let split = try XCTUnwrap(app.splitViewController)
        guard detail.isPhone, !detail.isPhoneOrCompact, !split.isCollapsed,
              split.style == .doubleColumn, detail.storyTitlesOnLeft else {
            throw XCTSkip("Open Duo with story titles on the left before checking the native Feeds reveal")
        }
        let defaults = UserDefaults.standard
        let previousBehavior = defaults.object(forKey: "split_behavior")
        defer {
            if let previousBehavior { defaults.set(previousBehavior, forKey: "split_behavior") }
            else { defaults.removeObject(forKey: "split_behavior") }
            app.updateSplitBehavior(false)
        }
        defaults.set("auto", forKey: "split_behavior")
        app.updateSplitBehavior(false)
        let pages = try await openReadableReader(app)
        let page = try XCTUnwrap(pages.currentPage)
        let web = try XCTUnwrap(page.webView)
        let hash = try XCTUnwrap(page.activeStoryId)
        let generation = page.value(forKey: "storyLoadGeneration") as? NSNumber
        let window = try XCTUnwrap(web.window)
        split.hide(.primary)
        try await waitUntil("The reader must begin with the feed sidebar dismissed") {
            split.isFeedsListHidden && split.transitionCoordinator == nil
        }
        try await settle(pages)
        let readerWidth = pages.view.bounds.width
        let articleWidth = web.bounds.width
        let maximumReadingOffset = max(0, web.scrollView.contentSize.height - web.scrollView.bounds.height +
                                        web.scrollView.adjustedContentInset.top + web.scrollView.adjustedContentInset.bottom)
        web.scrollView.setContentOffset(CGPoint(x: 0, y: min(250, maximumReadingOffset / 2) - web.scrollView.adjustedContentInset.top), animated: false)
        try await settle(pages)
        let readingOffset = web.scrollView.contentOffset.y + web.scrollView.adjustedContentInset.top
        XCTAssertGreaterThan(articleWidth, 280, "The baseline article must have a readable viewport")
        capture(window, named: "feeds-reveal-reader-before", controller: pages)

        for cycle in 1...2 {
            if cycle == 1 {
                let nativeBar = try XCTUnwrap(detail.navigationController?.navigationBar)
                let feedsButton = try XCTUnwrap(allViews(in: nativeBar).first {
                    $0.accessibilityIdentifier == "expanded-feeds-back"
                } as? UIButton, "Exercise the rendered native leading Feeds action beside the source title")
                let buttonFrame = visibleViewport(of: feedsButton)
                XCTAssertGreaterThanOrEqual(buttonFrame.width, 44)
                XCTAssertGreaterThanOrEqual(buttonFrame.height, 44)
                XCTAssertTrue(window.hitTest(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY), with: nil)?.isDescendant(of: feedsButton) == true,
                              "The native leading Feeds action must receive a real touch before the journey invokes it")
                feedsButton.sendActions(for: .touchUpInside)
            } else {
                let stories = try XCTUnwrap(app.feedDetailViewController)
                let sidebar = try XCTUnwrap(stories.value(forKey: "sidebarBarButton") as? UIBarButtonItem)
                let action = try XCTUnwrap(sidebar.action)
                XCTAssertEqual(action, #selector(BaseViewController.toggleFeeds(_:)))
                XCTAssertTrue(UIApplication.shared.sendAction(action, to: sidebar.target, from: sidebar, for: nil),
                              "The existing Sidebar action must use the same supported reveal as the Feeds title")
            }
            try await waitUntil("The Feeds action must reveal its real sidebar") {
                !split.isFeedsListHidden && split.transitionCoordinator == nil &&
                    self.isVisible(app.feedsViewController)
            }
            try await settle(split)
            try await settle(pages)
            let viewport = (try await web.evaluateJavaScript("window.innerWidth")) as? NSNumber
            print("DUO_FEEDS_REVEAL cycle=\(cycle) preferred=\(split.preferredSplitBehavior.rawValue) resolved=\(split.splitBehavior.rawValue) mode=\(split.displayMode.rawValue) reader=\(pages.view.bounds) article=\(web.bounds) baselineReader=\(readerWidth) baselineArticle=\(articleWidth) viewport=\(String(describing: viewport))")
            if split.displayMode == .oneOverSecondary {
                XCTAssertEqual(split.splitBehavior, .overlay)
                XCTAssertEqual(pages.view.bounds.width, readerWidth, accuracy: 1)
                XCTAssertEqual(web.bounds.width, articleWidth, accuracy: 1)
            } else {
                XCTAssertEqual(split.displayMode, .oneBesideSecondary)
                XCTAssertEqual(split.splitBehavior, .tile)
                XCTAssertFalse(detail.leftContainerView.isHidden,
                               "Tiled Feeds must be beside story titles, never beside the article")
                XCTAssertTrue(detail.topContainerView.isHidden,
                              "Retain the article offscreen while the two visible columns are Feeds and story titles")
                XCTAssertTrue(isVisible(app.feedDetailViewController))
                XCTAssertFalse(isVisible(pages))
                XCTAssertTrue(detail.verticalDividerView.isHidden)
                let safeSecondary = detail.view.convert(detail.view.safeAreaLayoutGuide.layoutFrame, to: window)
                    .intersection(visibleViewport(of: detail.view))
                XCTAssertEqual(visibleViewport(of: detail.leftContainerView).width, safeSecondary.width, accuracy: 2,
                               "Story titles must fill the resolved secondary column after hinge protection")
                XCTAssertGreaterThanOrEqual(visibleViewport(of: detail.leftContainerView).width, 320)
                XCTAssertEqual(pages.view.bounds.width, readerWidth, accuracy: 1,
                               "The hidden reader retains its viewport for an unchanged reading position")
                XCTAssertEqual(web.bounds.width, articleWidth, accuracy: 1)

                let bar = try XCTUnwrap(detail.navigationController?.navigationBar)
                defer {
                    // DuoPresentationTests.swift records rendered ancestors even when the clipping wait fails before its success attachment.
                    let button = self.allViews(in: bar).first { $0.accessibilityIdentifier == "expanded-feeds-back" }
                    var frames: [String] = []
                    let navigation = detail.navigationController
                    frames.append("navigation=\(String(describing: navigation.map { type(of: $0) })) hidden=\(navigation?.isNavigationBarHidden ?? false) ownsTop=\(navigation?.topViewController === detail) ownsBar=\(bar.topItem === detail.navigationItem) title=\(String(describing: detail.navigationItem.titleView))")
                    for (index, item) in (detail.navigationItem.leftBarButtonItems ?? []).enumerated() {
                        let custom = item.customView
                        frames.append("leftItem[\(index)] label=\(item.accessibilityLabel ?? "") width=\(item.width) custom=\(String(describing: custom)) intrinsic=\(custom?.intrinsicContentSize ?? .zero) mounted=\(custom?.isDescendant(of: bar) ?? false)")
                    }
                    var ancestor = button
                    while let view = ancestor {
                        let layer = view.layer
                        frames.append("\(type(of: view)) frame=\(view.convert(view.bounds, to: window)) bounds=\(view.bounds) safe=\(view.safeAreaInsets) clips=\(view.clipsToBounds) hidden=\(view.isHidden) alpha=\(view.alpha) layer=\(layer.frame) presentation=\(String(describing: layer.presentation()?.frame)) animations=\(layer.animationKeys() ?? [])")
                        if view === window { break }
                        ancestor = view.superview
                    }
                    let diagnostic = "column=\(self.visibleViewport(of: detail.leftContainerView)) bar=\(bar.convert(bar.bounds, to: window)) barSafe=\(bar.safeAreaInsets) tableOffset=\(app.feedDetailViewController.storyTitlesTable.contentOffset) visibleButton=\(button.map { self.visibleViewport(of: $0) } ?? .zero)\n" + frames.joined(separator: "\n")
                    print("DUO_TILED_HEADING_RENDERED \(diagnostic)")
                    let attachment = XCTAttachment(string: diagnostic)
                    attachment.name = "tiled-leading-heading-rendered-\(cycle)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
                var stableHeadingSamples = 0
                try await waitUntil("The tiled story heading must finish rendering without clipping Feeds") {
                    guard let button = self.allViews(in: bar).first(where: {
                        $0.accessibilityIdentifier == "expanded-feeds-back"
                    }) as? UIButton else { return false }
                    let frame = button.convert(button.bounds, to: window)
                    let visible = self.visibleViewport(of: button)
                    guard frame.width >= 44, frame.height >= 44,
                          abs(frame.minX - visible.minX) < 0.5,
                          abs(frame.maxX - visible.maxX) < 0.5,
                          abs(frame.minY - visible.minY) < 0.5,
                          abs(frame.maxY - visible.maxY) < 0.5 else {
                        stableHeadingSamples = 0
                        return false
                    }
                    var ancestor: UIView? = button
                    while let view = ancestor, view !== window {
                        let layer = view.layer
                        if !(layer.animationKeys() ?? []).isEmpty {
                            stableHeadingSamples = 0
                            return false
                        }
                        if let presented = layer.presentation(),
                           abs(presented.frame.minX - layer.frame.minX) > 0.5 ||
                            abs(presented.frame.minY - layer.frame.minY) > 0.5 ||
                            abs(presented.opacity - layer.opacity) > 0.01 {
                            stableHeadingSamples = 0
                            return false
                        }
                        ancestor = view.superview
                    }
                    stableHeadingSamples += 1
                    return stableHeadingSamples >= 3
                }
                let button = try XCTUnwrap(allViews(in: bar).first {
                    $0.accessibilityIdentifier == "expanded-feeds-back"
                } as? UIButton)
                let heading = try XCTUnwrap(button.superview)
                let buttonFrame = button.convert(button.bounds, to: window)
                let headingFrame = heading.convert(heading.bounds, to: window)
                let columnFrame = visibleViewport(of: detail.leftContainerView)
                let headingGeometry = "column=\(columnFrame) heading=\(headingFrame) button=\(buttonFrame) visibleButton=\(visibleViewport(of: button))"
                print("DUO_TILED_HEADING \(headingGeometry)")
                let headingAttachment = XCTAttachment(string: headingGeometry)
                headingAttachment.name = "tiled-leading-heading-geometry-\(cycle)"
                headingAttachment.lifetime = .keepAlways
                add(headingAttachment)
                XCTAssertGreaterThanOrEqual(buttonFrame.minX, columnFrame.minX - 1)
                XCTAssertLessThanOrEqual(buttonFrame.minX, columnFrame.minX + 32)
                XCTAssertLessThanOrEqual(headingFrame.maxX, columnFrame.maxX + 1,
                                        "The complete live heading must remain inside the tiled story column")
                XCTAssertTrue(window.hitTest(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY), with: nil)?.isDescendant(of: button) == true,
                              "Feeds must remain tappable after the native sidebar finishes tiling")
            }
            XCTAssertEqual(try XCTUnwrap(viewport).doubleValue, Double(web.bounds.width), accuracy: 1)
            XCTAssertTrue(pages.currentPage === page)
            XCTAssertEqual(app.activeStory?["story_hash"] as? String, hash)
            XCTAssertEqual(page.value(forKey: "storyLoadGeneration") as? NSNumber, generation)
            XCTAssertEqual(web.scrollView.contentOffset.y + web.scrollView.adjustedContentInset.top, readingOffset, accuracy: 2,
                           "Revealing Feeds must retain the article's reading position")
            capture(window, named: "feeds-reveal-reader-visible-\(cycle)", controller: pages)

            if cycle == 2, split.displayMode == .oneBesideSecondary {
                let stories = try XCTUnwrap(app.feedDetailViewController)
                let table = try XCTUnwrap(stories.storyTitlesTable)
                let path = try await waitForJourneyRow(hash: hash, in: stories)
                table.scrollToRow(at: path, at: .middle, animated: false)
                try await settle(stories)
                XCTAssertEqual((table.cellForRow(at: path) as? FeedDetailTableCell)?.storyHash, hash)
                table.selectRow(at: path, animated: false, scrollPosition: .none)
                table.delegate?.tableView?(table, didSelectRowAt: path)
            } else {
                let returnItems = (detail.navigationItem.leftBarButtonItems ?? []) +
                    (detail.navigationItem.rightBarButtonItems ?? [])
                let returnSidebar = try XCTUnwrap(returnItems.first { $0.accessibilityLabel == "Sidebar" },
                                                 "Revealing Feeds must retain a visible action to return to reading")
                let returnAction = try XCTUnwrap(returnSidebar.action)
                XCTAssertEqual(returnAction, #selector(BaseViewController.toggleFeeds(_:)))
                XCTAssertTrue(UIApplication.shared.sendAction(returnAction, to: returnSidebar.target, from: returnSidebar, for: nil))
            }
            try await waitUntil("Dismissing Feeds must return to the two-column reader") {
                split.isFeedsListHidden && split.transitionCoordinator == nil
            }
            try await settle(pages)
            XCTAssertEqual(pages.view.bounds.width, readerWidth, accuracy: 1)
            XCTAssertEqual(web.bounds.width, articleWidth, accuracy: 1)
            XCTAssertFalse(detail.leftContainerView.isHidden, "Dismissing Feeds must restore the story-title column")
            XCTAssertFalse(detail.topContainerView.isHidden)
            XCTAssertTrue(isVisible(pages))
            XCTAssertTrue(pages.currentPage === page)
            XCTAssertEqual(page.value(forKey: "storyLoadGeneration") as? NSNumber, generation,
                           "Returning to the selected article must reuse its loaded document")
            XCTAssertEqual(web.scrollView.contentOffset.y + web.scrollView.adjustedContentInset.top, readingOffset, accuracy: 2)
            try await waitForReadableArticle(pages, app: app, selectedHash: hash)
            capture(window, named: "feeds-reveal-reader-returned-\(cycle)", controller: pages)
        }
    }

    func test_openDuoReadingJourneyAcrossFeedsFoldersAndStories() async throws {
        journeyScrolledStories.removeAll()
        let app = try await prepareApp()
        let detail = try XCTUnwrap(app.detailViewController)
        guard !detail.isPhoneOrCompact, app.splitViewController?.isCollapsed == false else {
            throw XCTSkip("Open iPhone Duo in Device Hub before running the reading journey")
        }
        let feeds = try XCTUnwrap(app.feedsViewController)
        let stories = try XCTUnwrap(app.feedDetailViewController)
        let folders = try XCTUnwrap(app.dictFoldersArray as? [String])
        let specialFolders: Set<String> = ["dashboard", "discover_sites", "daily_briefing", "infrequent",
            "everything", "river_blurblogs", "river_global", "saved_stories", "read_stories", "widget_stories", "try_feed", " "]
        let ordinaryFolders = folders.filter {
            !specialFolders.contains($0) && !$0.hasPrefix("trending:") &&
                (app.dictFolders[$0] as? [Any])?.contains(where: {
                    let id = String(describing: $0)
                    return Int(id) != nil && app.dictFeeds[id] != nil
                }) == true
        }
        guard ordinaryFolders.count >= 2 else {
            throw XCTSkip("The real account needs two subscribed folders for the open-Duo journey")
        }
        let defaults = UserDefaults.standard
        let domainName = try XCTUnwrap(Bundle.main.bundleIdentifier)
        let originalDomain = defaults.persistentDomain(forName: domainName) ?? [:]
        let originalIndex = feeds.intelligenceControl.selectedSegmentIndex
        let originalIntelligence = app.selectedIntelligence
        let originalShowingAll = feeds.viewShowingAllFeeds
        var changedReadFilterKeys = Set<String>()
        defer {
            // DuoPresentationTests.swift restores filter and folder expansion preferences after normal reading/navigation.
            feeds.intelligenceControl.selectedSegmentIndex = originalIndex
            feeds.selectIntelligence()
            let currentKeys = (defaults.persistentDomain(forName: domainName) ?? [:]).keys
            let keys = Set(currentKeys).union(originalDomain.keys).filter {
                $0 == "selectedIntelligence" || $0.hasPrefix("folderCollapsed:") || changedReadFilterKeys.contains($0)
            }
            for key in keys {
                if let value = originalDomain[key] { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
            app.collapsedFolders = nil
            feeds.reloadFeedTitlesTable()
            XCTAssertEqual(app.selectedIntelligence, originalIntelligence)
            XCTAssertEqual(feeds.viewShowingAllFeeds, originalShowingAll)
        }
        feeds.intelligenceControl.selectedSegmentIndex = 0
        feeds.selectIntelligence()
        try await settleFeedList(feeds, app: app)

        var candidates: [(folder: String, id: String)] = []
        var candidateIDs = Set<String>()
        for offset in 0..<2 {
            for folder in ordinaryFolders {
                let ids = (app.dictFolders[folder] as? [Any] ?? []).map { String(describing: $0) }
                    .filter { Int($0) != nil && app.dictFeeds[$0] != nil }
                    .sorted { isNewsletterJourneyFeed($0, app: app) == false && isNewsletterJourneyFeed($1, app: app) }
                if ids.indices.contains(offset), candidateIDs.insert(ids[offset]).inserted {
                    candidates.append((folder, ids[offset]))
                }
            }
        }
        // DuoPresentationTests.swift prioritizes regular RSS across folders over short billing/alert newsletters.
        candidates = candidates.filter { !isNewsletterJourneyFeed($0.id, app: app) } +
            candidates.filter { isNewsletterJourneyFeed($0.id, app: app) }
        var completedFeeds: [(folder: String, id: String)] = []
        var completedFolders: [String] = []
        var visitedHashes = Set<String>()
        for candidate in candidates.prefix(8) {
            try await revealFeedsForJourney(app)
            feeds.selectFeed(candidate.id, inFolder: candidate.folder)
            try await waitUntil("Journey feed \(candidate.id) must load its own rows", timeout: 30) {
                stories.storiesCollection.activeFeedIdStr == candidate.id && !stories.pageFetching &&
                    (stories.storiesCollection.storyLocationsCount > 0 || stories.pageFinished) &&
                    self.isVisible(stories) && !stories.storyTitlesTable.hasUncommittedUpdates
            }
            print("DUO_JOURNEY_LIST \(journeyListDiagnostics(stories))")
            guard let location = readableAdjacentJourneyLocation(stories) else {
                print("DUO_JOURNEY_ROUTE_SKIPPED feed=\(candidate.id): \(journeyBodyDiagnostics(stories))")
                continue
            }
            let hashes = try await readJourneyStoryPair(app, location: location,
                                                       name: "feed-\(candidate.id)", river: false)
            visitedHashes.formUnion(hashes)
            completedFeeds.append(candidate)
            if !completedFolders.contains(candidate.folder) { completedFolders.append(candidate.folder) }
            if completedFeeds.count == 3 { break }
        }
        XCTAssertEqual(completedFeeds.count, 3, "The journey must finish three real feed reading routes")
        XCTAssertGreaterThanOrEqual(completedFolders.count, 2, "The selected feeds must span at least two folders")
        guard completedFeeds.count == 3, completedFolders.count >= 2 else {
            throw AuditError.insufficientJourneyContent("Loaded \(completedFeeds.count) feeds in \(completedFolders.count) folders with adjacent readable articles")
        }
        let folderCandidates = completedFolders + ordinaryFolders.filter { !completedFolders.contains($0) }
        var completedRiverFolders: [String] = []
        for folder in folderCandidates.prefix(6) {
            try await revealFeedsForJourney(app)
            feeds.selectFolder(folder)
            try await waitUntil("Journey folder \(folder) must present its river") {
                stories.storiesCollection.isRiverView && stories.storiesCollection.activeFolder == folder &&
                    self.isVisible(stories)
            }
            if stories.storiesCollection.activeReadFilter != "all" {
                changedReadFilterKeys.insert(stories.storiesCollection.readFilterKey)
                try await selectAllStoriesForJourney(app)
            }
            try await waitUntil("Journey folder \(folder) must finish loading All stories", timeout: 30) {
                let load = stories.value(forKey: "firstPageLoad") as? StoryFirstPageLoad
                return stories.storiesCollection.isRiverView && stories.storiesCollection.activeFolder == folder &&
                    stories.storiesCollection.activeReadFilter == "all" && !stories.pageFetching &&
                    (load == nil || (load?.authoritativeReceived == true && load?.pending == false)) &&
                    (stories.storiesCollection.storyLocationsCount > 0 || stories.pageFinished) && self.isVisible(stories) &&
                    !stories.storyTitlesTable.hasUncommittedUpdates
            }
            print("DUO_JOURNEY_LIST \(journeyListDiagnostics(stories))")
            guard let location = try await readableJourneyRiverLocation(app, folder: folder) else {
                print("DUO_JOURNEY_ROUTE_SKIPPED folder=\(folder): \(journeyBodyDiagnostics(stories))")
                if let window = stories.view.window {
                    capture(window, named: "journey-ineligible-folder-\(slug(folder))", controller: stories)
                }
                continue
            }
            visitedHashes.formUnion(try await readJourneyStoryPair(app, location: location,
                                                                   name: "folder-\(completedRiverFolders.count + 1)", river: true))
            completedRiverFolders.append(folder)
            if completedRiverFolders.count == 2 { break }
        }
        XCTAssertEqual(completedRiverFolders.count, 2,
                       "The journey requires two actual folder rivers with readable adjacent articles; candidates=\(folderCandidates.prefix(6))")
        guard completedRiverFolders.count == 2 else {
            throw AuditError.insufficientJourneyContent("Only \(completedRiverFolders) supplied readable folder routes")
        }
        // DuoPresentationTests.swift revisits the first real feed after two rivers to exercise cached-reader replacement.
        let first = try XCTUnwrap(completedFeeds.first)
        try await revealFeedsForJourney(app)
        feeds.selectFeed(first.id, inFolder: first.folder)
        try await waitUntil("The revisited feed must replace the outgoing folder rows", timeout: 30) {
            stories.storiesCollection.activeFeedIdStr == first.id && !stories.storiesCollection.isRiverView &&
                !stories.pageFetching && stories.storiesCollection.storyLocationsCount > 1 &&
                self.isVisible(stories) && !stories.storyTitlesTable.hasUncommittedUpdates
        }
        let location = try XCTUnwrap(readableAdjacentJourneyLocation(stories))
        visitedHashes.formUnion(try await readJourneyStoryPair(app, location: location,
                                                               name: "feed-\(first.id)-return", river: false))
        let last = try XCTUnwrap(completedFeeds.last)
        try await auditRapidJourneySelection(app, outgoingFeed: first, finalFeed: last)
        XCTAssertGreaterThanOrEqual(visitedHashes.count, 6, "The journey must render multiple real stories from all three feeds")
        XCTAssertGreaterThanOrEqual(journeyScrolledStories.count, 3,
                                    "The journey must actually scroll at least three distinct articles through their content")
        print("DUO_JOURNEY_COMPLETE feeds=\(completedFeeds.map(\.id)) folders=\(completedRiverFolders) distinctStories=\(visitedHashes.count)")
    }

    func test_readerStorySyncPreservesCommentComposerFocus() async throws {
        try await assertReaderUpdatePreservesCommentComposerFocus(refreshPages: false)
    }

    func test_readerPageRefreshPreservesCommentComposerFocus() async throws {
        try await assertReaderUpdatePreservesCommentComposerFocus(refreshPages: true)
    }

    func test_readerExistingCommentReplyFitsWithoutSubmitting() async throws {
        let app = try await prepareApp()
        let pages = try await openReadableReader(app)
        let web = try XCTUnwrap(pages.currentPage?.webView)
        let hasReply = try await web.evaluateJavaScript("document.querySelector('a[href^=\"http://ios.newsblur.com/reply/\"]') !== null") as? Bool
        guard hasReply == true else {
            throw XCTSkip("The loaded subscribed article has no existing comment reply action")
        }
        // DuoPresentationTests.swift activates a real article reply link, allowing its normal navigation delegate to select the comment.
        let opened = try await web.evaluateJavaScript("(() => { const link = document.querySelector('a[href^=\"http://ios.newsblur.com/reply/\"]'); link.scrollIntoView({block: 'center'}); if (!link.getClientRects().length) return false; link.click(); return true; })()") as? Bool
        XCTAssertEqual(opened, true)
        try await auditCommentComposer(try await waitForPresentation(app), named: "reader-comment-reply", app: app)
    }

    func test_readerFontShareAndTrainerFitCurrentDuoPose() async throws {
        let app = try await prepareApp()
        let pages = try await openReadableReader(app)
        try await audit(pages, named: "reader-before-dialogs", app: app, scroll: false)

        pages.toggleFontSize(nil)
        let fontDialog = try await waitForPresentation(app)
        try await audit(fontDialog, named: "reader-font-settings", app: app)
        let fontNavigation = try XCTUnwrap(app.fontSettingsNavigationController)
        let fontSettings = try XCTUnwrap(fontNavigation.topViewController)
        // DuoPresentationTests.swift follows the Font row's action, whose displayed title is the user's selected font.
        try invoke("showFontList", on: fontSettings)
        try await waitUntil("Reader font chooser must be the visible page") {
            guard let visible = fontNavigation.topViewController else { return false }
            return visible !== fontSettings && self.isVisible(visible)
        }
        let fontList = try XCTUnwrap(fontNavigation.topViewController)
        try await audit(fontList, named: "reader-font-list", app: app)
        await dismissPresentations(app)

        let share = pages.toolbarItems?.first { $0.accessibilityIdentifier == "reader-share" }
        try invoke("openSendToDialog:", on: pages, sender: share ?? pages.buttonAction)
        try await audit(try await waitForPresentation(app), named: "reader-system-share", app: app, scroll: false)
        await dismissPresentations(app)

        try invoke("openStoryTrainerFromKeyboard:", on: pages)
        try await audit(try await waitForPresentation(app), named: "reader-story-trainer", app: app)
    }

    private func prepareApp() async throws -> NewsBlurAppDelegate {
        #if !targetEnvironment(simulator)
        throw XCTSkip("Duo presentation audit requires the simulator")
        #else
        guard #available(iOS 27.1, *), Bundle.main.bundleIdentifier == "com.newsblur.NB-Alpha" else {
            throw XCTSkip("Run the live NewsBlur Alpha target on iPhone Duo")
        }
        let environment = ProcessInfo.processInfo.environment
        guard environment["SIMULATOR_MODEL_IDENTIFIER"] == "iPhone19,4" ||
                UIDevice.current.name.localizedCaseInsensitiveContains("duo") else {
            throw XCTSkip("Select iPhone Duo in Device Hub before running this audit")
        }
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        guard let username = app.activeUsername, !username.isEmpty else {
            throw XCTSkip("Log in to the existing NB Alpha session before running the audit")
        }
        liveApp = app
        initialUsername = username
        keyboardFrameInScreen = nil
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidChange(_:)),
                                               name: UIResponder.keyboardDidChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidChange(_:)),
                                               name: UIResponder.keyboardDidShowNotification, object: nil)
        await dismissPresentations(app)
        app.detailViewController?.dismissDiscoverSites()
        app.showFeedsList(animated: false)
        try await waitUntil("Feed list and its toolbar must finish navigation") {
            guard let feeds = app.feedsViewController, let navigation = feeds.navigationController,
                  feeds.viewIfLoaded?.window != nil, navigation.topViewController === feeds,
                  navigation.transitionCoordinator == nil, feeds.transitionCoordinator == nil else { return false }
            if Utilities.usesSystemVerticalBar(feeds.traitCollection) {
                let expected = Set(["feed-list-add", "feed-list-settings"])
                // DuoPresentationTests.swift checks the container's source items; UIKit owns the rendered side rail.
                let actual = Set((feeds.toolbarItems ?? []).compactMap(\.accessibilityIdentifier))
                return expected.isSubset(of: actual)
            }
            return !feeds.feedViewToolbar.isHidden
        }
        try await settle(app.feedsViewController)
        return app
        #endif
    }

    private func revealFeedsForJourney(_ app: NewsBlurAppDelegate) async throws {
        app.showFeedsList(animated: false)
        let feeds = try XCTUnwrap(app.feedsViewController)
        try await waitUntil("The reading journey must reveal the real feed sidebar") {
            self.isVisible(feeds) && app.splitViewController?.isFeedsListHidden == false &&
                app.splitViewController?.transitionCoordinator == nil
        }
        try await settle(feeds)
    }

    private func isNewsletterJourneyFeed(_ id: String, app: NewsBlurAppDelegate) -> Bool {
        guard let metadata = app.dictFeeds[id] as? [String: Any] else { return false }
        let address = (metadata["feed_address"] as? String ?? "").lowercased()
        return (metadata["is_newsletter"] as? NSNumber)?.boolValue == true ||
            address.hasPrefix("newsletter:") || address.hasPrefix("http://newsletter:")
    }

    private func selectAllStoriesForJourney(_ app: NewsBlurAppDelegate) async throws {
        let stories = try XCTUnwrap(app.feedDetailViewController)
        try await settle(stories)
        try await waitUntil("The folder sidebar transition must finish and expose the real Options pill") {
            guard let split = app.splitViewController, split.isFeedsListHidden,
                  split.transitionCoordinator == nil,
                  app.detailViewController?.transitionCoordinator == nil,
                  stories.navigationController?.transitionCoordinator == nil,
                  stories.transitionCoordinator == nil,
                  let pill = stories.storyTitlesHeaderBar?.optionsPill,
                  let window = pill.window, pill.isEnabled, !pill.isHidden,
                  pill.bounds.width > 0, pill.bounds.height > 0 else { return false }
            // DuoPresentationTests.swift must not invoke a covered button while the native feed overlay is still disappearing.
            let point = pill.convert(CGPoint(x: pill.bounds.midX, y: pill.bounds.midY), to: window)
            return window.hitTest(point, with: nil)?.isDescendant(of: pill) == true
        }
        let options = stories.toolbarItems?.first { $0.accessibilityIdentifier == "story-list-options" }
        let tracePopover = ProcessInfo.processInfo.environment["NEWSBLUR_DUO_POPOVER_TRACE"] == "1"
        let traceStarted = ProcessInfo.processInfo.systemUptime
        func traceIdentity(_ object: AnyObject?) -> String {
            guard let object else { return "nil" }
            return "\(type(of: object))@\(Unmanaged.passUnretained(object).toOpaque())"
        }
        func traceController(_ controller: UIViewController?) -> String {
            guard let controller else { return "nil" }
            let view = controller.viewIfLoaded
            let navigation = controller as? UINavigationController
            return "\(traceIdentity(controller)) top=\(traceIdentity(navigation?.topViewController)) " +
                "presenting=\(traceIdentity(controller.presentingViewController)) presented=\(traceIdentity(controller.presentedViewController)) " +
                "window=\(traceIdentity(view?.window)) frame=\(String(describing: view?.frame)) " +
                "presentedFlag=\(controller.isBeingPresented) dismissedFlag=\(controller.isBeingDismissed) " +
                "coordinator=\(controller.transitionCoordinator != nil) style=\(controller.modalPresentationStyle.rawValue)"
        }
        func traceAncestors(_ view: UIView?) -> String {
            var ancestor = view
            var values: [String] = []
            while let current = ancestor, values.count < 12 {
                let presentation = current.layer.presentation()
                values.append("\(traceIdentity(current)) frame=\(current.frame) alpha=\(current.alpha) hidden=\(current.isHidden) " +
                    "presentationFrame=\(String(describing: presentation?.frame)) presentationOpacity=\(String(describing: presentation?.opacity)) " +
                    "animations=\(current.layer.animationKeys() ?? [])")
                ancestor = current.superview
            }
            return values.joined(separator: " | ")
        }
        func traceState(_ phase: String, dialog: UIViewController?) {
            guard tracePopover else { return }
            let elapsed = ProcessInfo.processInfo.systemUptime - traceStarted
            print("DUO_POPOVER_JOURNEY \(phase) elapsed=\(elapsed) mode=\(String(describing: app.splitViewController?.displayMode.rawValue)) " +
                "primary=\(traceController(app.feedsNavigationController)) presenter=\(traceController(stories.navigationController)) " +
                "observed=\(traceController(dialog))")
            print("DUO_POPOVER_JOURNEY \(phase) pillAncestors=\(traceAncestors(stories.storyTitlesHeaderBar.optionsPill))")
            print("DUO_POPOVER_JOURNEY \(phase) primaryAncestors=\(traceAncestors(app.feedsNavigationController?.viewIfLoaded))")
            if let popover = dialog?.popoverPresentationController {
                print("DUO_POPOVER_JOURNEY \(phase) source=\(traceIdentity(popover.sourceView)) rect=\(popover.sourceRect) " +
                    "barItem=\(traceIdentity(popover.barButtonItem)) actualPresenter=\(traceIdentity(popover.presentingViewController))")
            }
        }
        traceState("before-options", dialog: presentedController(in: app.window?.rootViewController))
        stories.doOpenOptionsMenu(options as Any? ?? stories.storyTitlesHeaderBar.optionsPill)
        let initialDialog = presentedController(in: app.window?.rootViewController)
        traceState("after-options", dialog: initialDialog)
        // DuoPresentationTests.swift observes the original menu without changing its timing or retrying a disappearing presentation.
        let traceTask: Task<Void, Never>? = tracePopover ? Task { @MainActor in
            var observedDialog = initialDialog
            var previousState = ""
            while !Task.isCancelled, ProcessInfo.processInfo.systemUptime - traceStarted < 12 {
                let current = self.presentedController(in: app.window?.rootViewController)
                if observedDialog == nil { observedDialog = current }
                let state = "observed=\(traceController(observedDialog)) current=\(traceController(current))"
                if state != previousState {
                    traceState("presentation-changed", dialog: observedDialog)
                    print("DUO_POPOVER_JOURNEY current=\(traceController(current))")
                    previousState = state
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        } : nil
        defer { traceTask?.cancel() }
        let dialog = try await waitForPresentation(app)
        try await settle(dialog)
        traceState("menu-settled", dialog: dialog)
        let control = try XCTUnwrap(allViews(in: dialog.view).compactMap { $0 as? UISegmentedControl }.first {
            $0.numberOfSegments == 2 && $0.titleForSegment(at: 0) == "All stories"
        }, "The real Options menu must expose its All stories control")
        XCTAssertGreaterThan(visibleViewport(of: control).height, 20)
        traceState("select-all-stories", dialog: dialog)
        control.selectedSegmentIndex = 0
        control.sendActions(for: .valueChanged)
        try await waitUntil("The Options action must select All stories and dismiss its menu") {
            stories.storiesCollection.activeReadFilter == "all" &&
                self.presentedController(in: app.window?.rootViewController) == nil
        }
        print("DUO_JOURNEY_FILTER folder=\(stories.storiesCollection.activeFolder ?? "nil") filter=\(stories.storiesCollection.activeReadFilter ?? "nil")")
    }

    private func journeyListDiagnostics(_ stories: FeedDetailViewController) -> String {
        guard let collection = stories.storiesCollection, let table = stories.storyTitlesTable else {
            return "Story collection or table not loaded"
        }
        let load = stories.value(forKey: "firstPageLoad") as? StoryFirstPageLoad
        let rows = (0..<table.numberOfSections).map { table.numberOfRows(inSection: $0) }
        return "activeFolder=\(collection.activeFolder ?? "nil") activeFeed=\(collection.activeFeedIdStr ?? "nil") " +
            "river=\(collection.isRiverView) readFilter=\(collection.activeReadFilter ?? "nil") " +
            "folderFeedCount=\(collection.activeFolderFeeds?.count ?? 0) modelCount=\(collection.storyLocationsCount) " +
            "tableRows=\(rows) pageFetching=\(stories.pageFetching) pageFinished=\(stories.pageFinished) " +
            "firstPagePending=\(String(describing: load?.pending)) authoritative=\(String(describing: load?.authoritativeReceived)) " +
            "visible=\(isVisible(stories)) updates=\(table.hasUncommittedUpdates) fetchGeneration=\(stories.fetchRequestId)"
    }

    private func readableAdjacentJourneyLocation(_ stories: FeedDetailViewController) -> Int? {
        let count = Int(stories.storiesCollection.storyLocationsCount)
        guard count >= 2 else { return nil }
        let lengths = journeyBodyLengths(stories)
        let candidates = (0..<(count - 1)).filter { lengths[$0] > 600 && lengths[$0 + 1] > 100 }
            .sorted { lengths[$0] > lengths[$1] }
        return candidates.first {
            (stories.getStoryAtLocation($0)?["read_status"] as? NSNumber)?.boolValue == true &&
                (stories.getStoryAtLocation($0 + 1)?["read_status"] as? NSNumber)?.boolValue == true
        } ?? candidates.first
    }

    private func journeyBodyLengths(_ stories: FeedDetailViewController) -> [Int] {
        (0..<Int(stories.storiesCollection.storyLocationsCount)).map { location in
            let html = stories.getStoryAtLocation(location)?["story_content"] as? String ?? ""
            return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines).count
        }
    }

    private func journeyBodyDiagnostics(_ stories: FeedDetailViewController) -> String {
        "\(journeyListDiagnostics(stories)) page=\(stories.storiesCollection.feedPage) bodyLengths=\(journeyBodyLengths(stories))"
    }

    private func readableJourneyRiverLocation(_ app: NewsBlurAppDelegate, folder: String) async throws -> Int? {
        let stories = try XCTUnwrap(app.feedDetailViewController)
        for pageAttempt in 0...2 {
            if let location = readableAdjacentJourneyLocation(stories) { return location }
            print("DUO_JOURNEY_PAIR_UNAVAILABLE folder=\(folder) attempt=\(pageAttempt) \(journeyBodyDiagnostics(stories))")
            guard pageAttempt < 2, !stories.pageFinished else { return nil }
            let previousPage = stories.storiesCollection.feedPage
            var receivedPage = false
            // DuoPresentationTests.swift requests the next real river page through the same public action as infinite scrolling.
            stories.fetchNextPage { receivedPage = true }
            try await waitUntil("Journey folder \(folder) must receive page \(previousPage + 1)", timeout: 30) {
                receivedPage && !stories.pageFetching && stories.storiesCollection.activeFolder == folder &&
                    stories.storiesCollection.feedPage > previousPage && !stories.storyTitlesTable.hasUncommittedUpdates
            }
        }
        return nil
    }

    private func readJourneyStoryPair(_ app: NewsBlurAppDelegate, location: Int,
                                       name: String, river: Bool) async throws -> Set<String> {
        let stories = try XCTUnwrap(app.feedDetailViewController)
        let pages = try XCTUnwrap(app.storyPagesViewController)
        let table = try XCTUnwrap(stories.storyTitlesTable)
        let firstHash = try XCTUnwrap(stories.getStoryAtLocation(location)?["story_hash"] as? String)
        let path = try await waitForJourneyRow(hash: firstHash, in: stories)
        table.scrollToRow(at: path, at: .middle, animated: false)
        try await settle(stories)
        try await waitUntil("Journey selection must use the visible row for \(firstHash)") {
            (table.cellForRow(at: path) as? FeedDetailTableCell)?.storyHash == firstHash &&
                !table.hasUncommittedUpdates
        }
        table.selectRow(at: path, animated: false, scrollPosition: .none)
        table.delegate?.tableView?(table, didSelectRowAt: path)
        try await auditJourneyArticle(app, hash: firstHash, named: "\(name)-first", river: river, scroll: true)

        let current = try XCTUnwrap(pages.currentPage)
        let nextHash = try XCTUnwrap(stories.getStoryAtLocation(current.pageIndex + 1)?["story_hash"] as? String)
        XCTAssertNotEqual(nextHash, firstHash)
        print("DUO_JOURNEY_NEXT name=\(name) currentIndex=\(current.pageIndex) currentHash=\(current.activeStoryId ?? "nil") expected=\(nextHash) nextIndex=\(pages.nextPage?.pageIndex ?? -1) nextHash=\(pages.nextPage?.activeStoryId ?? "nil") pager=\(String(describing: pages.scrollView?.bounds)) offset=\(String(describing: pages.scrollView?.contentOffset))")
        pages.changeToNextPage(nil)
        try await auditJourneyArticle(app, hash: nextHash, named: "\(name)-next", river: river, scroll: false)
        pages.changeToPreviousPage(nil)
        try await auditJourneyArticle(app, hash: firstHash, named: "\(name)-previous", river: river, scroll: true)
        return [firstHash, nextHash]
    }

    private func waitForJourneyRow(hash: String, in stories: FeedDetailViewController) async throws -> IndexPath {
        let table = try XCTUnwrap(stories.storyTitlesTable)
        var readyPath: IndexPath?
        // DuoPresentationTests.swift waits for the coalesced table reload after the model receives its feed response.
        try await waitUntil("The story table must render a row for journey article \(hash)", timeout: 30) {
            table.layoutIfNeeded()
            guard !stories.pageFetching, !table.hasUncommittedUpdates,
                  let location = (0..<Int(stories.storiesCollection.storyLocationsCount)).first(where: {
                      stories.getStoryAtLocation($0)?["story_hash"] as? String == hash
                  }), let path = stories.indexPath(forStoryLocation: location),
                  path.section < table.numberOfSections, path.row < table.numberOfRows(inSection: path.section) else { return false }
            readyPath = path
            return true
        }
        return try XCTUnwrap(readyPath)
    }

    private func auditRapidJourneySelection(_ app: NewsBlurAppDelegate,
                                             outgoingFeed: (folder: String, id: String),
                                             finalFeed: (folder: String, id: String)) async throws {
        try await revealFeedsForJourney(app)
        let feeds = try XCTUnwrap(app.feedsViewController)
        let stories = try XCTUnwrap(app.feedDetailViewController)
        let pages = try XCTUnwrap(app.storyPagesViewController)
        // DuoPresentationTests.swift sends both real selections in one main-actor turn, before the outgoing request can complete.
        feeds.selectFeed(outgoingFeed.id, inFolder: outgoingFeed.folder)
        feeds.selectFeed(finalFeed.id, inFolder: finalFeed.folder)
        try await waitUntil("The last rapid feed selection must own the loaded story list", timeout: 30) {
            stories.storiesCollection.activeFeedIdStr == finalFeed.id && !stories.pageFetching &&
                stories.storiesCollection.storyLocationsCount > 1 && self.isVisible(stories)
        }
        let location = try XCTUnwrap(readableAdjacentJourneyLocation(stories))
        let firstHash = try XCTUnwrap(stories.getStoryAtLocation(location)?["story_hash"] as? String)
        let finalHash = try XCTUnwrap(stories.getStoryAtLocation(location + 1)?["story_hash"] as? String)
        let firstPath = try await waitForJourneyRow(hash: firstHash, in: stories)
        let finalPath = try await waitForJourneyRow(hash: finalHash, in: stories)
        let table = try XCTUnwrap(stories.storyTitlesTable)
        table.scrollToRow(at: firstPath, at: .top, animated: false)
        try await settle(stories)
        try await waitUntil("The first rapid story must have a real visible row") {
            (table.cellForRow(at: firstPath) as? FeedDetailTableCell)?.storyHash == firstHash
        }
        table.selectRow(at: firstPath, animated: false, scrollPosition: .none)
        table.delegate?.tableView?(table, didSelectRowAt: firstPath)
        let outgoingWasLoading = pages.value(forKey: "pendingPresentationPage") != nil ||
            pages.value(forKey: "storySelectionTransitionHost") != nil || pages.currentPage?.webView?.isLoading == true ||
            app.activeStory?["story_hash"] as? String != firstHash
        XCTAssertTrue(outgoingWasLoading, "The rapid selection case must supersede an unfinished story presentation")
        table.scrollToRow(at: finalPath, at: .middle, animated: false)
        table.layoutIfNeeded()
        let finalCell = try XCTUnwrap(table.cellForRow(at: finalPath) as? FeedDetailTableCell)
        XCTAssertEqual(finalCell.storyHash, finalHash)
        table.selectRow(at: finalPath, animated: false, scrollPosition: .none)
        table.delegate?.tableView?(table, didSelectRowAt: finalPath)
        try await auditJourneyArticle(app, hash: finalHash, named: "rapid-final-story", river: false, scroll: true)
        var stableSamples = 0
        try await waitUntil("Late outgoing work must leave the final feed and story selected") {
            let stable = stories.storiesCollection.activeFeedIdStr == finalFeed.id &&
                app.activeStory?["story_hash"] as? String == finalHash &&
                pages.currentPage?.activeStory?["story_hash"] as? String == finalHash &&
                pages.value(forKey: "pendingPresentationPage") == nil &&
                pages.value(forKey: "storySelectionTransitionHost") == nil &&
                pages.value(forKey: "storySelectionRedrawCover") == nil && !stories.pageFetching
            stableSamples = stable ? stableSamples + 1 : 0
            return stableSamples >= 10
        }
        try await auditJourneyArticle(app, hash: finalHash, named: "rapid-final-story-settled", river: false, scroll: false)
        print("DUO_JOURNEY_RAPID outgoingFeed=\(outgoingFeed.id) finalFeed=\(finalFeed.id) supersededStory=\(firstHash) finalStory=\(finalHash) outgoingWasLoading=\(outgoingWasLoading)")
    }

    private func auditJourneyArticle(_ app: NewsBlurAppDelegate, hash: String,
                                      named name: String, river: Bool, scroll: Bool) async throws {
        let pages = try XCTUnwrap(app.storyPagesViewController)
        try await waitForReadableArticle(pages, app: app, selectedHash: hash)
        try await waitUntil("Journey article \(name) must finish replacing the outgoing document") {
            pages.value(forKey: "pendingPresentationPage") == nil &&
                pages.value(forKey: "storySelectionTransitionHost") == nil &&
                pages.value(forKey: "storySelectionRedrawCover") == nil &&
                !pages.scrollView.isDragging && !pages.scrollView.isDecelerating
        }
        try await settle(pages)
        let page = try XCTUnwrap(pages.currentPage)
        let web = try XCTUnwrap(page.webView)
        let window = try XCTUnwrap(web.window)
        XCTAssertEqual(page.activeStory?["story_hash"] as? String, hash)
        XCTAssertEqual(app.activeStory?["story_hash"] as? String, hash)
        XCTAssertEqual(app.storiesCollection.isRiverView, river)
        XCTAssertFalse(app.detailViewController.isPhoneOrCompact)
        let webFrame = web.convert(web.bounds, to: window)
        let readerFrame = pages.view.convert(pages.view.bounds, to: window)
        XCTAssertTrue(window.bounds.insetBy(dx: -2, dy: -2).contains(readerFrame),
                      "\(name): reader frame \(readerFrame) must stay inside \(window.bounds)")
        XCTAssertTrue(readerFrame.insetBy(dx: -2, dy: -2).contains(webFrame),
                      "\(name): web frame \(webFrame) must stay inside reader \(readerFrame)")
        XCTAssertGreaterThan(web.bounds.width, 250, "\(name): the open Duo article must retain readable width")
        XCTAssertEqual(visibleViewport(of: web).width, web.bounds.width, accuracy: 2,
                       "\(name): no ancestor may clip the article behind a sidebar")

        let expectedTitle = try XCTUnwrap(page.activeStory?["story_title"] as? String)
        let titleJSON = try XCTUnwrap(String(data: JSONSerialization.data(withJSONObject: expectedTitle, options: .fragmentsAllowed), encoding: .utf8))
        let script = """
        (() => {
          const decoder = document.createElement('textarea'); decoder.innerHTML = \(titleJSON);
          const normalize = value => (value || '').replace(/\\s+/g, ' ').trim();
          return {titleMatches: normalize(document.querySelector('.NB-story-permalink')?.textContent) === normalize(decoder.value),
            title: document.querySelector('.NB-story-permalink')?.textContent || '',
            bodyLength: (document.querySelector('#NB-story')?.innerText || '').length,
            width: document.documentElement.clientWidth,
            generation: document.querySelector('meta[name="newsblur-story-load"]')?.content || ''};
        })()
        """
        let documentResult = try await web.evaluateJavaScript(script)
        let document = try XCTUnwrap(documentResult as? [String: Any])
        XCTAssertEqual(document["titleMatches"] as? Bool, true, "\(name): the reader must show the selected title, not outgoing content")
        XCTAssertGreaterThan((document["bodyLength"] as? NSNumber)?.intValue ?? 0, 100)
        XCTAssertEqual(document["generation"] as? String,
                       (page.value(forKey: "storyLoadGeneration") as? NSNumber)?.stringValue)
        XCTAssertEqual((document["width"] as? NSNumber)?.doubleValue ?? 0, Double(web.bounds.width), accuracy: 1)

        func assertHeaderDuringProgrammaticScroll(_ position: String) throws {
            let header = try XCTUnwrap(page.feedTitleGradient)
            XCTAssertTrue(header.superview === web, "\(name)-\(position): feed header must belong to the visible article")
            XCTAssertFalse(header.isHidden)
            XCTAssertGreaterThan(header.alpha, 0.99)
            if pages.usesVerticalReaderToolbar {
                XCTAssertEqual(header.convert(header.bounds, to: web).minY, web.scrollView.contentInset.top, accuracy: 1,
                               "\(name)-\(position): programmatic position changes must preserve the visible feed header")
            }
            if river {
                let story = try XCTUnwrap(page.activeStory as? [AnyHashable: Any])
                let metadata = try XCTUnwrap(app.feedMetadata(forStory: story, preferActiveFeeds: false))
                let title = try XCTUnwrap(metadata["feed_title"] as? String)
                XCTAssertTrue(header.subviews.compactMap { $0 as? UILabel }.contains { $0.text == title },
                              "\(name)-\(position): the header must name the current article's feed")
            }
        }
        let scroller = web.scrollView
        var scrollEvidence: [String] = []
        func recordScrollGeometry(_ position: String, phase: String, requested: CGFloat) {
            let minimum = -scroller.adjustedContentInset.top
            let maximum = max(minimum, scroller.contentSize.height - scroller.bounds.height + scroller.adjustedContentInset.bottom)
            let state = "\(name)-\(position) phase=\(phase) requested=\(requested) actual=\(scroller.contentOffset) content=\(scroller.contentSize) bounds=\(scroller.bounds) inset=\(scroller.contentInset) adjusted=\(scroller.adjustedContentInset) legalRange=\(minimum)...\(maximum) web=\(web.bounds) loading=\(web.isLoading) generation=\(String(describing: page.value(forKey: "storyLoadGeneration")))"
            scrollEvidence.append(state)
            print("DUO_JOURNEY_SCROLL \(state)")
        }
        let top = -scroller.adjustedContentInset.top
        recordScrollGeometry("top", phase: "before", requested: top)
        scroller.setContentOffset(CGPoint(x: 0, y: top), animated: false)
        try await settle(pages)
        recordScrollGeometry("top", phase: "settled", requested: top)
        try assertHeaderDuringProgrammaticScroll("top")
        capture(window, named: "journey-\(name)-top", controller: pages)
        if scroll {
            let bottom = max(top, scroller.contentSize.height - scroller.bounds.height + scroller.adjustedContentInset.bottom)
            if bottom - top > 100 { journeyScrolledStories.insert(hash) }
            for (position, offset) in [("middle", min(top + 300, bottom)), ("bottom", bottom), ("return-top", top)] {
                recordScrollGeometry(position, phase: "before", requested: offset)
                scroller.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
                try await settle(pages)
                recordScrollGeometry(position, phase: "settled", requested: offset)
                XCTAssertEqual(scroller.contentOffset.y, offset, accuracy: 2, "\(name)-\(position): article scroll must settle at the requested position")
                try assertHeaderDuringProgrammaticScroll(position)
                capture(window, named: "journey-\(name)-\(position)", controller: pages)
            }
        }
        let evidence = "\(name) hash=\(hash) feed=\(String(describing: page.activeStory?["story_feed_id"])) reader=\(readerFrame) web=\(webFrame) document=\(document)\n" + scrollEvidence.joined(separator: "\n")
        let attachment = XCTAttachment(string: evidence)
        attachment.name = "journey-\(name)-document"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("DUO_JOURNEY_ARTICLE \(evidence)")
    }

    private func openSubscribedFeed(_ app: NewsBlurAppDelegate) async throws -> FeedDetailViewController {
        let folders = try XCTUnwrap(app.dictFoldersArray as? [String])
        for folder in folders {
            guard let feedIDs = app.dictFolders[folder] as? [Any] else { continue }
            for value in feedIDs {
                let feedID = String(describing: value)
                guard Int(feedID) != nil, app.dictFeeds[feedID] != nil else { continue }
                app.feedsViewController.selectFeed(feedID, inFolder: folder)
                let stories = try XCTUnwrap(app.feedDetailViewController)
                try await waitUntil("Subscribed feed must be visible") {
                    stories.viewIfLoaded?.window != nil && stories.storiesCollection.activeFeedIdStr == feedID
                }
                try await settle(stories)
                return stories
            }
        }
        throw XCTSkip("The logged-in account needs a subscribed feed for site and reader dialogs")
    }

    private func selectVisibleStoryForReader(_ stories: FeedDetailViewController) async throws -> String {
        try await settle(stories)
        let table = try XCTUnwrap(stories.storyTitlesTable)
        try await waitUntil("A subscribed story list must finish loading", timeout: 30) {
            !stories.pageFetching && !table.isHidden && !table.hasUncommittedUpdates &&
                stories.storiesCollection.storyLocationsCount > 0
        }
        table.layoutIfNeeded()

        func matchingVisibleRows() -> [(path: IndexPath, hash: String, isRead: Bool)] {
            table.visibleCells.compactMap { cell in
                guard let cell = cell as? FeedDetailTableCell, let path = table.indexPath(for: cell) else { return nil }
                let location = stories.storyLocation(for: path)
                guard location >= 0, location < stories.storiesCollection.storyLocationsCount,
                      let story = stories.getStoryAtLocation(location), let hash = story["story_hash"] as? String,
                      cell.storyHash == hash else { return nil }
                return (path, hash, (story["read_status"] as? NSNumber)?.boolValue == true)
            }
        }

        var selected = matchingVisibleRows().first { $0.isRead }
        if selected == nil {
            for location in 0..<Int(stories.storiesCollection.storyLocationsCount) {
                guard let story = stories.getStoryAtLocation(location),
                      (story["read_status"] as? NSNumber)?.boolValue == true,
                      let hash = story["story_hash"] as? String,
                      let path = stories.indexPath(forStoryLocation: location),
                      path.section < table.numberOfSections, path.row < table.numberOfRows(inSection: path.section) else { continue }
                table.scrollToRow(at: path, at: .middle, animated: false)
                try await settle(stories)
                try await waitUntil("The already-read story row must match its loaded story") {
                    selected = matchingVisibleRows().first { $0.path == path && $0.hash == hash }
                    return selected != nil
                }
                break
            }
        }
        if selected == nil {
            // DuoPresentationTests.swift only falls back to an unread row when this loaded feed has no read story.
            try await waitUntil("A visible story row must match its loaded story") {
                selected = matchingVisibleRows().first
                return selected != nil
            }
        }
        let row = try XCTUnwrap(selected)
        table.selectRow(at: row.path, animated: false, scrollPosition: .none)
        table.delegate?.tableView?(table, didSelectRowAt: row.path)
        return row.hash
    }

    private func openReadableReader(_ app: NewsBlurAppDelegate) async throws -> StoryPagesViewController {
        let stories = try await openSubscribedFeed(app)
        let selectedHash = try await selectVisibleStoryForReader(stories)
        let pages = try XCTUnwrap(app.storyPagesViewController)
        try await waitUntil("Story reader must be visible") { self.isVisible(pages) }
        try await settle(pages)
        try await waitForReadableArticle(pages, app: app, selectedHash: selectedHash)
        return pages
    }

    private func waitForReadableArticle(_ pages: StoryPagesViewController, app: NewsBlurAppDelegate,
                                         selectedHash: String) async throws {
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            if let page = pages.currentPage, let web = page.webView,
               !web.isHidden, web.alpha > 0.99, !web.isLoading,
               visibleViewport(of: web).height > 80,
               app.activeStory?["story_hash"] as? String == selectedHash {
                let text = (try? await web.evaluateJavaScript("document.querySelector('#NB-story')?.innerText || ''")) as? String ?? ""
                let generation = (try? await web.evaluateJavaScript("document.querySelector('meta[name=\"newsblur-story-load\"]')?.content || ''")) as? String
                let currentGeneration = (page.value(forKey: "storyLoadGeneration") as? NSNumber)?.stringValue
                if text.count > 100, generation == currentGeneration, generation?.isEmpty == false {
                    XCTAssertFalse(web.isHidden)
                    XCTAssertGreaterThan(text.count, 100, "Reader dialogs must open above a readable article")
                    return
                }
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        func pageState(_ page: StoryDetailViewController?) -> String {
            guard let page else { return "nil" }
            let web = page.webView
            return "index=\(page.pageIndex) id=\(page.activeStoryId ?? "nil") modelHash=\(String(describing: page.activeStory?["story_hash"])) generation=\(String(describing: page.value(forKey: "storyLoadGeneration"))) hasStory=\(page.hasStory) ready=\(page.readyForPresentation) hidden=\(String(describing: web?.isHidden)) alpha=\(String(describing: web?.alpha)) loading=\(String(describing: web?.isLoading)) bounds=\(String(describing: web?.bounds))"
        }
        let documentScript = """
        JSON.stringify({readyState:document.readyState,
          title:document.querySelector('.NB-story-permalink')?.textContent || '',
          bodyLength:(document.querySelector('#NB-story')?.innerText || '').length,
          generation:document.querySelector('meta[name="newsblur-story-load"]')?.content || '',
          fonts:document.fonts.status,
          viewport:[innerWidth,innerHeight], document:[document.documentElement.clientWidth,document.documentElement.scrollHeight],
          scroll:[scrollX,scrollY]})
        """
        let document = try? await pages.currentPage?.webView?.evaluateJavaScript(documentScript)
        let readiness = "expected=\(selectedHash) appHash=\(String(describing: app.activeStory?["story_hash"])) selectedRow=\(String(describing: app.feedDetailViewController?.storyTitlesTable?.indexPathForSelectedRow))\ncurrent={\(pageState(pages.currentPage))}\nprevious={\(pageState(pages.previousPage))}\nnext={\(pageState(pages.nextPage))}\npager=\(String(describing: pages.scrollView?.bounds)) offset=\(String(describing: pages.scrollView?.contentOffset)) insets=\(String(describing: pages.scrollView?.adjustedContentInset)) dragging=\(pages.isDraggingScrollview) scrollingTo=\(pages.scrollingToPage) pending=\(String(describing: pages.value(forKey: "pendingPresentationHash"))) transition=\(pages.value(forKey: "storySelectionTransitionHost") != nil) redraw=\(pages.value(forKey: "storySelectionRedrawCover") != nil)\ndocument=\(String(describing: document))"
        let attachment = XCTAttachment(string: readiness)
        attachment.name = "reader-readiness-timeout-state"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("DUO_READER_READINESS_TIMEOUT \(readiness)")
        try await waitUntil("The selected story must visibly render current article text before reader dialogs", timeout: 0) { false }
    }

    private func waitForManagementContent(_ title: String, in dialog: UIViewController,
                                          app: NewsBlurAppDelegate) async throws {
        if title == "Mute Sites" {
            let chooser = try XCTUnwrap(descendant(named: "FeedChooserViewController", in: dialog))
            try await waitUntil("Mute Sites must finish loading subscribed and inactive feeds", timeout: 30) {
                guard let table = chooser.value(forKey: "tableView") as? UITableView else { return false }
                return !self.hasVisibleLoadingIndicator(in: chooser.view) && !table.hasUncommittedUpdates &&
                    !table.visibleCells.isEmpty && chooser.value(forKey: "dictFolders") != nil
            }
        } else if title == "Find Friends" {
            let friends = try XCTUnwrap(descendant(named: "FriendsListViewController", in: dialog))
            let requested = try XCTUnwrap(app.value(forKey: "friendsListViewController") as? UIViewController)
            XCTAssertTrue(friends === requested, "Suggested friends must load into the presented controller")
            try await waitUntil("The visible Find Friends controller must receive its suggested profiles", timeout: 30) {
                guard let profiles = friends.value(forKey: "suggestedUserProfiles") as? NSArray,
                      let table = friends.value(forKey: "friendsTable") as? UITableView else { return false }
                return !self.hasVisibleLoadingIndicator(in: friends.view) && !table.hasUncommittedUpdates &&
                    (profiles.count == 0 || !table.visibleCells.isEmpty)
            }
            let profiles = try XCTUnwrap(friends.value(forKey: "suggestedUserProfiles") as? [[String: Any]])
            let table = try XCTUnwrap(friends.value(forKey: "friendsTable") as? UITableView)
            let cells = table.visibleCells.filter { self.visibleViewport(of: $0).height > 40 }
            XCTAssertFalse(cells.isEmpty, "Find Friends must display a profile or an explicit empty state")
            for cell in cells {
                guard let path = table.indexPath(for: cell) else { continue }
                guard profiles.isEmpty || profiles.indices.contains(path.row) else {
                    XCTFail("Find Friends rendered a row outside its loaded suggested profiles")
                    continue
                }
                let expected = profiles.isEmpty ? "No friends to suggest." : profiles[path.row]["username"] as? String
                let matchingLabels = allViews(in: cell).compactMap { $0 as? UILabel }.filter {
                    $0.text == expected && self.visibleViewport(of: $0).width > 20 && self.visibleViewport(of: $0).height > 10
                }
                XCTAssertFalse(matchingLabels.isEmpty, "Find Friends row \(path.row) must visibly render \(expected ?? "its username")")
            }
        }
    }

    private func waitForDiscoverContent(_ tab: DiscoverTab, model: DiscoverSitesViewModel) async throws {
        func categoryState() -> CategoryTabState? {
            switch tab {
            case .popular: return model.popularState
            case .youtube: return model.youtubeState
            case .reddit: return model.redditState
            case .newsletters: return model.newslettersState
            case .podcasts: return model.podcastsState
            default: return nil
            }
        }
        try await waitUntil("Discover \(tab.label) must finish loading its actual content", timeout: 30) {
            if let state = categoryState() {
                return !state.isLoading && (state.isCategoriesLoaded || state.errorMessage != nil)
            }
            switch tab {
            case .search:
                return !model.searchState.isTrendingLoading &&
                    (model.searchState.isTrendingLoaded || model.searchState.trendingErrorMessage != nil)
            case .googleNews:
                return !model.googleNewsState.isLoading &&
                    (model.googleNewsState.isDataLoaded || model.googleNewsState.errorMessage != nil)
            case .webFeed: return true
            default: return false
            }
        }
        if let state = categoryState() {
            XCTAssertNil(state.errorMessage, "\(tab.label) failed to load")
            XCTAssertFalse(state.feeds.isEmpty, "\(tab.label) must display loaded feed cards")
        } else if tab == .search {
            XCTAssertNil(model.searchState.trendingErrorMessage)
            XCTAssertFalse(model.searchState.trendingFeeds.isEmpty, "Search must display loaded trending feeds")
        } else if tab == .googleNews {
            XCTAssertNil(model.googleNewsState.errorMessage)
            XCTAssertFalse(model.googleNewsState.topics.isEmpty, "Google News must load its topic options")
        }
    }

    private func waitForStatisticsContent(_ browser: OriginalStoryViewController) async throws {
        let web = try XCTUnwrap(browser.webView)
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            if !web.isLoading, web.url?.path.contains("/rss_feeds/statistics_embedded/") == true,
               !hasVisibleLoadingIndicator(in: browser.view) {
                let text = (try? await web.evaluateJavaScript("document.readyState === 'complete' && document.querySelector('.NB-modal-statistics-info .NB-statistics-count') ? document.body.innerText : ''")) as? String ?? ""
                if text.count > 100 {
                    return
                }
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        try await waitUntil("Site Statistics must render its loaded statistics document", timeout: 0) { false }
    }

    private func hasVisibleLoadingIndicator(in view: UIView) -> Bool {
        allViews(in: view).contains {
            let isLoading = String(describing: type(of: $0)).contains("MBProgressHUD") ||
                ($0 as? UIActivityIndicatorView)?.isAnimating == true
            return isLoading && !self.visibleViewport(of: $0).isEmpty
        }
    }

    private func auditBottom(of controller: UIViewController, named name: String) async throws {
        let scroller = try XCTUnwrap(allViews(in: controller.view).compactMap { $0 as? UIScrollView }
            .filter { self.visibleViewport(of: $0).height > 80 && $0.contentSize.height > $0.bounds.height + 40 }
            .max { $0.bounds.height < $1.bounds.height })
        let originalOffset = scroller.contentOffset
        defer { scroller.setContentOffset(originalOffset, animated: false) }
        let maximum = max(-scroller.adjustedContentInset.top,
                          scroller.contentSize.height - scroller.bounds.height + scroller.adjustedContentInset.bottom)
        scroller.setContentOffset(CGPoint(x: originalOffset.x, y: maximum), animated: false)
        try await settle(controller)
        XCTAssertEqual(scroller.contentOffset.y, maximum, accuracy: 1,
                       "The entire settings form must be reachable by scrolling")
        capture(try XCTUnwrap(controller.view.window), named: name, controller: controller)
    }

    private func selectMenuRow(_ title: String, in menu: MenuViewController) throws {
        let table = try XCTUnwrap(menu.menuTableView)
        try selectTableRow(title, in: table)
    }

    private func openSiteSettings(_ stories: FeedDetailViewController) {
        // DuoPresentationTests.swift uses the visible settings source so popovers follow the same anchor as a tap.
        let settings = stories.toolbarItems?.first { $0.accessibilityIdentifier == "story-list-settings" }
            ?? stories.settingsBarButton
        stories.doOpenSettingsMenu(settings)
    }

    private func selectTableRow(_ title: String, in table: UITableView) throws {
        for section in 0..<table.numberOfSections {
            for row in 0..<table.numberOfRows(inSection: section) {
                let path = IndexPath(row: row, section: section)
                let cell = try XCTUnwrap(table.dataSource?.tableView(table, cellForRowAt: path))
                if allViews(in: cell).compactMap({ ($0 as? UILabel)?.text }).contains(title) {
                    table.delegate?.tableView?(table, didSelectRowAt: path)
                    return
                }
            }
        }
        XCTFail("Missing expected menu route: \(title)")
        throw AuditError.missingRoute(title)
    }

    private func tableCellTitles(_ table: UITableView) -> [String] {
        var titles: [String] = []
        for section in 0..<table.numberOfSections {
            for row in 0..<table.numberOfRows(inSection: section) {
                let path = IndexPath(row: row, section: section)
                if let cell = table.dataSource?.tableView(table, cellForRowAt: path) {
                    titles += allViews(in: cell).compactMap { ($0 as? UILabel)?.text }
                }
            }
        }
        return titles
    }

    private func assertReaderUpdatePreservesCommentComposerFocus(refreshPages: Bool) async throws {
        let app = try await prepareApp()
        let pages = try await openReadableReader(app)
        let page = try XCTUnwrap(pages.currentPage)
        page.openShareDialog()
        let dialog = try await waitForPresentation(app)
        try await settle(dialog)
        let input = try XCTUnwrap(allViews(in: dialog.view).compactMap { $0 as? UITextView }.first { $0.isEditable })
        let originalText = input.text
        // DuoPresentationTests.swift models tapping the editor; the separate composer audit still requires automatic focus.
        XCTAssertTrue(input.becomeFirstResponder(), "The presented composer must accept keyboard focus")
        try await waitUntil("The presented comment editor must own keyboard focus before refreshing the reader") {
            input.isFirstResponder && self.isVisible(dialog)
        }
        let operation = refreshPages ? "page-refresh" : "story-sync"
        if refreshPages {
            pages.refreshPages()
        } else {
            pages.setStoryFromScroll(true)
        }
        await Task.yield()
        XCTAssertTrue(input.isFirstResponder, "Reader \(operation) must preserve the presented comment editor's focus")
        XCTAssertFalse(dialog.isBeingDismissed, "Reader \(operation) must leave the comment composer open")
        XCTAssertTrue(isVisible(dialog), "Reader \(operation) must preserve the visible composer")
        XCTAssertEqual(input.text, originalText, "Reader refreshes must leave the draft untouched")
        if let window = app.window {
            capture(window, named: "reader-composer-after-\(operation)", controller: dialog)
        }
    }

    private func auditCommentComposer(_ dialog: UIViewController, named name: String,
                                        app: NewsBlurAppDelegate) async throws {
        let input = try XCTUnwrap(allViews(in: dialog.view).compactMap { $0 as? UITextView }.first { $0.isEditable })
        let originalText = input.text
        let window = try XCTUnwrap(dialog.view.window)
        try await waitUntil("The comment composer keyboard must be visible") {
            input.isFirstResponder && self.visibleKeyboardFrame(in: window).height > 100
        }
        try await settle(dialog)
        let keyboard = visibleKeyboardFrame(in: window)
        let inputFrame = input.convert(input.bounds, to: window)
        XCTAssertGreaterThan(inputFrame.height, 44, "The comment editor must retain usable space above the keyboard")
        XCTAssertLessThanOrEqual(inputFrame.maxY, keyboard.minY + 1)
        let submit = try XCTUnwrap(allViews(in: dialog.view).compactMap { $0 as? UIButton }.first {
            let title = $0.currentTitle ?? ""
            return title == "Share" || title == "Save reply" || title.hasPrefix("Reply to ")
        })
        let submitFrame = submit.convert(submit.bounds, to: window)
        XCTAssertTrue(window.bounds.contains(submitFrame), "The composer action must remain on screen")
        XCTAssertLessThanOrEqual(submitFrame.maxY, keyboard.minY + 1, "The keyboard must not cover the composer action")
        try await audit(dialog, named: name, app: app, scroll: false)
        XCTAssertEqual(input.text, originalText, "Presentation checks must leave the draft untouched")
        await dismissPresentations(app)
    }

    private func waitForNextMenu(after previous: MenuViewController) async throws -> MenuViewController {
        try await waitUntil("Nested site-management menu must be visible") {
            guard let next = previous.navigationController?.topViewController as? MenuViewController else { return false }
            return next !== previous && self.isVisible(next)
        }
        let menu = try XCTUnwrap(previous.navigationController?.topViewController as? MenuViewController)
        try await settle(menu)
        return menu
    }

    private func invoke(_ name: String, on target: NSObject, sender: Any? = nil) throws {
        let selector = NSSelectorFromString(name)
        guard target.responds(to: selector) else {
            XCTFail("Missing public presentation action: \(name)")
            throw AuditError.missingRoute(name)
        }
        target.perform(selector, with: sender)
    }

    private func audit(_ controller: UIViewController, named name: String,
                       app: NewsBlurAppDelegate, scroll: Bool = true) async throws {
        try await settle(controller)
        let window = try XCTUnwrap(controller.view.window)
        let frame = controller.view.convert(controller.view.bounds, to: window)
        XCTAssertGreaterThan(frame.width, 150, "\(name) must retain usable width")
        XCTAssertGreaterThan(frame.height, 80, "\(name) must retain usable height")
        XCTAssertTrue(window.bounds.insetBy(dx: -2, dy: -2).contains(frame),
                      "\(name) extends outside the screen: \(frame), window \(window.bounds)")
        let visibleFrame = visibleViewport(of: controller.view)
        XCTAssertTrue(isVisible(controller), "\(name) must be in the visible navigation branch with visible ancestors")
        XCTAssertGreaterThan(visibleFrame.width, 150, "\(name) is clipped or hidden horizontally: \(visibleFrame)")
        XCTAssertGreaterThan(visibleFrame.height, 80, "\(name) is clipped or hidden vertically: \(visibleFrame)")
        if controller.presentationController?.presentationStyle == .popover,
           let popover = controller.popoverPresentationController {
            if let item = popover.barButtonItem {
                let anchor = try XCTUnwrap(item.frame(in: window), "\(name) bar button must have a live anchor")
                XCTAssertFalse(anchor.isEmpty, "\(name) bar button anchor must have area")
                XCTAssertTrue(window.bounds.intersects(anchor), "\(name) bar button is off screen")
            } else if let source = popover.sourceView {
                XCTAssertTrue(source.window === window, "\(name) must anchor to an attached view")
                let anchor = source.convert(popover.sourceRect, to: window)
                XCTAssertTrue(window.bounds.intersects(anchor), "\(name) popover anchor is off screen: \(anchor)")
            } else {
                XCTFail("\(name) popover has no source view or bar button")
            }
        }
        capture(window, named: name, controller: controller)
        if scroll, let scroller = allViews(in: controller.view).compactMap({ $0 as? UIScrollView })
            .filter({ !$0.isHidden && $0.bounds.height > 80 && $0.contentSize.height > $0.bounds.height + 40 })
            .max(by: { $0.bounds.height < $1.bounds.height }) {
            let originalOffset = scroller.contentOffset
            let maximum = scroller.contentSize.height - scroller.bounds.height + scroller.adjustedContentInset.bottom
            scroller.setContentOffset(CGPoint(x: originalOffset.x, y: min(maximum, originalOffset.y + 180)), animated: false)
            controller.view.layoutIfNeeded()
            capture(window, named: "\(name)-scrolled", controller: controller)
            scroller.setContentOffset(originalOffset, animated: false)
        }
        XCTAssertEqual(app.activeUsername, initialUsername)
    }

    private func capture(_ window: UIWindow, named name: String, controller: UIViewController) {
        let size = window.bounds.size
        let pose = "\(Int(size.width))x\(Int(size.height))-\(window.traitCollection.horizontalSizeClass.rawValue)"
        let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: screenshot)
        attachment.name = "duo-\(pose)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("DUO_DIALOG_CAPTURE \(pose) \(name) \(type(of: controller))")
    }

    private func waitForTextField(in controller: UIViewController) async throws -> UITextField {
        try await waitUntil("Add Site must expose its editable input") {
            self.allViews(in: controller.view).contains { $0 is UITextField && !$0.isHidden }
        }
        return try XCTUnwrap(allViews(in: controller.view).compactMap { $0 as? UITextField }.first { !$0.isHidden })
    }

    @objc private func keyboardDidChange(_ notification: Notification) {
        keyboardFrameInScreen = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
    }

    private func visibleKeyboardFrame(in window: UIWindow) -> CGRect {
        guard let keyboardFrameInScreen else { return .zero }
        // DuoPresentationTests.swift measures the actual system keyboard, independent of a window-level layout guide.
        let frame = window.convert(keyboardFrameInScreen, from: window.screen.coordinateSpace)
        let visible = frame.intersection(window.bounds)
        return visible.isNull ? .zero : visible
    }

    private func activeTextField(in controller: UIViewController) -> UITextField? {
        allViews(in: controller.view).compactMap { $0 as? UITextField }.first { $0.isFirstResponder && $0.window != nil }
    }

    private func isVisible(_ controller: UIViewController) -> Bool {
        guard let view = controller.viewIfLoaded else { return false }
        let visible = visibleViewport(of: view)
        guard visible.width > 150, visible.height > 80 else { return false }
        if let navigation = controller.navigationController, let current = navigation.visibleViewController {
            var ancestor: UIViewController? = controller
            while let candidate = ancestor {
                if candidate === current { return true }
                ancestor = candidate.parent
            }
            return false
        }
        return true
    }

    private func visibleViewport(of view: UIView) -> CGRect {
        guard let window = view.window, !window.isHidden else { return .zero }
        var visible = view.convert(view.bounds, to: window).intersection(window.bounds)
        var ancestor: UIView? = view
        while let candidate = ancestor {
            guard !candidate.isHidden, candidate.alpha > 0.01 else { return .zero }
            if candidate.clipsToBounds {
                visible = visible.intersection(candidate.convert(candidate.bounds, to: window))
            }
            ancestor = candidate.superview
        }
        return visible.isNull ? .zero : visible
    }

    private func waitForPresentation(_ app: NewsBlurAppDelegate,
                                     excluding previous: UIViewController? = nil) async throws -> UIViewController {
        try await waitUntil("Expected dialog must be presented") {
            guard let dialog = self.presentedController(in: app.window?.rootViewController) else { return false }
            return dialog !== previous && dialog.viewIfLoaded?.window != nil && !dialog.isBeingDismissed
        }
        let dialog = try XCTUnwrap(presentedController(in: app.window?.rootViewController))
        try await settle(dialog)
        return dialog
    }

    private func settle(_ controller: UIViewController) async throws {
        var previousFrame = CGRect.null
        var stableSamples = 0
        try await waitUntil("\(type(of: controller)) must finish presentation and layout") {
            guard let view = controller.viewIfLoaded, let window = view.window,
                  !controller.isBeingPresented, !controller.isBeingDismissed,
                  controller.transitionCoordinator == nil else { return false }
            window.layoutIfNeeded()
            let frame = view.convert(view.bounds, to: window)
            stableSamples = frame == previousFrame && !frame.isEmpty ? stableSamples + 1 : 0
            previousFrame = frame
            return stableSamples >= 2
        }
    }

    private func settleFeedList(_ feeds: FeedsViewController, app: NewsBlurAppDelegate) async throws {
        let table = try XCTUnwrap(feeds.feedTitlesTable)
        var previousState = ""
        var stableSamples = 0
        try await waitUntil("Feed filters, rows, and theme must finish updating") {
            guard feeds.navigationController?.topViewController === feeds,
                  feeds.navigationController?.transitionCoordinator == nil,
                  !table.hasUncommittedUpdates, !table.isTracking, !table.isDecelerating else { return false }
            feeds.view.layoutIfNeeded()
            let feedViews = self.allViews(in: feeds.view)
            let hasVisibleHUD = feedViews.contains {
                String(describing: type(of: $0)).contains("MBProgressHUD") && !$0.isHidden && $0.alpha > 0.01
            }
            let hasRowAnimations = self.allViews(in: table).contains {
                !$0.isHidden && $0.alpha > 0.01 && !($0.layer.animationKeys() ?? []).isEmpty
            }
            guard !hasVisibleHUD, !hasRowAnimations else {
                stableSamples = 0
                return false
            }
            // DuoPresentationTests.swift waits on stable live content, not a fixed delay after each filter action.
            let rows = (0..<table.numberOfSections).map { table.numberOfRows(inSection: $0) }
            let cells = table.visibleCells.map { "\($0.frame)-\($0.textLabel?.text ?? "")" }
            let state = "\(app.dictFeeds.count)-\(rows)-\(cells)-\(table.contentSize)-\(table.contentOffset)-\(feeds.view.bounds)"
            stableSamples = state == previousState ? stableSamples + 1 : 0
            previousState = state
            return stableSamples >= 4
        }
    }

    private func waitUntil(_ message: String, timeout: TimeInterval = 10,
                           condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline {
                if let window = liveApp?.window, let root = window.rootViewController {
                    let controller = presentedController(in: root) ?? root
                    capture(window, named: "timeout-\(slug(message))", controller: controller)
                    let textFields = allViews(in: controller.view).compactMap { $0 as? UITextField }.map {
                        "\(type(of: $0)) firstResponder=\($0.isFirstResponder) frame=\($0.convert($0.bounds, to: window))"
                    }
                    let textViews = allViews(in: controller.view).compactMap { $0 as? UITextView }.map {
                        "\(type(of: $0)) firstResponder=\($0.isFirstResponder) editable=\($0.isEditable) frame=\($0.convert($0.bounds, to: window))"
                    }
                    let storyState: String
                    if let stories = liveApp?.feedDetailViewController {
                        storyState = journeyListDiagnostics(stories)
                    } else {
                        storyState = "No live story list"
                    }
                    let geometry = "\(message)\nkeyboard=\(visibleKeyboardFrame(in: window))\nwindowGuide=\(window.keyboardLayoutGuide.layoutFrame)\ntextFields=\(textFields)\ntextViews=\(textViews)\ncontrollers=\(controllerGeometry(root))\nstories=\(storyState)"
                    let attachment = XCTAttachment(string: geometry)
                    attachment.name = "timeout-geometry"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                    print("DUO_TIMEOUT_GEOMETRY \(geometry)")
                }
                XCTFail(message)
                throw AuditError.timedOut(message)
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private func dismissPresentations(_ app: NewsBlurAppDelegate) async {
        app.window?.endEditing(true)
        for _ in 0..<8 {
            guard let dialog = presentedController(in: app.window?.rootViewController) else { break }
            await withCheckedContinuation { continuation in
                dialog.dismiss(animated: false) { continuation.resume() }
            }
        }
    }

    private func presentedController(in root: UIViewController?) -> UIViewController? {
        guard let root else { return nil }
        if let presented = root.presentedViewController {
            return presentedController(in: presented) ?? presented
        }
        for child in root.children.reversed() {
            if let presented = presentedController(in: child) { return presented }
        }
        return nil
    }

    private func descendant<T: UIViewController>(of type: T.Type, in root: UIViewController) -> T? {
        if let match = root as? T { return match }
        for child in root.children {
            if let match = descendant(of: type, in: child) { return match }
        }
        return nil
    }

    private func descendant(named name: String, in root: UIViewController) -> UIViewController? {
        if String(describing: type(of: root)) == name { return root }
        for child in root.children {
            if let match = descendant(named: name, in: child) { return match }
        }
        return nil
    }

    private func allViews(in root: UIView) -> [UIView] {
        [root] + root.subviews.flatMap { allViews(in: $0) }
    }

    private func controllerGeometry(_ controller: UIViewController) -> [String] {
        let viewport = controller.viewIfLoaded.map { visibleViewport(of: $0) } ?? .zero
        var current = "\(type(of: controller)) viewport=\(viewport)"
        if let navigation = controller as? UINavigationController {
            current += " top=\(String(describing: navigation.topViewController.map { type(of: $0) }))"
        }
        var children = controller.children
        if let presented = controller.presentedViewController { children.append(presented) }
        return [current] + children.flatMap { controllerGeometry($0) }
    }

    private func slug(_ title: String) -> String {
        title.lowercased().replacingOccurrences(of: " ", with: "-")
    }

    private enum AuditError: Error {
        case timedOut(String)
        case insufficientJourneyContent(String)
        case missingRoute(String)
    }
}
