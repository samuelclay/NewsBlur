import XCTest
import WebKit

@testable import NewsBlur

@available(iOS 15.0, *)
@MainActor
final class AddSiteSheetViewControllerTests: XCTestCase {
    func test_loadingViewEmbedsSwiftUIContent() {
        let controller = AddSiteSheetViewController()

        controller.loadViewIfNeeded()

        XCTAssertEqual(controller.children.count, 1)
        XCTAssertEqual(controller.view.subviews.count, 1)
        XCTAssertTrue(controller.children.first?.view.isDescendant(of: controller.view) == true)
    }

    func test_initialFeedAddressSeedsViewModel() throws {
        let controller = AddSiteSheetViewController()
        controller.initialFeedAddress = "https://example.com/feed"

        controller.loadViewIfNeeded()

        let viewModel = try XCTUnwrap(extractViewModel(from: controller))
        XCTAssertEqual(viewModel.searchText, "https://example.com/feed")
    }

    private func extractViewModel(from controller: AddSiteSheetViewController) -> AddSiteViewModel? {
        guard let optionalViewModel = Mirror(reflecting: controller).descendant("viewModel") else {
            return nil
        }

        let mirror = Mirror(reflecting: optionalViewModel)
        return mirror.children.first?.value as? AddSiteViewModel
    }
}

@available(iOS 15.0, *)
@MainActor
final class DetailViewControllerTests: XCTestCase {
    func test_collapseToSingleColumnDoesNotRequireLoadedView() throws {
        let detailController = try XCTUnwrap(
            UIStoryboard(name: "MainInterface", bundle: nil)
                .instantiateViewController(withIdentifier: "DetailViewController") as? DetailViewController
        )

        XCTAssertFalse(detailController.isViewLoaded)

        detailController.collapseToSingleColumn()

        XCTAssertFalse(detailController.isViewLoaded)
    }

    func test_showSecondaryInCompactRemovesStaleStoryPagesWhenNoStoryIsSelected() {
        let appDelegate = NewsBlurAppDelegate()
        let storiesCollection = StoriesCollection()
        storiesCollection.activeFeed = ["id": 1, "feed_title": "Test Feed"]
        appDelegate.storiesCollection = storiesCollection
        appDelegate.activeStory = nil

        let detailController = DetailViewController()
        detailController.appDelegate = appDelegate
        detailController.isCompact = true
        appDelegate.detailViewController = detailController

        let feedsViewController = FeedsViewController()
        let feedDetailViewController = FeedDetailViewController()
        let storyPagesViewController = StoryPagesViewController()
        feedDetailViewController.appDelegate = appDelegate
        storyPagesViewController.appDelegate = appDelegate
        storyPagesViewController.loadViewIfNeeded()
        storyPagesViewController.currentPage.clearStory()
        storyPagesViewController.currentPage.view.isHidden = true

        detailController.feedDetailViewController = feedDetailViewController
        detailController.storyPagesViewController = storyPagesViewController

        let navigationController = UINavigationController()
        appDelegate.feedsNavigationController = navigationController
        appDelegate.feedsViewController = feedsViewController
        navigationController.setViewControllers(
            [feedsViewController, feedDetailViewController, storyPagesViewController],
            animated: false
        )

        detailController.show(column: .secondary, animated: false)

        XCTAssertEqual(navigationController.viewControllers.count, 2)
        XCTAssertTrue(navigationController.viewControllers[0] === feedsViewController)
        XCTAssertTrue(navigationController.viewControllers[1] === feedDetailViewController)
    }

    func test_appDelegateUpdatesCompactFeedDetailTitleItem() {
        let appDelegate = NewsBlurAppDelegate()
        let storiesCollection = StoriesCollection()
        storiesCollection.activeFeed = ["id": 1, "feed_title": "Test Feed"]
        appDelegate.storiesCollection = storiesCollection

        let detailController = DetailViewController()
        let feedDetailViewController = FeedDetailViewController()
        detailController.appDelegate = appDelegate
        detailController.feedDetailViewController = feedDetailViewController
        feedDetailViewController.appDelegate = appDelegate
        appDelegate.detailViewController = detailController

        appDelegate.perform(Selector(("updateFeedDetailTitleView")))

        XCTAssertNotNil(detailController.navigationItem.titleView)
        XCTAssertNotNil(feedDetailViewController.navigationItem.titleView)
    }

    func test_resetFeedDetailClearsVisibleStoryRowsImmediately() throws {
        let appDelegate = NewsBlurAppDelegate()
        let storiesCollection = StoriesCollection()
        storiesCollection.appDelegate = appDelegate
        storiesCollection.activeFeed = ["id": 1, "feed_title": "Test Feed"]
        appDelegate.storiesCollection = storiesCollection
        appDelegate.unreadStoryHashes = NSMutableDictionary()
        appDelegate.recentlyReadStories = NSMutableDictionary()

        let detailController = DetailViewController()
        detailController.appDelegate = appDelegate
        detailController.isCompact = true
        appDelegate.detailViewController = detailController

        let storyPagesViewController = StoryPagesViewController()
        storyPagesViewController.appDelegate = appDelegate
        storyPagesViewController.loadViewIfNeeded()
        detailController.storyPagesViewController = storyPagesViewController

        let feedDetailViewController = try XCTUnwrap(
            UIStoryboard(name: "MainInterface", bundle: nil)
                .instantiateViewController(withIdentifier: "FeedDetailViewController") as? FeedDetailViewController
        )
        feedDetailViewController.appDelegate = appDelegate
        feedDetailViewController.storiesCollection = storiesCollection
        detailController.feedDetailViewController = feedDetailViewController
        feedDetailViewController.loadViewIfNeeded()
        feedDetailViewController.messageView.isHidden = true

        storiesCollection.setStories([
            [
                "story_hash": "old:story",
                "story_title": "Old story",
                "read_status": 0,
                "intelligence": [:],
            ],
        ])
        feedDetailViewController.reloadImmediately()
        XCTAssertGreaterThan(feedDetailViewController.storyTitlesTable.numberOfRows(inSection: 0), 1)

        feedDetailViewController.resetFeedDetail()

        XCTAssertLessThanOrEqual(feedDetailViewController.storyTitlesTable.numberOfRows(inSection: 0), 1)
    }
}

@available(iOS 15.0, *)
@MainActor
final class StoryPagesViewControllerTests: XCTestCase {
    private let defaults = UserDefaults.standard
    private let horizontalPagingKey = "scroll_stories_horizontally"
    private var savedHorizontalPagingValue: Any?

    override func setUp() {
        super.setUp()

        savedHorizontalPagingValue = defaults.object(forKey: horizontalPagingKey)
        defaults.set(true, forKey: horizontalPagingKey)
    }

    override func tearDown() {
        defaults.removeObject(forKey: horizontalPagingKey)
        if let savedHorizontalPagingValue {
            defaults.set(savedHorizontalPagingValue, forKey: horizontalPagingKey)
        }

        savedHorizontalPagingValue = nil
        super.tearDown()
    }

    func test_setStoryFromScrollRefreshesVisiblePageChromeAfterPageSwap() {
        let appDelegate = NewsBlurAppDelegate()
        let storiesCollection = StoriesCollection()
        storiesCollection.storyLocationsCount = 3
        appDelegate.storiesCollection = storiesCollection

        let controller = StoryPagesObjCViewController()
        controller.appDelegate = appDelegate
        controller.scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        controller.scrollView.contentSize = CGSize(width: 300, height: 100)

        let previousPage = GradientSpyStoryDetailViewController(pageIndex: -1)
        let currentPage = GradientSpyStoryDetailViewController(pageIndex: 0)
        let nextPage = GradientSpyStoryDetailViewController(pageIndex: 1)

        [currentPage, nextPage, previousPage].forEach { controller.scrollView.addSubview($0.view) }
        controller.currentPage = currentPage
        controller.nextPage = nextPage
        controller.previousPage = previousPage
        controller.scrollingToPage = 2
        controller.scrollView.contentOffset = CGPoint(x: 60, y: 0)

        controller.setStoryFromScroll()

        XCTAssertTrue(controller.currentPage === nextPage)
        XCTAssertTrue(controller.scrollView.subviews.last === nextPage.view)
        XCTAssertEqual(nextPage.drawFeedGradientCallCount, 1)
    }

    func test_resetPagesClearsStalePageStories() {
        let appDelegate = NewsBlurAppDelegate()
        let detailController = DetailViewController()
        let controller = StoryPagesViewController()

        appDelegate.detailViewController = detailController
        detailController.appDelegate = appDelegate
        detailController.storyPagesViewController = controller
        controller.appDelegate = appDelegate
        controller.loadViewIfNeeded()

        let staleStory: NSMutableDictionary = ["story_hash": "stale:story"]
        controller.currentPage.activeStory = staleStory
        controller.nextPage.activeStory = staleStory
        controller.previousPage.activeStory = staleStory

        controller.resetPages()

        XCTAssertNil(controller.currentPage.activeStory)
        XCTAssertNil(controller.currentPage.activeStoryId)
        XCTAssertNil(controller.nextPage.activeStory)
        XCTAssertNil(controller.nextPage.activeStoryId)
        XCTAssertNil(controller.previousPage.activeStory)
        XCTAssertNil(controller.previousPage.activeStoryId)
    }
}

@available(iOS 15.0, *)
@MainActor
private final class GradientSpyStoryDetailViewController: StoryDetailViewController {
    private(set) var drawFeedGradientCallCount = 0

    init(pageIndex: Int) {
        super.init(nibName: nil, bundle: nil)
        self.pageIndex = pageIndex
        loadViewIfNeeded()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let rootView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let webView = WKWebView(frame: rootView.bounds)
        rootView.addSubview(webView)

        view = rootView
        self.webView = webView
        noStoryMessage = UIView(frame: .zero)
    }

    override func drawFeedGradient() {
        drawFeedGradientCallCount += 1
    }

    override func becomeFirstResponder() -> Bool {
        true
    }
}
