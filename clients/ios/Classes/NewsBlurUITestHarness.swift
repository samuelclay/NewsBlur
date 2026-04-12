//
//  NewsBlurUITestHarness.swift
//  NewsBlur
//
//  Created by Codex on 2026-04-05.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import Foundation
import UIKit

@available(iOS 16.0, *)
@MainActor
final class NewsBlurUITestHarness {
    private enum LaunchArgument {
        static let enabled = "-newsblur-ui-testing"
        static let screen = "-newsblur-ui-test-screen"
    }

    private enum ReaderScenario {
        case list
        case techFolder
        case cultureFolder
        case swiftFeed
        case swiftStoryOne
        case swiftClusterFeed
        case swiftClusterStoryOne
    }

    private static var didPrepareLaunchEnvironment = false
    private static var didScheduleScenario = false
    private static var didLoadFeedFixture = false

    static func prepareLaunchEnvironmentIfNeeded(appDelegate: NewsBlurAppDelegate) {
        guard isEnabled, !didPrepareLaunchEnvironment else { return }

        didPrepareLaunchEnvironment = true
        UIView.setAnimationsEnabled(false)

        switch requestedScreen {
        case "add-site":
            installReaderFixtureNetwork(on: appDelegate)
            ReaderUITestFixtures.prepareAppState(for: appDelegate)
            appDelegate.replaceUnreadCounts(forTesting: ReaderUITestFixtures.unreadCountRows())
        case "preferences":
            installReaderFixtureNetwork(on: appDelegate)
            ReaderUITestFixtures.prepareAppState(for: appDelegate)
            appDelegate.replaceUnreadCounts(forTesting: ReaderUITestFixtures.unreadCountRows())
        case let screen? where readerScenario(for: screen) != nil:
            installReaderFixtureNetwork(on: appDelegate)
            ReaderUITestFixtures.prepareAppState(for: appDelegate)
            appDelegate.replaceUnreadCounts(forTesting: ReaderUITestFixtures.unreadCountRows())
        default:
            break
        }
    }

    static func configureIfNeeded(appDelegate: NewsBlurAppDelegate) {
        guard isEnabled, !didScheduleScenario else { return }

        UIView.setAnimationsEnabled(false)

        switch requestedScreen {
        case "add-site":
            didScheduleScenario = true
            AddSiteSheetViewController.viewModelFactory = { makeAddSiteViewModel() }
            configureAddSite(on: appDelegate, remainingRetries: 20)
        case "preferences":
            didScheduleScenario = true
            configurePreferences(on: appDelegate, remainingRetries: 20)
        case let screen? where readerScenario(for: screen) != nil:
            didScheduleScenario = true
            configureReader(
                on: appDelegate,
                scenario: readerScenario(for: screen) ?? .list,
                remainingRetries: 20
            )
        default:
            break
        }
    }

    private static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(LaunchArgument.enabled)
    }

    private static var requestedScreen: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: LaunchArgument.screen) else { return nil }

        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else { return nil }

        return arguments[valueIndex]
    }

    private static func presentAddSite(on appDelegate: NewsBlurAppDelegate, remainingRetries: Int) {
        guard remainingRetries > 0 else { return }
        guard let feedsNavigationController = appDelegate.feedsNavigationController else { return }
        guard feedsNavigationController.viewIfLoaded?.window != nil else {
            retryPresentingAddSite(on: appDelegate, remainingRetries: remainingRetries)
            return
        }
        guard feedsNavigationController.presentedViewController == nil else {
            retryPresentingAddSite(on: appDelegate, remainingRetries: remainingRetries)
            return
        }

        let addSiteViewController = AddSiteSheetViewController()
        addSiteViewController.shouldReloadFeedsOnSuccess = false

        let navigationController = UINavigationController(rootViewController: addSiteViewController)
        navigationController.modalPresentationStyle = .pageSheet
        navigationController.navigationBar.isHidden = true

        if let sheet = navigationController.sheetPresentationController {
            let smallDetent = UISheetPresentationController.Detent.custom(identifier: .init("addSiteSmall")) { _ in
                200.0
            }
            sheet.detents = [smallDetent, .medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            sheet.preferredCornerRadius = 12.0
            addSiteViewController.setSheetController(sheet)
        }

        feedsNavigationController.present(navigationController, animated: false)
    }

    private static func configureAddSite(on appDelegate: NewsBlurAppDelegate, remainingRetries: Int) {
        guard remainingRetries > 0 else { return }
        guard let feedsNavigationController = appDelegate.feedsNavigationController else { return }
        guard feedsNavigationController.viewIfLoaded?.window != nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                configureAddSite(on: appDelegate, remainingRetries: remainingRetries - 1)
            }
            return
        }

        if let presentedViewController = feedsNavigationController.presentedViewController {
            presentedViewController.dismiss(animated: false) {
                configureAddSite(on: appDelegate, remainingRetries: remainingRetries - 1)
            }
            return
        }

        loadFixtureFeedList(on: appDelegate)
        presentAddSite(on: appDelegate, remainingRetries: remainingRetries)
    }

    private static func retryPresentingAddSite(on appDelegate: NewsBlurAppDelegate, remainingRetries: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            presentAddSite(on: appDelegate, remainingRetries: remainingRetries - 1)
        }
    }

    private static func configurePreferences(on appDelegate: NewsBlurAppDelegate, remainingRetries: Int) {
        guard remainingRetries > 0 else { return }
        guard let feedsNavigationController = appDelegate.feedsNavigationController else { return }
        guard feedsNavigationController.viewIfLoaded?.window != nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                configurePreferences(on: appDelegate, remainingRetries: remainingRetries - 1)
            }
            return
        }

        if let presentedViewController = feedsNavigationController.presentedViewController {
            presentedViewController.dismiss(animated: false) {
                configurePreferences(on: appDelegate, remainingRetries: remainingRetries - 1)
            }
            return
        }

        loadFixtureFeedList(on: appDelegate)
        DispatchQueue.main.async {
            appDelegate.showPreferences()
        }
    }

    private static func configureReader(
        on appDelegate: NewsBlurAppDelegate,
        scenario: ReaderScenario,
        remainingRetries: Int
    ) {
        guard remainingRetries > 0 else { return }
        guard let feedsNavigationController = appDelegate.feedsNavigationController else { return }
        guard feedsNavigationController.viewIfLoaded?.window != nil else {
            retryConfiguringReader(on: appDelegate, scenario: scenario, remainingRetries: remainingRetries)
            return
        }

        if let presentedViewController = feedsNavigationController.presentedViewController {
            presentedViewController.dismiss(animated: false) {
                configureReader(on: appDelegate, scenario: scenario, remainingRetries: remainingRetries - 1)
            }
            return
        }

        loadFixtureFeedList(on: appDelegate)
        applyReaderScenario(scenario, on: appDelegate, remainingRetries: remainingRetries)
    }

    private static func retryConfiguringReader(
        on appDelegate: NewsBlurAppDelegate,
        scenario: ReaderScenario,
        remainingRetries: Int
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            configureReader(on: appDelegate, scenario: scenario, remainingRetries: remainingRetries - 1)
        }
    }

    private static func loadFixtureFeedList(on appDelegate: NewsBlurAppDelegate) {
        guard !didLoadFeedFixture else { return }
        guard let feedsViewController = appDelegate.feedsViewController else { return }
        didLoadFeedFixture = true

        installReaderFixtureNetwork(on: appDelegate)
        ReaderUITestFixtures.prepareAppState(for: appDelegate)
        appDelegate.replaceUnreadCounts(forTesting: ReaderUITestFixtures.unreadCountRows())
        feedsViewController.loadViewIfNeeded()
        appDelegate.feedsNavigationController.loadViewIfNeeded()
        appDelegate.feedsNavigationController.view.layoutIfNeeded()

        DispatchQueue.main.async {
            if appDelegate.dictFeeds == nil {
                feedsViewController.fetchFeedList(false)
            } else {
                feedsViewController.reloadFeedTitlesTable()
                feedsViewController.refreshHeaderCounts()
            }
            feedsViewController.view.layoutIfNeeded()
        }
    }

    private static func installReaderFixtureNetwork(on appDelegate: NewsBlurAppDelegate) {
        ReaderUITestURLProtocol.installIfNeeded()
        appDelegate.setCustomDomainForTesting(ReaderUITestFixtures.baseURL.absoluteString)
        appDelegate.setNetworkProtocolClassesForTesting([ReaderUITestURLProtocol.self])
        appDelegate.resetNetworkManagerForTesting()
    }

    private static func applyReaderScenario(
        _ scenario: ReaderScenario,
        on appDelegate: NewsBlurAppDelegate,
        remainingRetries: Int
    ) {
        guard remainingRetries > 0 else { return }
        guard appDelegate.dictFeeds != nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                applyReaderScenario(scenario, on: appDelegate, remainingRetries: remainingRetries - 1)
            }
            return
        }

        switch scenario {
        case .list:
            return
        case .techFolder:
            appDelegate.feedsViewController.selectFolder("Tech")
        case .cultureFolder:
            appDelegate.feedsViewController.selectFolder("Culture")
        case .swiftFeed:
            appDelegate.feedsViewController.selectFeed(ReaderUITestFixtures.swiftFeedId, inFolder: "Tech ▸ Swift")
        case .swiftStoryOne:
            appDelegate.loadFeed(ReaderUITestFixtures.swiftFeedId, withStory: "ui-story-swift-1", animated: false)
        case .swiftClusterFeed:
            appDelegate.loadFeed(ReaderUITestFixtures.swiftClusterFeedId, withStory: nil, animated: false)
        case .swiftClusterStoryOne:
            appDelegate.loadFeed(
                ReaderUITestFixtures.swiftClusterFeedId,
                withStory: ReaderUITestFixtures.swiftClusterPrimaryStoryHash,
                animated: false
            )
        }
    }

    private static func readerScenario(for screen: String) -> ReaderScenario? {
        switch screen {
        case "reader":
            return .list
        case "reader-folder-tech":
            return .techFolder
        case "reader-folder-culture":
            return .cultureFolder
        case "reader-feed-swift":
            return .swiftFeed
        case "reader-story-swift-1":
            return .swiftStoryOne
        case "reader-feed-swift-cluster":
            return .swiftClusterFeed
        case "reader-story-swift-cluster-1":
            return .swiftClusterStoryOne
        default:
            return nil
        }
    }

    private static func makeAddSiteViewModel() -> AddSiteViewModel {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AddSiteUITestURLProtocol.self]

        return AddSiteViewModel(
            appEnvironment: AddSiteUITestEnvironment(),
            session: URLSession(configuration: configuration)
        )
    }
}

private enum ReaderUITestFixtures {
    static let baseURL = URL(string: "https://ui-test.newsblur.example")!

    static let techFeedId = "910001"
    static let swiftFeedId = "910002"
    static let cultureFeedId = "910003"
    static let swiftClusterFeedId = "910004"
    static let swiftClusterPrimaryStoryHash = "ui-story-swift-cluster-1"
    static let swiftClusterMatchStoryHash = "ui-story-swift-cluster-match"
    static let swiftClusterRelatedStoryHash = "ui-story-swift-cluster-related"

    static func prepareAppState(for appDelegate: NewsBlurAppDelegate) {
        let defaults = UserDefaults.standard

        [
            "folderCollapsed:everything",
            "folderCollapsed:Tech",
            "folderCollapsed:Tech ▸ Swift",
            "folderCollapsed:Culture",
        ].forEach { defaults.removeObject(forKey: $0) }

        defaults.set("feeds", forKey: "app_opening")
        defaults.set("title", forKey: "feed_list_sort_order")
        defaults.set(false, forKey: "show_infrequent_site_stories")
        defaults.set(false, forKey: "show_global_shared_stories")
        defaults.set(true, forKey: "story_clustering")
        defaults.set("related", forKey: "cluster_mode")

        appDelegate.pendingFolder = nil
        appDelegate.pendingDailyBriefingStoryHash = nil
        appDelegate.tryFeedFeedId = nil
        appDelegate.tryFeedStoryId = nil
        appDelegate.tryFeedStoryTitle = nil
        appDelegate.inFindingStoryMode = false
        appDelegate.activeStory = nil
        appDelegate.selectedIntelligence = 0
        appDelegate.storiesCollection.reset()

        cacheFixtureImages(on: appDelegate)
    }

    static func unreadCountRows() -> [[String: Any]] {
        [
            ["feed_id": techFeedId, "ps": 0, "nt": 2, "ng": 0],
            ["feed_id": swiftFeedId, "ps": 0, "nt": 4, "ng": 0],
            ["feed_id": cultureFeedId, "ps": 0, "nt": 1, "ng": 0],
            ["feed_id": swiftClusterFeedId, "ps": 0, "nt": 3, "ng": 0],
        ]
    }

    static func feedListResponse() -> [String: Any] {
        let response: [String: Any] = [
            "user": "ui-test-user",
            "share_ext_token": "ui-test-token",
            "social_profile": NSNull(),
            "social_services": [:],
            "user_profile": [
                "is_premium": 1,
                "is_archive": 1,
                "is_pro": 0,
                "premium_expire": NSNull(),
                "preferences": [
                    "story_clustering": true,
                    "cluster_mode": "related",
                ],
            ],
            "activities": [],
            "dashboard_rivers": [],
            "social_feeds": [],
            "flat_folders_with_inactive": [
                "Tech": [Int(techFeedId)!],
                "Tech ▸ Swift": [Int(swiftFeedId)!, Int(swiftClusterFeedId)!],
                "Culture": [Int(cultureFeedId)!],
            ],
            "inactive_feeds": [:],
            "feeds": [
                techFeedId: feed(
                    id: techFeedId,
                    title: "Arc News",
                    unreadCount: 2,
                    address: "https://ui-test.newsblur.example/arc.xml"
                ),
                swiftFeedId: feed(
                    id: swiftFeedId,
                    title: "Swift Weekly",
                    unreadCount: 4,
                    address: "https://ui-test.newsblur.example/swift.xml"
                ),
                cultureFeedId: feed(
                    id: cultureFeedId,
                    title: "Design Notes",
                    unreadCount: 1,
                    address: "https://ui-test.newsblur.example/design.xml"
                ),
                swiftClusterFeedId: feed(
                    id: swiftClusterFeedId,
                    title: "Swift Weekly Clustered",
                    unreadCount: 3,
                    address: "https://ui-test.newsblur.example/swift-cluster.xml"
                ),
            ],
            "folder_icons": [:],
            "feed_icons": [:],
            "saved_searches": [],
            "starred_count": 0,
            "starred_counts": [],
        ]

        return response
    }

    static func response(for request: URLRequest) throws -> (HTTPURLResponse, Data) {
        guard let url = request.url else {
            throw URLError(.badURL)
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        let payload: [String: Any]

        if url.path == "/reader/feeds" {
            payload = feedListResponse()
        } else if url.path == "/reader/refresh_feeds" {
            payload = refreshFeedsResponse()
        } else if url.path == "/reader/logout" {
            payload = [
                "code": 1,
            ]
        } else if url.path == "/reader/favicons" {
            payload = faviconsResponse(for: url)
        } else if url.path.hasPrefix("/reader/river_stories") {
            payload = riverStoriesResponse(for: url)
        } else if url.path.hasPrefix("/reader/feed/") {
            let requestedFeedID = feedID(from: url)
            if pageNumber(from: url) == 1, requestedFeedID == swiftFeedId {
                payload = feedStoriesResponse(feedID: swiftFeedId, stories: swiftStoriesPageOne)
            } else if pageNumber(from: url) == 2, requestedFeedID == swiftFeedId {
                payload = feedStoriesResponse(feedID: swiftFeedId, stories: swiftStoriesPageTwo)
            } else if pageNumber(from: url) == 1, requestedFeedID == swiftClusterFeedId {
                payload = feedStoriesResponse(feedID: swiftClusterFeedId, stories: swiftClusterStoriesPageOne)
            } else if pageNumber(from: url) == 1, requestedFeedID == techFeedId {
                payload = feedStoriesResponse(feedID: techFeedId, stories: techStoriesPageOne)
            } else if pageNumber(from: url) == 1, requestedFeedID == cultureFeedId {
                payload = feedStoriesResponse(feedID: cultureFeedId, stories: cultureStoriesPageOne)
            } else {
                payload = feedStoriesResponse(feedID: requestedFeedID, stories: [])
            }
        } else {
            throw URLError(.unsupportedURL)
        }

        return (response, try JSONSerialization.data(withJSONObject: payload))
    }

    private static func refreshFeedsResponse() -> [String: Any] {
        [
            "feeds": [
                techFeedId: unreadCount(ps: 0, nt: 2, ng: 0),
                swiftFeedId: unreadCount(ps: 0, nt: 4, ng: 0),
                cultureFeedId: unreadCount(ps: 0, nt: 1, ng: 0),
                swiftClusterFeedId: unreadCount(ps: 0, nt: 3, ng: 0),
            ],
            "social_feeds": [:],
        ]
    }

    private static func riverStoriesResponse(for url: URL) -> [String: Any] {
        let activeFeeds = Set(URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .filter { $0.name == "f" }
            .compactMap(\.value) ?? [])

        let stories: [[String: Any]]
        if activeFeeds.contains(techFeedId) || activeFeeds.contains(swiftFeedId) {
            stories = [
                swiftStoriesPageOne[0],
                techStoriesPageOne[0],
                swiftStoriesPageOne[1],
                techStoriesPageOne[1],
                swiftStoriesPageOne[2],
            ]
        } else if activeFeeds.contains(cultureFeedId) {
            stories = cultureStoriesPageOne
        } else {
            stories = []
        }

        return [
            "feed_id": "river",
            "stories": stories,
            "classifiers": [:],
            "feed_tags": [],
            "feed_authors": [],
            "user_profiles": [],
        ]
    }

    private static func faviconsResponse(for url: URL) -> [String: Any] {
        let requestedFeedIds = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .filter { $0.name == "feed_ids" }
            .compactMap(\.value)

        let feedIds = requestedFeedIds?.isEmpty == false
            ? requestedFeedIds ?? []
            : [techFeedId, swiftFeedId, cultureFeedId, swiftClusterFeedId]

        return Dictionary(uniqueKeysWithValues: feedIds.map { ($0, NSNull()) })
    }

    private static func feedStoriesResponse(feedID: String?, stories: [[String: Any]]) -> [String: Any] {
        [
            "feed_id": feedID ?? "",
            "stories": stories,
            "classifiers": [:],
            "feed_tags": [],
            "feed_authors": [],
            "user_profiles": [],
        ]
    }

    private static func pageNumber(from url: URL) -> Int {
        let page = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "page" })?
            .value
        return Int(page ?? "1") ?? 1
    }

    private static func feedID(from url: URL) -> String? {
        let components = url.pathComponents
        guard let readerIndex = components.firstIndex(of: "feed"), readerIndex + 1 < components.count else {
            return nil
        }

        return components[readerIndex + 1]
    }

    private static func feed(id: String, title: String, unreadCount: Int, address: String) -> [String: Any] {
        [
            "id": Int(id) ?? 0,
            "feed_title": title,
            "feed_address": address,
            "feed_link": address.replacingOccurrences(of: ".xml", with: ""),
            "active": true,
            "feed_opens": unreadCount,
            "ps": 0,
            "nt": unreadCount,
            "ng": 0,
            "favicon_fade": "707070",
            "favicon_color": "707070",
        ]
    }

    private static func unreadCount(ps: Int, nt: Int, ng: Int) -> [String: Any] {
        [
            "ps": ps,
            "nt": nt,
            "ng": ng,
        ]
    }

    private static func story(
        hash: String,
        feedID: String,
        title: String,
        content: String,
        date: String,
        timestamp: Int,
        author: String,
        clusterStories: [[String: Any]] = [],
        clusterTier: String? = nil,
        score: Int? = nil
    ) -> [String: Any] {
        var story: [String: Any] = [
            "id": hash,
            "story_hash": hash,
            "story_feed_id": Int(feedID) ?? 0,
            "story_title": title,
            "story_content": content,
            "story_permalink": "https://ui-test.newsblur.example/story/\(hash)",
            "story_authors": author,
            "short_parsed_date": date,
            "story_timestamp": timestamp,
            "read_status": 0,
            "starred": false,
            "shared": false,
            "sticky": false,
            "comment_count": 0,
            "public_comments": [],
            "friend_comments": [],
            "shared_by_public": [],
            "shared_by_friends": [],
            "image_urls": [],
            "secure_image_thumbnails": [:],
            "intelligence": [
                "title": 0,
                "title_regex": 0,
                "author": 0,
                "tags": 0,
                "text": 0,
                "text_regex": 0,
                "url": 0,
                "url_regex": 0,
                "prompt": 0,
                "feed": 0,
            ],
        ]

        if !clusterStories.isEmpty {
            story["cluster_stories"] = clusterStories
        }
        if let clusterTier {
            story["cluster_tier"] = clusterTier
        }
        if let score {
            story["score"] = score
        }

        return story
    }

    private static let techStoriesPageOne: [[String: Any]] = [
        story(
            hash: "ui-story-arc-1",
            feedID: techFeedId,
            title: "Arc News Launches a Reader Fixture",
            content: "<p>This article verifies feed loading from a deterministic test fixture.</p>",
            date: "10m",
            timestamp: 1_700_001_010,
            author: "Reader Fixtures"
        ),
        story(
            hash: "ui-story-arc-2",
            feedID: techFeedId,
            title: "Sidebar Selection Still Works",
            content: "<p>This story exists to keep the Tech folder populated with multiple rows.</p>",
            date: "20m",
            timestamp: 1_700_000_950,
            author: "Regression Tests"
        ),
    ]

    private static let swiftStoriesPageOne: [[String: Any]] = [
        story(
            hash: "ui-story-swift-1",
            feedID: swiftFeedId,
            title: "Swift Fixture Story One",
            content: "<p>The first Swift story should open in the detail reader.</p>",
            date: "5m",
            timestamp: 1_700_001_050,
            author: "Swift Weekly"
        ),
        story(
            hash: "ui-story-swift-2",
            feedID: swiftFeedId,
            title: "Swift Fixture Story Two",
            content: "<p>The Next story control should move from story one to story two.</p>",
            date: "8m",
            timestamp: 1_700_001_025,
            author: "Swift Weekly"
        ),
        story(
            hash: "ui-story-swift-3",
            feedID: swiftFeedId,
            title: "Swift Fixture Story Three",
            content: "<p>The Previous story control should be able to navigate back to story two.</p>",
            date: "12m",
            timestamp: 1_700_000_980,
            author: "Swift Weekly"
        ),
    ]

    private static let swiftStoriesPageTwo: [[String: Any]] = [
        story(
            hash: "ui-story-swift-4",
            feedID: swiftFeedId,
            title: "Swift Fixture Story Four",
            content: "<p>Reaching this story proves the reader fetched the next page of results.</p>",
            date: "16m",
            timestamp: 1_700_000_940,
            author: "Swift Weekly"
        ),
    ]

    private static let cultureStoriesPageOne: [[String: Any]] = [
        story(
            hash: "ui-story-culture-1",
            feedID: cultureFeedId,
            title: "Design Notes Keeps Another Folder Alive",
            content: "<p>This story confirms a second folder can coexist in the sidebar fixtures.</p>",
            date: "30m",
            timestamp: 1_700_000_900,
            author: "Design Notes"
        ),
    ]

    private static let swiftClusterStoriesPageOne: [[String: Any]] = [
        story(
            hash: swiftClusterPrimaryStoryHash,
            feedID: swiftClusterFeedId,
            title: "Swift Cluster Fixture Headline",
            content: "<p>This fixture keeps the article short so the bottom story clusters stay visible in a simulator screenshot.</p>",
            date: "3m",
            timestamp: 1_700_001_200,
            author: "Swift Weekly",
            clusterStories: [
                story(
                    hash: swiftClusterMatchStoryHash,
                    feedID: techFeedId,
                    title: "Swift Cluster Fixture Headline",
                    content: "<p>A title match from another feed.</p>",
                    date: "4m",
                    timestamp: 1_700_001_180,
                    author: "Arc News",
                    clusterTier: "title",
                    score: 1
                ),
                story(
                    hash: swiftClusterRelatedStoryHash,
                    feedID: cultureFeedId,
                    title: "Swift Cluster Fixture Related Coverage",
                    content: "<p>A related follow-up from a different feed.</p>",
                    date: "6m",
                    timestamp: 1_700_001_140,
                    author: "Design Notes",
                    clusterTier: "related",
                    score: 0
                ),
            ]
        ),
        story(
            hash: "ui-story-swift-cluster-2",
            feedID: swiftClusterFeedId,
            title: "Second Cluster Fixture Story",
            content: "<p>A plain story to keep the feed layout realistic.</p>",
            date: "9m",
            timestamp: 1_700_001_100,
            author: "Swift Weekly"
        ),
    ]

    private static func cacheFixtureImages(on appDelegate: NewsBlurAppDelegate) {
        let fixtureImages: [(String, UIColor, UIColor)] = [
            (
                swiftClusterMatchStoryHash,
                UIColor(red: 0.42, green: 0.67, blue: 0.53, alpha: 1.0),
                UIColor(red: 0.20, green: 0.30, blue: 0.24, alpha: 1.0)
            ),
            (
                swiftClusterRelatedStoryHash,
                UIColor(red: 0.87, green: 0.69, blue: 0.42, alpha: 1.0),
                UIColor(red: 0.34, green: 0.23, blue: 0.13, alpha: 1.0)
            ),
        ]

        for (hash, primary, secondary) in fixtureImages {
            appDelegate.cacheStoryImage(fixtureImage(primary: primary, secondary: secondary), forStoryHash: hash)
        }
    }

    private static func fixtureImage(primary: UIColor, secondary: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120))
        return renderer.image { context in
            primary.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 120, height: 120))

            secondary.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 70, width: 120, height: 50))

            UIColor(white: 1.0, alpha: 0.18).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 16, y: 18, width: 56, height: 56))
            context.cgContext.fill(CGRect(x: 16, y: 88, width: 88, height: 10))
        }
    }
}

private final class ReaderUITestURLProtocol: URLProtocol {
    private static var isInstalled = false

    static func installIfNeeded() {
        guard !isInstalled else { return }
        _ = URLProtocol.registerClass(ReaderUITestURLProtocol.self)
        isInstalled = true
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == ReaderUITestFixtures.baseURL.host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let (response, data) = try ReaderUITestFixtures.response(for: request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class AddSiteUITestEnvironment: AddSiteViewModelAppEnvironment {
    let url: String? = "https://ui-test.newsblur.example"
    let dictFoldersArray: Any? = [
        "Tech",
        "Tech \u{25B8} Swift"
    ]
}

private final class AddSiteUITestURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let (response, data) = try mockedResponse(for: request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private func mockedResponse(for request: URLRequest) throws -> (HTTPURLResponse, Data) {
        guard let url = request.url else {
            throw URLError(.badURL)
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!

        switch url.path {
        case "/rss_feeds/feed_autocomplete":
            let term = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "term" })?
                .value ?? ""
            let payload: [String: Any] = [
                "term": term,
                "feeds": [
                    [
                        "feed_title": "Swift UI Test Feed",
                        "feed_address": "https://ui-test.newsblur.example/swift.xml",
                        "num_subscribers": 42,
                        "last_story_seconds_ago": 3600
                    ],
                    [
                        "feed_title": "Engineering UI Test Feed",
                        "feed_address": "https://ui-test.newsblur.example/engineering.xml",
                        "num_subscribers": 17,
                        "last_story_seconds_ago": 7200
                    ]
                ]
            ]
            return (response, try JSONSerialization.data(withJSONObject: payload))
        case "/reader/add_url":
            let payload: [String: Any] = ["code": 1]
            return (response, try JSONSerialization.data(withJSONObject: payload))
        default:
            throw URLError(.unsupportedURL)
        }
    }
}
