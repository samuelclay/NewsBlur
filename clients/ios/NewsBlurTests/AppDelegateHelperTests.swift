import XCTest

@testable import NewsBlur

final class AppDelegateHelperTests: XCTestCase {
    private let defaults = UserDefaults.standard
    private let keys = [
        "default_scroll_read_filter",
        "default_mark_read_filter",
        "release",
        "custom_domain",
        "default_feed_read_filter",
        "story_titles_style",
    ]
    private var savedValues: [String: Any] = [:]
    private var bundleID: String { Bundle(for: NewsBlurAppDelegate.self).bundleIdentifier ?? "" }

    /// Read a user-set value from the persistent domain, excluding registered
    /// defaults that Settings.bundle adds at launch. Tests that assert "the
    /// migration did not write" must use this; `defaults.object(forKey:)` also
    /// returns the registered `scroll` default.
    private func userValue(_ key: String) -> Any? {
        return defaults.persistentDomain(forName: bundleID)?[key]
    }

    override func setUp() {
        super.setUp()

        for key in keys {
            if let value = defaults.object(forKey: key) {
                savedValues[key] = value
            }
            defaults.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in keys {
            defaults.removeObject(forKey: key)
            if let value = savedValues[key] {
                defaults.set(value, forKey: key)
            }
        }

        savedValues.removeAll()
        super.tearDown()
    }

    func test_upgradeSettings_migratesLegacyScrollFalseToSelection() {
        defaults.set(false, forKey: "default_scroll_read_filter")

        AppDelegateHelper.shared.upgradeSettings(from: 153)

        XCTAssertEqual(userValue("default_mark_read_filter") as? String, "selection")
    }

    func test_upgradeSettings_migratesLegacyScrollTrueToScroll() {
        defaults.set(true, forKey: "default_scroll_read_filter")

        AppDelegateHelper.shared.upgradeSettings(from: 153)

        XCTAssertEqual(userValue("default_mark_read_filter") as? String, "scroll")
    }

    func test_upgradeSettings_doesNotWriteMarkReadWhenLegacyKeyAbsent() {
        // Fresh install: no old boolean key. Migration must NOT force "selection",
        // which would override the Settings.bundle default of "scroll".
        AppDelegateHelper.shared.upgradeSettings(from: 0)

        XCTAssertNil(userValue("default_mark_read_filter"))
    }

    func test_upgradeSettings_doesNotOverwriteExistingMarkReadValue() {
        defaults.set(true, forKey: "default_scroll_read_filter")
        defaults.set("selection", forKey: "default_mark_read_filter")

        AppDelegateHelper.shared.upgradeSettings(from: 153)

        XCTAssertEqual(userValue("default_mark_read_filter") as? String, "selection")
    }

    func test_upgradeSettings_doesNotMigrateWhenAlreadyPastMigrationRelease() {
        defaults.set(false, forKey: "default_scroll_read_filter")

        AppDelegateHelper.shared.upgradeSettings(from: 154)

        XCTAssertNil(userValue("default_mark_read_filter"))
    }

    func test_applyReleaseUpgrade_readsPreviousReleaseBeforeOverwriting() {
        // Simulate a device that last ran an old build (release 120) and is
        // now launching build 328. The migration must see 120 and run.
        defaults.set(120, forKey: "release")
        defaults.set(false, forKey: "default_scroll_read_filter")

        AppDelegateHelper.shared.applyReleaseUpgrade(currentRelease: 328, defaults: defaults)

        XCTAssertEqual(userValue("default_mark_read_filter") as? String, "selection")
        XCTAssertEqual(defaults.integer(forKey: "release"), 328)
    }

    func test_applyReleaseUpgrade_skipsMigrationWhenStoredReleaseAlreadyPastThreshold() {
        defaults.set(200, forKey: "release")
        defaults.set(false, forKey: "default_scroll_read_filter")

        AppDelegateHelper.shared.applyReleaseUpgrade(currentRelease: 328, defaults: defaults)

        XCTAssertNil(userValue("default_mark_read_filter"))
        XCTAssertEqual(defaults.integer(forKey: "release"), 328)
    }

    func test_appDelegateURL_normalizesCustomDomainToOrigin() {
        defaults.set("  newsblur.local:8443/reader?foo=bar  ", forKey: "custom_domain")

        let appDelegate = NewsBlurAppDelegate()

        XCTAssertEqual(appDelegate.url, "https://newsblur.local:8443")
        XCTAssertEqual(appDelegate.host, "newsblur.local")
    }

    func test_appDelegateURL_fallsBackToDefaultWhenCustomDomainIsInvalid() {
        defaults.removeObject(forKey: "custom_domain")
        let defaultURL = NewsBlurAppDelegate().url

        defaults.set("https://", forKey: "custom_domain")
        let appDelegate = NewsBlurAppDelegate()

        XCTAssertEqual(appDelegate.url, defaultURL)
    }

    func test_setCustomDomainForTesting_doesNotPersistFakeDomainIntoUserDefaults() {
        defaults.removeObject(forKey: "custom_domain")

        let appDelegate = NewsBlurAppDelegate()
        appDelegate.setCustomDomainForTesting("https://ui-test.newsblur.example")

        XCTAssertEqual(appDelegate.url, "https://ui-test.newsblur.example")
        let bundleIdentifier = Bundle(for: NewsBlurAppDelegate.self).bundleIdentifier ?? ""
        let persistedValue = defaults.persistentDomain(forName: bundleIdentifier)?["custom_domain"]
        XCTAssertNil(persistedValue)
    }

    func test_extractFolderName_treatsMissingActiveFolderAsTopLevel() {
        let appDelegate = NewsBlurAppDelegate()

        XCTAssertEqual(appDelegate.extractFolderName(nil), "")
    }

    func test_feedIdsForTopLevelRiverWithReadFilter_unread_usesModelUnreadCountsInsteadOfSidebarVisibility() {
        let appDelegate = NewsBlurAppDelegate()
        let feedsViewController = FeedsViewController()

        appDelegate.feedsViewController = feedsViewController
        appDelegate.selectedIntelligence = 0
        appDelegate.dictFoldersArray = [
            "dashboard",
            "everything",
            "infrequent",
            "Tech",
            "News",
            "saved_stories",
            "read_stories",
        ]
        // dictFolders["everything"] is the iOS-renamed bucket for top-level unfoldered feeds
        // (server's flat_folders_with_inactive[" "]). The river must include them.
        appDelegate.dictFolders = [
            "dashboard": ["dashboard"],
            "everything": [10, 11, 99],
            "infrequent": ["infrequent"],
            "Tech": [1, 2, 4],
            "News": [2, 3, "saved:query"],
            "saved_stories": ["saved:1"],
            "read_stories": ["read_stories"],
        ]
        appDelegate.dictFeeds = [
            "1": ["id": 1],
            "2": ["id": 2],
            "3": ["id": 3],
            "4": ["id": 4],
            "10": ["id": 10],
            "11": ["id": 11],
            "99": ["id": 99, "temp": true],
        ]
        appDelegate.dictUnreadCounts = [
            "1": ["ps": 0, "nt": 1, "ng": 0],
            "2": ["ps": 1, "nt": 0, "ng": 0],
            "3": ["ps": 0, "nt": 0, "ng": 0],
            "4": ["ps": 0, "nt": 1, "ng": 0],
            "10": ["ps": 1, "nt": 0, "ng": 0],
            "11": ["ps": 0, "nt": 0, "ng": 0],
        ]
        appDelegate.dictInactiveFeeds = [
            "4": ["id": 4],
        ]

        feedsViewController.activeFeedLocations = [
            "Tech": [0],
            "News": [0],
        ]
        feedsViewController.viewShowingAllFeeds = false

        let feedIds = ((appDelegate.feedIdsForTopLevelRiver(withReadFilter: "unread") as? [Any]) ?? []).map {
            String(describing: $0)
        }

        XCTAssertEqual(feedIds, ["10", "1", "2"])
    }

    func test_feedIdsForTopLevelRiverWithReadFilter_all_returnsFullSubscribedFeedIds() {
        let appDelegate = NewsBlurAppDelegate()
        let feedsViewController = FeedsViewController()

        appDelegate.feedsViewController = feedsViewController
        appDelegate.dictFoldersArray = [
            "dashboard",
            "everything",
            "infrequent",
            "Tech",
            "News",
        ]
        appDelegate.dictFolders = [
            "dashboard": ["dashboard"],
            "everything": [10, 11],
            "infrequent": ["infrequent"],
            "Tech": [1, 2, 99],
            "News": [2, 3, 4],
        ]
        appDelegate.dictFeeds = [
            "1": ["id": 1],
            "2": ["id": 2],
            "3": ["id": 3],
            "4": ["id": 4],
            "10": ["id": 10],
            "11": ["id": 11],
            "99": ["id": 99, "temp": true],
        ]

        feedsViewController.activeFeedLocations = [
            "Tech": [0],
        ]

        let feedIds = ((appDelegate.feedIdsForTopLevelRiver(withReadFilter: "all") as? [Any]) ?? []).map {
            String(describing: $0)
        }

        XCTAssertEqual(feedIds, ["10", "11", "1", "2", "3", "4"])
    }

    func test_nextUnreadNavigationTitleForFeedUsesUnreadMode() {
        let feedsViewController = makeFeedsViewControllerForNextUnreadNavigation()
        feedsViewController.setValue(NSIndexPath(row: 0, section: 3), forKey: "lastRowAtIndexPath")
        feedsViewController.setValue(-1, forKey: "lastSection")

        XCTAssertEqual(feedsViewController.nextUnreadNavigationKind(), "site")
        XCTAssertEqual(feedsViewController.nextUnreadNavigationTitle(), "Neutral Site")
    }

    func test_nextUnreadNavigationTitleForFeedIncludesNegativeInAllMode() {
        let feedsViewController = makeFeedsViewControllerForNextUnreadNavigation()
        feedsViewController.viewShowingAllFeeds = true
        feedsViewController.setValue(NSIndexPath(row: 0, section: 3), forKey: "lastRowAtIndexPath")
        feedsViewController.setValue(-1, forKey: "lastSection")

        XCTAssertEqual(feedsViewController.nextUnreadNavigationTitle(), "Negative Site")
    }

    func test_nextUnreadNavigationTitleForFeedUsesFocusMode() {
        let feedsViewController = makeFeedsViewControllerForNextUnreadNavigation(selectedIntelligence: 1)
        feedsViewController.setValue(NSIndexPath(row: 0, section: 3), forKey: "lastRowAtIndexPath")
        feedsViewController.setValue(-1, forKey: "lastSection")

        XCTAssertEqual(feedsViewController.nextUnreadNavigationTitle(), "Focus Site")
    }

    func test_nextUnreadNavigationTitleForFolderUsesAdjacentUnreadFolder() {
        let feedsViewController = makeFeedsViewControllerForNextUnreadNavigation()
        feedsViewController.setValue(nil, forKey: "lastRowAtIndexPath")
        feedsViewController.setValue(3, forKey: "lastSection")

        XCTAssertEqual(feedsViewController.nextUnreadNavigationKind(), "folder")
        XCTAssertEqual(feedsViewController.nextUnreadNavigationTitle(), "News")
    }

    func test_returningFromFeedDetailRecalculatesFeedListAfterReadingAcrossFeeds() {
        let feedsViewController = FeedListReturnTrackingViewController()
        _ = makeFeedsViewControllerForNextUnreadNavigation(feedViewController: feedsViewController)
        feedsViewController.calculateFeedLocations()
        feedsViewController.calculateFeedLocationsCount = 0
        feedsViewController.reloadFeedTitlesTableCount = 0
        feedsViewController.appDelegate.inFeedDetail = true
        feedsViewController.currentRowAtIndexPath = IndexPath(row: 0, section: 3)

        feedsViewController.viewWillAppear(false)

        XCTAssertEqual(feedsViewController.calculateFeedLocationsCount, 1)
        XCTAssertEqual(feedsViewController.reloadFeedTitlesTableCount, 1)
    }

    func test_canPullToNextUnreadListWaitsUntilPageFinishedEvenWhenKnownUnreadStoriesAreLoaded() {
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: false,
            activeStoriesCount: 1,
            unreadCounts: ["ps": 0, "nt": 1, "ng": 0]
        )

        XCTAssertFalse(feedDetailViewController.canPullToNextUnreadList())
    }

    func test_canPullToNextUnreadListAfterPageFinished() {
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: true,
            activeStoriesCount: 1,
            unreadCounts: ["ps": 0, "nt": 1, "ng": 0]
        )

        XCTAssertTrue(feedDetailViewController.canPullToNextUnreadList())
    }

    func test_checkScrollContinuesFetchingUntilPageFinishedEvenWhenKnownUnreadStoriesAreLoaded() {
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: false,
            activeStoriesCount: 1,
            unreadCounts: ["ps": 0, "nt": 1, "ng": 0],
            feedDetailViewController: BottomNextFeedPagingViewController()
        ) as! BottomNextFeedPagingViewController
        setBottomScrollPosition(feedDetailViewController)

        feedDetailViewController.checkScroll()

        XCTAssertEqual(feedDetailViewController.fetchedFeedPages, [2])
        XCTAssertTrue(feedDetailViewController.pageFetching)
    }

    func test_checkScrollStillFetchesWhenKnownUnreadStoriesAreNotLoaded() {
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: false,
            activeStoriesCount: 1,
            unreadCounts: ["ps": 0, "nt": 2, "ng": 0],
            feedDetailViewController: BottomNextFeedPagingViewController()
        ) as! BottomNextFeedPagingViewController
        setBottomScrollPosition(feedDetailViewController)

        feedDetailViewController.checkScroll()

        XCTAssertEqual(feedDetailViewController.fetchedFeedPages, [2])
        XCTAssertTrue(feedDetailViewController.pageFetching)
    }

    func test_bottomNextFeedStartsWhenEndRowCrossesScrollReadProbe() throws {
        defaults.set("scroll", forKey: "default_mark_read_filter")
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: true,
            activeStoriesCount: 1,
            unreadCounts: ["ps": 0, "nt": 1, "ng": 0]
        )
        feedDetailViewController.loadViewIfNeeded()
        feedDetailViewController.view.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        feedDetailViewController.storyTitlesTable.frame = feedDetailViewController.view.bounds
        feedDetailViewController.storyTitlesTable.dataSource = feedDetailViewController
        feedDetailViewController.storyTitlesTable.delegate = feedDetailViewController
        feedDetailViewController.storyTitlesTable.reloadData()
        feedDetailViewController.storyTitlesTable.layoutIfNeeded()
        setBottomNextFeedActiveDrag(feedDetailViewController, active: true)

        let endRow = feedDetailViewController.storyTitlesTable.numberOfRows(inSection: 0) - 1
        let endRowTop = feedDetailViewController.storyTitlesTable.rectForRow(at: IndexPath(row: endRow, section: 0)).minY
        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: endRowTop - 59)

        feedDetailViewController.scrollViewDidScroll(feedDetailViewController.storyTitlesTable)

        let control = try XCTUnwrap(feedDetailViewController.value(forKey: "bottomNextFeedControl") as? UIView)
        XCTAssertFalse(control.isHidden)
        XCTAssertTrue(feedDetailViewController.view.bounds.intersects(control.frame))
    }

    func test_bottomNextFeedOpensWhenReleasedWhileActivelyReady() {
        let feedsViewController = BottomNextFeedSelectionViewController()
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: true,
            activeStoriesCount: 1,
            unreadCounts: ["ps": 0, "nt": 1, "ng": 0],
            feedsViewController: feedsViewController
        )
        feedDetailViewController.loadViewIfNeeded()
        feedDetailViewController.view.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        feedDetailViewController.storyTitlesTable.frame = feedDetailViewController.view.bounds
        feedDetailViewController.storyTitlesTable.dataSource = feedDetailViewController
        feedDetailViewController.storyTitlesTable.delegate = feedDetailViewController
        feedDetailViewController.storyTitlesTable.reloadData()
        feedDetailViewController.storyTitlesTable.layoutIfNeeded()

        let endRow = feedDetailViewController.storyTitlesTable.numberOfRows(inSection: 0) - 1
        let endRowTop = feedDetailViewController.storyTitlesTable.rectForRow(at: IndexPath(row: endRow, section: 0)).minY

        feedDetailViewController.scrollViewWillBeginDragging(feedDetailViewController.storyTitlesTable)
        setBottomNextFeedActiveDrag(feedDetailViewController, active: true)
        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: endRowTop + 10)
        feedDetailViewController.scrollViewDidScroll(feedDetailViewController.storyTitlesTable)
        feedDetailViewController.scrollViewDidEndDragging(feedDetailViewController.storyTitlesTable, willDecelerate: false)

        XCTAssertEqual(feedsViewController.selectNextUnreadFolderOrFeedCount, 1)
    }

    func test_bottomNextFeedDoesNotOpenWhenMomentumCrossesThreshold() {
        let feedsViewController = BottomNextFeedSelectionViewController()
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: true,
            activeStoriesCount: 1,
            unreadCounts: ["ps": 0, "nt": 1, "ng": 0],
            feedsViewController: feedsViewController
        )
        feedDetailViewController.loadViewIfNeeded()
        feedDetailViewController.view.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        feedDetailViewController.storyTitlesTable.frame = feedDetailViewController.view.bounds
        feedDetailViewController.storyTitlesTable.dataSource = feedDetailViewController
        feedDetailViewController.storyTitlesTable.delegate = feedDetailViewController
        feedDetailViewController.storyTitlesTable.reloadData()
        feedDetailViewController.storyTitlesTable.layoutIfNeeded()

        let endRow = feedDetailViewController.storyTitlesTable.numberOfRows(inSection: 0) - 1
        let endRowTop = feedDetailViewController.storyTitlesTable.rectForRow(at: IndexPath(row: endRow, section: 0)).minY

        feedDetailViewController.scrollViewWillBeginDragging(feedDetailViewController.storyTitlesTable)
        setBottomNextFeedActiveDrag(feedDetailViewController, active: true)
        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: endRowTop - 90)
        feedDetailViewController.scrollViewDidScroll(feedDetailViewController.storyTitlesTable)
        setBottomNextFeedActiveDrag(feedDetailViewController, active: false)
        feedDetailViewController.scrollViewDidEndDragging(feedDetailViewController.storyTitlesTable, willDecelerate: true)
        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: endRowTop + 10)
        feedDetailViewController.scrollViewDidScroll(feedDetailViewController.storyTitlesTable)
        feedDetailViewController.scrollViewDidEndDecelerating(feedDetailViewController.storyTitlesTable)

        XCTAssertEqual(feedsViewController.selectNextUnreadFolderOrFeedCount, 0)
    }

    func test_bottomNextFeedCanBeDisarmedBeforeRelease() {
        let feedsViewController = BottomNextFeedSelectionViewController()
        let feedDetailViewController = makeFeedDetailViewControllerForBottomNextFeed(
            pageFinished: true,
            activeStoriesCount: 1,
            unreadCounts: ["ps": 0, "nt": 1, "ng": 0],
            feedsViewController: feedsViewController
        )
        feedDetailViewController.loadViewIfNeeded()
        feedDetailViewController.view.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        feedDetailViewController.storyTitlesTable.frame = feedDetailViewController.view.bounds
        feedDetailViewController.storyTitlesTable.dataSource = feedDetailViewController
        feedDetailViewController.storyTitlesTable.delegate = feedDetailViewController
        feedDetailViewController.storyTitlesTable.reloadData()
        feedDetailViewController.storyTitlesTable.layoutIfNeeded()

        let endRow = feedDetailViewController.storyTitlesTable.numberOfRows(inSection: 0) - 1
        let endRowTop = feedDetailViewController.storyTitlesTable.rectForRow(at: IndexPath(row: endRow, section: 0)).minY

        feedDetailViewController.scrollViewWillBeginDragging(feedDetailViewController.storyTitlesTable)
        setBottomNextFeedActiveDrag(feedDetailViewController, active: true)
        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: endRowTop + 10)
        feedDetailViewController.scrollViewDidScroll(feedDetailViewController.storyTitlesTable)
        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: endRowTop - 90)
        feedDetailViewController.scrollViewDidScroll(feedDetailViewController.storyTitlesTable)
        feedDetailViewController.scrollViewDidEndDragging(feedDetailViewController.storyTitlesTable, willDecelerate: false)

        XCTAssertEqual(feedsViewController.selectNextUnreadFolderOrFeedCount, 0)
    }

    func test_toggleAuthorClassifierFromStoryDetail_cyclesPositiveNegativeNeutral() {
        let appDelegate = ClassifierToggleAppDelegate()
        appDelegate.storiesCollection = StoriesCollection()
        appDelegate.storiesCollection.activeClassifiers = [
            "1": [
                "authors": [
                    "Jane": 1,
                ],
            ],
        ]

        appDelegate.toggleAuthorClassifier("Jane", feedId: "1")
        XCTAssertEqual(classifierScore(appDelegate, feedId: "1", key: "authors", value: "Jane"), -1)
        XCTAssertEqual(appDelegate.savedClassifierParameters?["dislike_author"] as? String, "Jane")

        appDelegate.toggleAuthorClassifier("Jane", feedId: "1")
        XCTAssertEqual(classifierScore(appDelegate, feedId: "1", key: "authors", value: "Jane"), 0)
        XCTAssertEqual(appDelegate.savedClassifierParameters?["remove_like_author"] as? String, "Jane")

        appDelegate.toggleAuthorClassifier("Jane", feedId: "1")
        XCTAssertEqual(classifierScore(appDelegate, feedId: "1", key: "authors", value: "Jane"), 1)
        XCTAssertEqual(appDelegate.savedClassifierParameters?["like_author"] as? String, "Jane")

        appDelegate.storiesCollection.activeClassifiers = [
            "1": [
                "authors": [
                    "Jane": -2,
                ],
            ],
        ]
        appDelegate.toggleAuthorClassifier("Jane", feedId: "1")
        XCTAssertEqual(classifierScore(appDelegate, feedId: "1", key: "authors", value: "Jane"), 0)
        XCTAssertEqual(appDelegate.savedClassifierParameters?["remove_like_author"] as? String, "Jane")
    }

    func test_toggleTagClassifierFromStoryDetail_cyclesPositiveNegativeNeutral() {
        let appDelegate = ClassifierToggleAppDelegate()
        appDelegate.storiesCollection = StoriesCollection()
        appDelegate.storiesCollection.activeClassifiers = [
            "1": [
                "tags": [
                    "swift": 1,
                ],
            ],
        ]

        appDelegate.toggleTagClassifier("swift", feedId: "1")
        XCTAssertEqual(classifierScore(appDelegate, feedId: "1", key: "tags", value: "swift"), -1)
        XCTAssertEqual(appDelegate.savedClassifierParameters?["dislike_tag"] as? String, "swift")

        appDelegate.toggleTagClassifier("swift", feedId: "1")
        XCTAssertEqual(classifierScore(appDelegate, feedId: "1", key: "tags", value: "swift"), 0)
        XCTAssertEqual(appDelegate.savedClassifierParameters?["remove_like_tag"] as? String, "swift")

        appDelegate.toggleTagClassifier("swift", feedId: "1")
        XCTAssertEqual(classifierScore(appDelegate, feedId: "1", key: "tags", value: "swift"), 1)
        XCTAssertEqual(appDelegate.savedClassifierParameters?["like_tag"] as? String, "swift")

        appDelegate.storiesCollection.activeClassifiers = [
            "1": [
                "tags": [
                    "swift": -2,
                ],
            ],
        ]
        appDelegate.toggleTagClassifier("swift", feedId: "1")
        XCTAssertEqual(classifierScore(appDelegate, feedId: "1", key: "tags", value: "swift"), 0)
        XCTAssertEqual(appDelegate.savedClassifierParameters?["remove_like_tag"] as? String, "swift")
    }

    private func classifierScore(_ appDelegate: NewsBlurAppDelegate, feedId: String, key: String, value: String) -> Int? {
        let feedClassifiers = appDelegate.storiesCollection.activeClassifiers[feedId] as? [String: Any]
        let classifiers = feedClassifiers?[key] as? [String: Any]
        return classifiers?[value] as? Int
    }

    private func makeFeedsViewControllerForNextUnreadNavigation(
        selectedIntelligence: Int = 0,
        feedViewController: FeedsViewController = FeedsViewController()
    ) -> FeedsViewController {
        let appDelegate = NewsBlurAppDelegate()
        let feedsViewController = feedViewController
        let tableView = UITableView(frame: .zero, style: .plain)

        appDelegate.feedsViewController = feedsViewController
        appDelegate.selectedIntelligence = selectedIntelligence
        appDelegate.dictFoldersArray = [
            "dashboard",
            "daily_briefing",
            "infrequent",
            "Tech",
            "News",
        ]
        appDelegate.dictFolders = [
            "dashboard": [],
            "daily_briefing": [],
            "infrequent": [],
            "Tech": [1, 2, 3, 4],
            "News": [5],
        ]
        appDelegate.dictFeeds = [
            "1": ["id": 1, "feed_title": "Current Site", "active": 1],
            "2": ["id": 2, "feed_title": "Negative Site", "active": 1],
            "3": ["id": 3, "feed_title": "Neutral Site", "active": 1],
            "4": ["id": 4, "feed_title": "Focus Site", "active": 1],
            "5": ["id": 5, "feed_title": "News Site", "active": 1],
        ]
        appDelegate.dictUnreadCounts = [
            "1": ["ps": 0, "nt": 1, "ng": 0],
            "2": ["ps": 0, "nt": 0, "ng": 1],
            "3": ["ps": 0, "nt": 1, "ng": 0],
            "4": ["ps": 1, "nt": 0, "ng": 0],
            "5": ["ps": 0, "nt": 1, "ng": 0],
        ]
        appDelegate.dictInactiveFeeds = [:]
        appDelegate.collapsedFolders = [:]
        appDelegate.folderCountCache = nil

        feedsViewController.appDelegate = appDelegate
        feedsViewController.feedTitlesTable = tableView
        feedsViewController.visibleFolders = NSMutableDictionary(dictionary: [
            "Tech": true,
            "News": true,
        ])
        feedsViewController.viewShowingAllFeeds = false
        tableView.dataSource = feedsViewController
        tableView.delegate = feedsViewController
        tableView.reloadData()

        return feedsViewController
    }

    private func makeFeedDetailViewControllerForBottomNextFeed(
        pageFinished: Bool,
        activeStoriesCount: Int,
        unreadCounts: [String: Int],
        feedsViewController: FeedsViewController = FeedsViewController(),
        feedDetailViewController: FeedDetailViewController = FeedDetailViewController()
    ) -> FeedDetailViewController {
        defaults.set("unread", forKey: "default_feed_read_filter")
        defaults.set("standard", forKey: DetailViewController.Key.style)

        let appDelegate = NewsBlurAppDelegate()
        let detailViewController = DetailViewController()
        let storiesCollection = StoriesCollection()

        appDelegate.detailViewController = detailViewController
        appDelegate.feedsViewController = feedsViewController
        appDelegate.storiesCollection = storiesCollection
        appDelegate.dictFeeds = ["1": ["id": 1, "active": 1, "feed_title": "Low Count Site"]]
        appDelegate.dictUnreadCounts = ["1": unreadCounts]
        appDelegate.selectedIntelligence = 0

        detailViewController.appDelegate = appDelegate
        feedsViewController.appDelegate = appDelegate
        feedsViewController.viewShowingAllFeeds = false

        storiesCollection.appDelegate = appDelegate
        storiesCollection.activeFeed = ["id": 1, "active": 1, "feed_title": "Low Count Site"]
        storiesCollection.activeFolder = "Tech"
        storiesCollection.feedPage = 1
        storiesCollection.setStories((0..<activeStoriesCount).map { index in
            [
                "story_hash": "story-\(index)",
                "story_feed_id": 1,
                "read_status": 0,
            ]
        })

        feedDetailViewController.appDelegate = appDelegate
        feedDetailViewController.storiesCollection = storiesCollection
        feedDetailViewController.storyTitlesTable = BottomNextFeedTestTableView(frame: .zero, style: .plain)
        feedDetailViewController.messageView = UIView()
        feedDetailViewController.messageView.isHidden = true
        feedDetailViewController.pageFetching = false
        feedDetailViewController.pageFinished = pageFinished

        return feedDetailViewController
    }

    private func setBottomScrollPosition(_ feedDetailViewController: FeedDetailViewController) {
        feedDetailViewController.storyTitlesTable.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        feedDetailViewController.storyTitlesTable.contentSize = CGSize(width: 320, height: 900)
        feedDetailViewController.storyTitlesTable.contentOffset = CGPoint(x: 0, y: 260)
    }

    private func setBottomNextFeedActiveDrag(_ feedDetailViewController: FeedDetailViewController, active: Bool) {
        let tableView = feedDetailViewController.storyTitlesTable as? BottomNextFeedTestTableView
        tableView?.trackingForTest = active
        tableView?.draggingForTest = active
    }
}

final class ActivityModulesLayoutTests: XCTestCase {
    func test_interactionsModuleReusesTableAcrossLayoutPasses() {
        let module = makeModule(named: "InteractionsModule")

        module.layoutSubviews()
        module.layoutSubviews()

        XCTAssertEqual(module.subviews.compactMap { $0 as? UITableView }.count, 1)
    }

    func test_activityModuleReusesTableAcrossLayoutPasses() {
        let module = makeModule(named: "ActivityModule")

        module.layoutSubviews()
        module.layoutSubviews()

        XCTAssertEqual(module.subviews.compactMap { $0 as? UITableView }.count, 1)
    }

    private func makeModule(named className: String) -> UIView {
        let type = NSClassFromString(className) as? UIView.Type
            ?? NSClassFromString("NewsBlur.\(className)") as? UIView.Type
        guard let type else {
            XCTFail("Missing \(className)")
            return UIView(frame: .zero)
        }

        return type.init(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
    }
}

private final class ClassifierToggleAppDelegate: NewsBlurAppDelegate {
    var savedClassifierParameters: [String: Any]?

    override func post(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error) -> Void)!) {
        savedClassifierParameters = parameters as? [String: Any]
    }

    override func recalculateIntelligenceScores(_ feedId: Any!) {
    }
}

private final class BottomNextFeedPagingViewController: FeedDetailViewController {
    var fetchedFeedPages: [Int32] = []

    override func fetchFeedDetail(_ page: Int32, withCallback callback: (() -> Void)!) {
        fetchedFeedPages.append(page)
        pageFetching = true
        callback?()
    }
}

private final class BottomNextFeedTestTableView: UITableView {
    var trackingForTest = false
    var draggingForTest = false

    override var isTracking: Bool {
        trackingForTest
    }

    override var isDragging: Bool {
        draggingForTest
    }
}

private final class BottomNextFeedSelectionViewController: FeedsViewController {
    var selectNextUnreadFolderOrFeedCount = 0

    override func selectNextUnreadFolderOrFeed() -> Bool {
        selectNextUnreadFolderOrFeedCount += 1
        return true
    }
}

private final class FeedListReturnTrackingViewController: FeedsViewController {
    var calculateFeedLocationsCount = 0
    var reloadFeedTitlesTableCount = 0

    override func calculateFeedLocations() {
        calculateFeedLocationsCount += 1
        super.calculateFeedLocations()
    }

    override func reloadFeedTitlesTable() {
        reloadFeedTitlesTableCount += 1
        super.reloadFeedTitlesTable()
    }
}
