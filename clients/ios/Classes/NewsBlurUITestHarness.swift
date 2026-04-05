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

    private static var didScheduleScenario = false
    private static var didLoadReaderFixture = false

    static func configureIfNeeded(appDelegate: NewsBlurAppDelegate) {
        guard isEnabled, !didScheduleScenario else { return }

        UIView.setAnimationsEnabled(false)

        switch requestedScreen {
        case "add-site":
            didScheduleScenario = true
            AddSiteSheetViewController.viewModelFactory = { makeAddSiteViewModel() }
            presentAddSite(on: appDelegate, remainingRetries: 20)
        case "reader":
            didScheduleScenario = true
            configureReader(on: appDelegate, remainingRetries: 20)
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

    private static func retryPresentingAddSite(on appDelegate: NewsBlurAppDelegate, remainingRetries: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            presentAddSite(on: appDelegate, remainingRetries: remainingRetries - 1)
        }
    }

    private static func configureReader(on appDelegate: NewsBlurAppDelegate, remainingRetries: Int) {
        guard remainingRetries > 0 else { return }
        guard let feedsNavigationController = appDelegate.feedsNavigationController else { return }
        guard feedsNavigationController.viewIfLoaded?.window != nil else {
            retryConfiguringReader(on: appDelegate, remainingRetries: remainingRetries)
            return
        }

        if let presentedViewController = feedsNavigationController.presentedViewController {
            presentedViewController.dismiss(animated: false) {
                configureReader(on: appDelegate, remainingRetries: remainingRetries - 1)
            }
            return
        }

        guard !didLoadReaderFixture else { return }
        didLoadReaderFixture = true

        ReaderUITestURLProtocol.installIfNeeded()
        appDelegate.url = ReaderUITestFixtures.baseURL.absoluteString
        appDelegate.resetNetworkManagerForTesting()
        ReaderUITestFixtures.prepareAppState(for: appDelegate)
        ReaderUITestFixtures.seedUnreadCounts(for: appDelegate)
        appDelegate.feedsViewController.finishLoadingFeedList(withDict: ReaderUITestFixtures.feedListResponse(), finished: true)
    }

    private static func retryConfiguringReader(on appDelegate: NewsBlurAppDelegate, remainingRetries: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            configureReader(on: appDelegate, remainingRetries: remainingRetries - 1)
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

    static func prepareAppState(for appDelegate: NewsBlurAppDelegate) {
        let defaults = UserDefaults.standard

        [
            "folderCollapsed:Tech",
            "folderCollapsed:Tech ▸ Swift",
            "folderCollapsed:Culture",
        ].forEach { defaults.removeObject(forKey: $0) }

        defaults.set("title", forKey: "feed_list_sort_order")
        defaults.set(false, forKey: "show_infrequent_site_stories")
        defaults.set(false, forKey: "show_global_shared_stories")

        appDelegate.pendingFolder = nil
        appDelegate.pendingDailyBriefingStoryHash = nil
        appDelegate.tryFeedFeedId = nil
        appDelegate.tryFeedStoryId = nil
        appDelegate.tryFeedStoryTitle = nil
        appDelegate.inFindingStoryMode = false
        appDelegate.activeStory = nil
        appDelegate.selectedIntelligence = 0
        appDelegate.storiesCollection.reset()
    }

    static func seedUnreadCounts(for appDelegate: NewsBlurAppDelegate) {
        let unreadRows: [(String, Int, Int, Int)] = [
            (techFeedId, 0, 2, 0),
            (swiftFeedId, 0, 4, 0),
            (cultureFeedId, 0, 1, 0),
        ]

        appDelegate.database.inDatabase { database in
            for row in unreadRows {
                _ = database.executeUpdate("DELETE FROM unread_counts WHERE feed_id = ?", withArgumentsIn: [row.0])
                _ = database.executeUpdate(
                    "INSERT INTO unread_counts (feed_id, ps, nt, ng) VALUES (?, ?, ?, ?)",
                    withArgumentsIn: [row.0, row.1, row.2, row.3]
                )
            }
        }
    }

    static func feedListResponse() -> NSDictionary {
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
            ],
            "activities": [],
            "dashboard_rivers": [],
            "social_feeds": [],
            "flat_folders_with_inactive": [
                "Tech": [Int(techFeedId)!],
                "Tech ▸ Swift": [Int(swiftFeedId)!],
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
            ],
            "folder_icons": [:],
            "feed_icons": [:],
            "saved_searches": [],
            "starred_count": 0,
            "starred_counts": [],
        ]

        return response as NSDictionary
    }

    static func response(for request: URLRequest) throws -> (HTTPURLResponse, Data) {
        guard let url = request.url else {
            throw URLError(.badURL)
        }

        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let payload: [String: Any]

        if url.path == "/reader/river_stories/" {
            payload = riverStoriesResponse(for: url)
        } else if url.path.hasPrefix("/reader/feed/") {
            let requestedFeedID = feedID(from: url)
            if pageNumber(from: url) == 1, requestedFeedID == swiftFeedId {
                payload = feedStoriesResponse(feedID: swiftFeedId, stories: swiftStoriesPageOne)
            } else if pageNumber(from: url) == 2, requestedFeedID == swiftFeedId {
                payload = feedStoriesResponse(feedID: swiftFeedId, stories: swiftStoriesPageTwo)
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

    private static func story(
        hash: String,
        feedID: String,
        title: String,
        content: String,
        date: String,
        timestamp: Int,
        author: String
    ) -> [String: Any] {
        [
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

        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

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
