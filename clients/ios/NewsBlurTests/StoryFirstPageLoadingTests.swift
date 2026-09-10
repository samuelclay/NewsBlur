import ObjectiveC.runtime
import UIKit
import WebKit
import XCTest

@testable import NewsBlur

@MainActor final class Test_StoryFirstPageLoading: XCTestCase {
    func test_reopenedFeedShowsCachedRowsBeforeQueuedReadAndSaveFlushesFinish() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.app.requests.removeAll()

        fixture.open()
        await settle()

        XCTAssertEqual(fixture.hashes, (0..<12).map { "first-page-\($0)" })
        XCTAssertEqual(fixture.app.readFlushes.count, 1)
        XCTAssertTrue(fixture.app.savedFlushes.isEmpty)
        XCTAssertTrue(fixture.app.requests.isEmpty)
        XCTAssertFalse(fixture.controller.pageFetching)
        XCTAssertFalse(fixture.controller.pageFinished)
        XCTAssertTrue(fixture.controller.isOnline)
        XCTAssertEqual(fixture.stories.feedPage, 1)

        fixture.controller.fetchNextPage(nil)
        fixture.controller.fetchFeedDetail(2, withCallback: nil)
        fixture.controller.checkScroll()
        XCTAssertTrue(fixture.app.requests.isEmpty, "Provisional rows must not start page two before authoritative page one")

        fixture.app.releaseReadFlush()
        XCTAssertEqual(fixture.app.savedFlushes.count, 1)
        XCTAssertTrue(fixture.app.requests.isEmpty)
        fixture.app.releaseSavedFlush()
        await settle()
        XCTAssertEqual(fixture.app.requests.count, 1)
        XCTAssertTrue(fixture.app.requests.first?.url.contains("page=1&") == true)
    }

    func test_emptyCachedFirstPageStillRequestsAuthoritativePageOne() async throws {
        let fixture = makeFixture()
        try await prime(fixture, stories: [])
        fixture.app.requests.removeAll()
        fixture.open()
        await settle()
        XCTAssertTrue(fixture.hashes.isEmpty)
        XCTAssertFalse(fixture.controller.pageFinished)
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        XCTAssertEqual(fixture.app.requests.count, 1)
        XCTAssertTrue(fixture.app.requests.first?.url.contains("page=1&") == true)
    }

    func test_laterPagesDoNotReplaceCachedFirstPage() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.controller.fetchNextPage(nil)
        fixture.app.reply(to: 1, with: response(stories: makeStories(12..<24)))
        XCTAssertEqual(fixture.hashes.count, 24)
        fixture.open()
        await settle()
        XCTAssertEqual(fixture.hashes, (0..<12).map { "first-page-\($0)" })
    }

    func test_accountHostAndReadFilterCannotReuseAnotherSnapshot() async throws {
        for changedKey in ["account", "host", "filter", "order"] {
            let fixture = makeFixture()
            try await prime(fixture)
            if changedKey == "account" { fixture.app.activeUsername = "different-" + UUID().uuidString }
            if changedKey == "host" { fixture.app.testURL = "https://other.example.test" }
            if changedKey == "filter" { fixture.stories.readFilter = "unread" }
            if changedKey == "order" { fixture.stories.order = "oldest" }
            fixture.open()
            await settle()
            XCTAssertTrue(fixture.hashes.isEmpty, changedKey)
        }
    }

    func test_oldQueuedFlushCannotLaunchARequestForNewNavigation() async throws {
        let fixture = makeFixture()
        fixture.open()
        fixture.stories.activeFeed = ["id": 2, "feed_title": "Second feed"]
        fixture.open()
        fixture.app.releaseReadFlush()
        await settle()
        XCTAssertTrue(fixture.app.savedFlushes.isEmpty)
        XCTAssertTrue(fixture.app.requests.isEmpty)
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        XCTAssertEqual(fixture.app.requests.count, 1)
        XCTAssertTrue(fixture.app.requests.first?.url.contains("/feed/2/") == true)
    }

    func test_lateAuthoritativeResponseCannotReplaceNewFeedOrAccount() async throws {
        for changeAccount in [false, true] {
            let fixture = makeFixture()
            fixture.open()
            fixture.app.releaseReadFlush()
            fixture.app.releaseSavedFlush()
            await settle()
            if changeAccount { fixture.app.activeUsername = "different-" + UUID().uuidString }
            fixture.stories.activeFeed = ["id": 2, "feed_title": "Second feed"]
            fixture.open()
            fixture.app.reply(to: 0, with: response())
            await settle()
            XCTAssertTrue(fixture.hashes.isEmpty)
        }
    }

    func test_localReadAndSaveWhileFlushingSurviveOlderServerResponse() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.open()
        await settle()
        let story = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        fixture.stories.markStoryRead(story, feed: nil)
        let readStory = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        _ = fixture.stories.markStory(readStory, asSaved: true)
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response())
        await settle()
        let refreshed = try XCTUnwrap((fixture.stories.activeFeedStories as? [[String: Any]])?.first)
        XCTAssertEqual(refreshed["read_status"] as? Int, 1)
        XCTAssertEqual(refreshed["starred"] as? Bool, true)
        XCTAssertNotNil(refreshed["starred_date"])
    }

    func test_localUnreadAndUnsavePreserveReversalAndRemovedDate() async throws {
        let fixture = makeFixture()
        var stories = makeStories(0..<12)
        stories[0]["read_status"] = 1
        stories[0]["starred"] = true
        stories[0]["starred_date"] = "Yesterday"
        try await prime(fixture, stories: stories)
        fixture.open()
        await settle()
        let story = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        fixture.stories.markStoryUnread(story, feed: nil)
        let unreadStory = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        _ = fixture.stories.markStory(unreadStory, asSaved: false)
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: stories))
        await settle()
        let refreshed = try XCTUnwrap((fixture.stories.activeFeedStories as? [[String: Any]])?.first)
        XCTAssertEqual(refreshed["read_status"] as? Int, 0)
        XCTAssertEqual(refreshed["starred"] as? Bool, false)
        XCTAssertNil(refreshed["starred_date"])
    }

    func test_provisionalReadStateDoesNotTrustUnownedGlobalReadTables() async throws {
        let fixture = makeFixture()
        var stories = makeStories(0..<12)
        stories[0]["read_status"] = 1
        try await prime(fixture, stories: stories)
        fixture.app.unreadStoryHashes["first-page-0"] = true
        fixture.app.recentlyReadStories["first-page-1"] = true
        fixture.open()
        await settle()
        let first = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        let second = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.dropFirst().first)
        XCTAssertFalse(fixture.stories.isStoryUnread(first))
        XCTAssertTrue(fixture.stories.isStoryUnread(second))
    }

    func test_authoritativeInsertionPreservesVisibleStoryPixelOffsetAndSelection() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.open()
        await settle()
        let path = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 4))
        fixture.table.contentOffset.y = fixture.table.rectForRow(at: path).minY + 13
        fixture.table.selectRow(at: path, animated: false, scrollPosition: .none)
        fixture.controller.markedHashes.removeAll()
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: makeStories(100..<103) + makeStories(0..<12)))
        await settle()

        let moved = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 7))
        XCTAssertEqual(fixture.table.contentOffset.y - fixture.table.rectForRow(at: moved).minY, 13, accuracy: 0.5)
        XCTAssertEqual(fixture.table.indexPathForSelectedRow, moved)
        XCTAssertTrue(fixture.controller.markedHashes.isEmpty, "Programmatic restoration must not mark passed rows read")
    }

    func test_networkRefreshFailureKeepsCachedRowsAndRestoresNormalPagingFlags() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.open()
        await settle()
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.fail(to: fixture.app.requests.count - 1)
        await settle()
        XCTAssertEqual(fixture.hashes.count, 12)
        XCTAssertFalse(fixture.controller.pageFetching)
        XCTAssertFalse(fixture.controller.isOnline)
        XCTAssertFalse(fixture.controller.value(forKey: "restoringFirstPageViewport") as? Bool ?? true)
        fixture.controller.resetFeedDetail()
        XCTAssertFalse(fixture.controller.value(forKey: "restoringFirstPageViewport") as? Bool ?? true)
        XCTAssertNil(fixture.controller.value(forKey: "firstPageLoad"))
    }

    func test_authoritativeResponseRemovesProvisionalReadResolver() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.open()
        await settle()
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response())
        fixture.app.recentlyReadStories["first-page-0"] = true
        let story = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        XCTAssertNil(story["_nb_provisional_read_state"])
        XCTAssertFalse(fixture.stories.isStoryUnread(story), "Authoritative rows resume the existing global read resolver")
    }

    func test_cachedArticleMissingFromUnreadRefreshStaysOpenUntilExplicitNextOrPrevious() async throws {
        for direction in [-1, 1] {
            let fixture = makeFixture()
            fixture.stories.readFilter = "unread"
            try await prime(fixture)
            fixture.open()
            await settle()
            let cached = try XCTUnwrap(fixture.stories.activeFeedStories as? [[AnyHashable: Any]])
            fixture.app.activeStory = cached[5]
            let pages = FirstPageLoadingPages()
            pages.appDelegate = fixture.app
            pages.currentPage = StoryDetailViewController()
            pages.currentPage.pageIndex = 5
            fixture.app.testPages = pages
            fixture.app.releaseReadFlush()
            fixture.app.releaseSavedFlush()
            await settle()
            let remaining = makeStories(0..<12).filter { $0["story_hash"] as? String != "first-page-5" }
            fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: remaining))
            await settle()
            XCTAssertEqual(fixture.app.activeStory["story_hash"] as? String, "first-page-5")
            XCTAssertEqual(pages.currentPage.pageIndex, 5)
            XCTAssertTrue(pages.pageChanges.isEmpty)
            XCTAssertTrue(fixture.controller.hasRetainedFirstPageStory())
            pages.setStoryFromScroll(true)
            XCTAssertTrue(pages.pageChanges.isEmpty)
            let action = NSSelectorFromString(direction > 0 ? "changeToNextPage:" : "changeToPreviousPage:")
            pages.perform(action, with: nil)
            XCTAssertEqual(pages.pageChanges, [direction > 0 ? 5 : 4])
            XCTAssertFalse(fixture.controller.hasRetainedFirstPageStory())
        }
    }

    func test_retainedArticleWithNoSurvivingNeighborsClampsAndFeedNavigationClearsGuard() async throws {
        for navigateFeed in [false, true] {
            let fixture = makeFixture()
            try await prime(fixture)
            fixture.open()
            await settle()
            fixture.app.activeStory = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?[9])
            let pages = FirstPageLoadingPages()
            pages.appDelegate = fixture.app
            pages.currentPage = StoryDetailViewController()
            pages.currentPage.pageIndex = 9
            fixture.app.testPages = pages
            fixture.app.releaseReadFlush()
            fixture.app.releaseSavedFlush()
            await settle()
            fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: makeStories(100..<102)))
            await settle()
            XCTAssertEqual(pages.currentPage.pageIndex, 9)
            XCTAssertTrue(fixture.controller.hasRetainedFirstPageStory())
            if navigateFeed {
                fixture.open()
                XCTAssertFalse(fixture.controller.hasRetainedFirstPageStory())
            } else {
                pages.perform(NSSelectorFromString("changeToNextPage:"), with: nil)
                XCTAssertEqual(pages.pageChanges, [1])
            }
        }
    }

    func test_provisionalPresentationDoesNotReplaceGlobalFeedMetadataOrProfile() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.app.dictActiveFeeds = ["sentinel": ["id": "sentinel"]]
        fixture.app.dictSocialProfile = ["id": 99, "username": "owner"]
        fixture.open()
        let recentlyRead = fixture.app.recentlyReadFeeds
        await settle()
        XCTAssertEqual(fixture.hashes.count, 12)
        XCTAssertEqual(fixture.app.dictActiveFeeds.count, 1)
        XCTAssertNotNil(fixture.app.dictActiveFeeds["sentinel"])
        XCTAssertEqual(fixture.app.dictSocialProfile["id"] as? Int, 99)
        XCTAssertTrue(fixture.app.recentlyReadFeeds === recentlyRead)
    }

    func test_lateSnapshotCannotReplaceAnAuthoritativeResponseOrNewNavigation() async throws {
        for change in ["response", "navigation", "account", "filter"] {
            let fixture = makeFixture()
            try await prime(fixture)
            fixture.controller.holdCache = true
            fixture.open()
            await settle()
            XCTAssertEqual(fixture.controller.heldCache.count, 1)
            if change == "response" {
                fixture.app.releaseReadFlush()
                fixture.app.releaseSavedFlush()
                await settle()
                fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: makeStories(100..<112)))
            } else if change == "navigation" {
                fixture.stories.activeFeed = ["id": 2]
                fixture.open()
            } else if change == "account" { fixture.app.activeUsername = "other" }
            else { fixture.stories.readFilter = "unread" }
            fixture.controller.releaseCache()
            await settle()
            XCTAssertEqual(fixture.hashes, change == "response" ? (100..<112).map { "first-page-\($0)" } : [])
        }
    }

    func test_trainingChangeWhileSnapshotLookupWaitsIsPreserved() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.stories.activeClassifiers = NSMutableDictionary()
        fixture.controller.holdCache = true
        fixture.open()
        await settle()
        fixture.stories.activeClassifiers["1"] = ["feeds": ["1": 1]]
        fixture.controller.releaseCache()
        await settle()
        let classifier = fixture.stories.activeClassifiers["1"] as? [String: Any]
        XCTAssertEqual((classifier?["feeds"] as? [String: Int])?["1"], 1)
    }

    func test_knownOfflineAndCancelledPageOneReleasePaginationGate() async throws {
        for outcome in ["offline", "cancel", "wrong feed"] {
            let fixture = makeFixture()
            try await prime(fixture)
            fixture.open()
            await settle()
            if outcome == "offline" { fixture.controller.isOnline = false }
            fixture.app.releaseReadFlush()
            fixture.app.releaseSavedFlush()
            await settle()
            if outcome == "cancel" { fixture.app.fail(to: fixture.app.requests.count - 1, code: NSURLErrorCancelled) }
            if outcome == "wrong feed" {
                var wrong = response()
                wrong["feed_id"] = 2
                fixture.app.reply(to: fixture.app.requests.count - 1, with: wrong)
            }
            let load = try XCTUnwrap(fixture.controller.value(forKey: "firstPageLoad") as? StoryFirstPageLoad)
            XCTAssertFalse(load.pending, outcome)
            XCTAssertFalse(fixture.controller.pageFetching, outcome)
            XCTAssertEqual(fixture.hashes.count, 12, outcome)
        }
    }

    func test_sameOpenArticleMovesWithoutReplacingItsPageOrAdvancingUnread() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.open()
        await settle()
        fixture.app.activeStory = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?[5])
        let pages = FirstPageLoadingPages()
        pages.appDelegate = fixture.app
        let page = FirstPageLoadingStoryPage()
        page.pageIndex = 5
        pages.currentPage = page
        pages.scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        pages.scrollView.contentSize = CGSize(width: 390 * 15, height: 844 * 15)
        fixture.app.testPages = pages
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: makeStories(100..<103) + makeStories(0..<12)))
        await settle()
        XCTAssertTrue(pages.currentPage === page)
        XCTAssertEqual(page.pageIndex, 8)
        if pages.isHorizontal {
            XCTAssertEqual(page.view.frame.minX, 390 * 8, accuracy: 0.5)
            XCTAssertEqual(pages.scrollView.contentOffset.x, 390 * 8, accuracy: 0.5)
        } else {
            XCTAssertEqual(page.view.frame.minY, 844 * 8, accuracy: 0.5)
            XCTAssertEqual(pages.scrollView.contentOffset.y, 844 * 8, accuracy: 0.5)
        }
        XCTAssertEqual(fixture.app.activeStory["story_hash"] as? String, "first-page-5")
        XCTAssertTrue(pages.pageChanges.isEmpty)
        XCTAssertEqual(pages.advances, 0)
    }

    func test_forcedSavedTagEditDuringRefreshKeepsAddedAndRemovedTags() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.open()
        await settle()
        var edited = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        edited["user_tags"] = ["added"]
        _ = fixture.stories.markStory(edited, asSaved: true, forceUpdate: true)
        edited["user_tags"] = [] as [String]
        _ = fixture.stories.markStory(edited, asSaved: true, forceUpdate: true)
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response())
        let refreshed = try XCTUnwrap((fixture.stories.activeFeedStories as? [[String: Any]])?.first)
        XCTAssertEqual(refreshed["user_tags"] as? [String], [])
        XCTAssertEqual(refreshed["starred"] as? Bool, true)
    }

    func test_folderReopenShowsSnapshotBeforeQueuesAndPreservesEightHundredFeedLimit() async throws {
        let fixture = makeFixture()
        fixture.app.riverFeeds = (1...805).map { NSNumber(value: $0) }
        fixture.openRiver()
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        XCTAssertEqual(fixture.app.requests.count, 1)
        let firstURL = try XCTUnwrap(fixture.app.requests.first?.url)
        XCTAssertTrue(firstURL.contains("&f=800&page=1"))
        XCTAssertFalse(firstURL.contains("f=801"))
        fixture.app.reply(to: 0, with: response())
        await settle()
        fixture.app.requests.removeAll()
        fixture.openRiver()
        await settle()
        XCTAssertEqual(fixture.hashes.count, 12)
        XCTAssertTrue(fixture.app.requests.isEmpty)
        fixture.controller.fetchRiverPage(2, withCallback: nil)
        XCTAssertTrue(fixture.app.requests.isEmpty)
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        XCTAssertEqual(fixture.app.requests.first?.url, firstURL)
    }

    func test_cancelledFirstPageRetriesPageOneWithoutLosingAnchorOrLocalEditsThenAllowsPageTwo() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.open()
        await settle()
        let load = try XCTUnwrap(fixture.controller.value(forKey: "firstPageLoad") as? StoryFirstPageLoad)
        let anchor = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 4))
        fixture.table.contentOffset.y = fixture.table.rectForRow(at: anchor).minY + 17
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.fail(to: fixture.app.requests.count - 1, code: NSURLErrorCancelled)
        let story = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        fixture.stories.markStoryRead(story, feed: nil)
        fixture.controller.fetchNextPage(nil)
        await settle()
        XCTAssertTrue(fixture.app.requests.last?.url.contains("page=1&") == true)
        XCTAssertTrue(fixture.controller.value(forKey: "firstPageLoad") as? StoryFirstPageLoad === load)
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response())
        await settle()
        XCTAssertEqual((fixture.stories.activeFeedStories as? [[String: Any]])?.first?["read_status"] as? Int, 1)
        XCTAssertEqual(fixture.table.contentOffset.y - fixture.table.rectForRow(at: anchor).minY, 17, accuracy: 0.5)
        fixture.controller.fetchNextPage(nil)
        XCTAssertTrue(fixture.app.requests.last?.url.contains("page=2&") == true)
    }

    func test_failedQueuedPostsPreservePreOpeningReadSaveAndTagsWhileLaterSuccessAllowsServerChanges() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        let story = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        fixture.stories.markStoryRead(story, feed: nil)
        var edited = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        edited["user_tags"] = ["pending tag"]
        _ = fixture.stories.markStory(edited, asSaved: true, forceUpdate: true)
        fixture.open()
        await settle()
        fixture.app.beginQueuedReadPOST(hashes: ["1": ["first-page-0"]])
        fixture.app.finishPOST(success: false)
        await settle()
        fixture.app.beginQueuedSavedPOST(params: ["story_id": "first-page-0", "feed_id": 1, "user_tags": ["pending tag"]])
        fixture.app.finishPOST(success: false)
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response())
        await settle()
        let preserved = try XCTUnwrap((fixture.stories.activeFeedStories as? [[String: Any]])?.first)
        XCTAssertEqual(preserved["read_status"] as? Int, 1)
        XCTAssertEqual(preserved["starred"] as? Bool, true)
        XCTAssertEqual(preserved["user_tags"] as? [String], ["pending tag"])

        fixture.open()
        await settle()
        fixture.app.beginQueuedReadPOST(hashes: ["1": ["first-page-0"]])
        fixture.app.finishPOST(success: true)
        await settle()
        fixture.app.beginQueuedSavedPOST(params: ["story_id": "first-page-0", "feed_id": 1, "user_tags": ["pending tag"]])
        fixture.app.finishPOST(success: true)
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response())
        await settle()
        let authoritative = try XCTUnwrap((fixture.stories.activeFeedStories as? [[String: Any]])?.first)
        XCTAssertEqual(authoritative["read_status"] as? Int, 0)
        XCTAssertEqual(authoritative["starred"] as? Bool, false)
        XCTAssertEqual(authoritative["user_tags"] as? [String], [])
    }

    func test_failedQueuedPostsReassertLatestReversalsRatherThanTheirObsoleteRequestValues() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        var edited = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        fixture.stories.markStoryRead(edited, feed: nil)
        edited["user_tags"] = ["old pending tag"]
        _ = fixture.stories.markStory(edited, asSaved: true, forceUpdate: true)
        fixture.open()
        await settle()
        fixture.app.beginQueuedReadPOST(hashes: ["1": ["first-page-0"]])
        let cached = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        fixture.stories.markStoryUnread(cached, feed: nil)
        fixture.app.finishPOST(success: false)
        await settle()
        fixture.app.beginQueuedSavedPOST(params: ["story_id": "first-page-0", "feed_id": 1, "user_tags": ["old pending tag"]])
        var unsaved = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?.first)
        unsaved["user_tags"] = [] as [String]
        _ = fixture.stories.markStory(unsaved, asSaved: false, forceUpdate: true)
        fixture.app.finishPOST(success: false)
        await settle()
        var stale = makeStories(0..<12)
        stale[0]["read_status"] = 1
        stale[0]["starred"] = true
        stale[0]["starred_date"] = "Stale date"
        stale[0]["user_tags"] = ["old pending tag"]
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: stale))
        await settle()
        let final = try XCTUnwrap((fixture.stories.activeFeedStories as? [[String: Any]])?.first)
        XCTAssertEqual(final["read_status"] as? Int, 0)
        XCTAssertEqual(final["starred"] as? Bool, false)
        XCTAssertNil(final["starred_date"])
        XCTAssertEqual(final["user_tags"] as? [String], [])
    }

    func test_retainedFarPageSwipeUsesGestureDirectionBeforeNewListClamping() async throws {
        for direction in [-1, 1] {
            let fixture = makeFixture()
            try await prime(fixture)
            fixture.open()
            await settle()
            fixture.app.activeStory = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?[8])
            let pages = FirstPageLoadingPages()
            pages.appDelegate = fixture.app
            pages.currentPage = StoryDetailViewController()
            pages.currentPage.pageIndex = 8
            let scroll = FirstPageGestureScroll(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            scroll.contentSize = CGSize(width: 390 * 15, height: 844 * 15)
            pages.scrollView = scroll
            fixture.app.testPages = pages
            fixture.app.releaseReadFlush()
            fixture.app.releaseSavedFlush()
            await settle()
            fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: makeStories(9..<10) + makeStories(1..<2) + makeStories(3..<4)))
            await settle()
            XCTAssertTrue(pages.pageChanges.isEmpty)
            scroll.testingDrag = true
            let rawPage = CGFloat(8 + direction)
            var projected = pages.isHorizontal ? CGPoint(x: 390 * rawPage, y: 0) : CGPoint(x: 0, y: 844 * rawPage)
            let expectedProjected = projected
            pages.scrollViewWillEndDragging(scroll, withVelocity: .zero, targetContentOffset: &projected)
            XCTAssertEqual(projected, expectedProjected, "The end-of-drag target must preserve direction around the retained frame before deceleration")
            XCTAssertTrue(pages.pageChanges.isEmpty)
            scroll.contentOffset = expectedProjected
            pages.scrollViewDidScroll(scroll)
            XCTAssertEqual(pages.pageChanges, [direction > 0 ? 0 : 2])
        }
    }

    func test_retainedArticleSurvivesReorientationAndRefreshWithoutLosingReadingOffset() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        fixture.open()
        await settle()
        fixture.app.activeStory = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?[8])
        let pages = FirstPageLoadingPages()
        pages.appDelegate = fixture.app
        let current = FirstPageLoadingStoryPage()
        current.appDelegate = fixture.app
        current.pageIndex = 8
        current.webView = WKWebView(frame: current.view.bounds)
        current.webView.scrollView.addObserver(current, forKeyPath: "contentOffset", options: [], context: nil)
        current.view.addSubview(current.webView)
        current.webView.scrollView.contentSize = CGSize(width: 390, height: 4_000)
        current.webView.scrollView.contentOffset.y = 321
        pages.currentPage = current
        pages.scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        pages.scrollView.contentSize = CGSize(width: 390 * 15, height: 844 * 15)
        pages.scrollView.addSubview(current.view)
        fixture.app.testPages = pages
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: makeStories(1..<4)))
        await settle()
        pages.scrollView.bounds.size = CGSize(width: 844, height: 390)
        pages.reorientPages()
        XCTAssertFalse(current.view.isHidden)
        XCTAssertEqual(current.pageIndex, 8)
        XCTAssertEqual(current.webView.scrollView.contentOffset.y, 321, accuracy: 0.5)
        pages.refreshPages()
        XCTAssertTrue(pages.currentPage === current)
        XCTAssertEqual(current.pageIndex, 8)
        XCTAssertFalse(current.view.isHidden)
        XCTAssertEqual(current.webView.scrollView.contentOffset.y, 321, accuracy: 0.5)
        XCTAssertTrue(pages.pageChanges.isEmpty)
        XCTAssertEqual(fixture.app.activeStory["story_hash"] as? String, "first-page-8")
        pages.changeToPreviousPage(nil)
        XCTAssertEqual(pages.pageChanges, [2])
    }

    func test_cachedClusterChildSelectionAndReadEditsSurviveAuthoritativeInsertion() async throws {
        let preferences = UserDefaults.standard
        let original = preferences.object(forKey: "story_clustering")
        preferences.set(true, forKey: "story_clustering")
        defer {
            if let original { preferences.set(original, forKey: "story_clustering") }
            else { preferences.removeObject(forKey: "story_clustering") }
        }
        let fixture = makeFixture()
        fixture.app.dictUserProfile = ["preferences": ["cluster_mark_read": true]]
        var cached = makeStories(0..<12)
        cached[4]["cluster_stories"] = [["story_hash": "related-child", "story_feed_id": 1, "story_title": "Related child", "read_status": 0]]
        try await prime(fixture, stories: cached)
        fixture.open()
        await settle()
        let parent = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 4))
        let selected = IndexPath(row: parent.row + 1, section: parent.section)
        fixture.table.selectRow(at: selected, animated: false, scrollPosition: .none)
        let parentStory = try XCTUnwrap((fixture.stories.activeFeedStories as? [[AnyHashable: Any]])?[4])
        fixture.stories.markStoryRead(parentStory, feed: nil)
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        fixture.app.reply(to: fixture.app.requests.count - 1, with: response(stories: makeStories(100..<103) + cached))
        await settle()
        let moved = try XCTUnwrap(fixture.controller.indexPath(forStoryLocation: 7))
        XCTAssertEqual(fixture.table.indexPathForSelectedRow, IndexPath(row: moved.row + 1, section: moved.section))
        let story = try XCTUnwrap((fixture.stories.activeFeedStories as? [[String: Any]])?[7])
        XCTAssertEqual((story["cluster_stories"] as? [[String: Any]])?.first?["read_status"] as? Int, 1)
    }

    func test_ignoredPageOneRequestDoesNotInstallAPermanentPaginationGate() async throws {
        let fixture = makeFixture()
        try await prime(fixture)
        let load = try XCTUnwrap(fixture.controller.value(forKey: "firstPageLoad") as? StoryFirstPageLoad)
        fixture.controller.pageFinished = true
        fixture.controller.fetchFeedDetail(1, withCallback: nil)
        XCTAssertTrue(fixture.controller.value(forKey: "firstPageLoad") as? StoryFirstPageLoad === load)
        XCTAssertFalse(load.pending)
        fixture.controller.pageFinished = false
        fixture.controller.fetchNextPage(nil)
        XCTAssertTrue(fixture.app.requests.last?.url.contains("page=2&") == true)
    }

    func test_successiveSearchEditsClearNormalCacheGatesAndRejectEarlierResultsInFeedsAndRivers() async throws {
        for river in [false, true] {
            let fixture = makeFixture()
            if river {
                fixture.app.riverFeeds = [1]
                fixture.openRiver()
                fixture.app.releaseReadFlush()
                fixture.app.releaseSavedFlush()
                await settle()
                fixture.app.reply(to: 0, with: response())
                await settle()
            } else {
                try await prime(fixture)
            }
            let search = UITextField()
            fixture.controller.searchField = search
            let delegate = fixture.controller as UITextFieldDelegate
            let reloadSelector = NSSelectorFromString("reloadStories")
            defer { NSObject.cancelPreviousPerformRequests(withTarget: fixture.controller, selector: reloadSelector, object: nil) }
            func edit(_ query: String) {
                search.text = query
                fixture.controller.perform(NSSelectorFromString("searchFieldDidChange:"), with: search)
            }
            func query(in index: Int) -> String? {
                guard fixture.app.requests.indices.contains(index) else { return nil }
                return URLComponents(string: fixture.app.requests[index].url)?.queryItems?.first { $0.name == "query" }?.value
            }

            edit("breeding ground for malicious")
            await settleSearchDebounce()
            let firstSearch = fixture.app.requests.count - 1
            XCTAssertEqual(query(in: firstSearch), "breeding ground for malicious")
            XCTAssertNil(fixture.controller.value(forKey: "firstPageLoad"))
            fixture.app.reply(to: firstSearch, with: response(stories: makeStories(100..<102)))
            await settle()
            XCTAssertEqual(fixture.hashes, ["first-page-100", "first-page-101"])

            XCTAssertTrue(delegate.textFieldShouldClear?(search) == true)
            search.text = ""
            let clearedRequest = fixture.app.requests.count - 1
            XCTAssertNil(query(in: clearedRequest))
            edit("Container for Chaos")
            _ = delegate.textFieldShouldReturn?(search)
            // StoryFirstPageLoadingTests.swift holds the clear-triggered normal response until the query already changed, then lets the real one-second search debounce run.
            fixture.app.reply(to: clearedRequest, with: response(stories: makeStories(200..<202)))
            await settleSearchDebounce()
            let replacement = fixture.app.requests.count - 1
            XCTAssertGreaterThan(replacement, clearedRequest)
            XCTAssertEqual(query(in: replacement), "Container for Chaos")
            XCTAssertNil(fixture.controller.value(forKey: "firstPageLoad"))
            fixture.app.reply(to: replacement, with: response(stories: makeStories(300..<302)))
            await settle()
            XCTAssertEqual(fixture.hashes, ["first-page-300", "first-page-301"])
            XCTAssertFalse(fixture.controller.pageFetching)

            while !(search.text ?? "").isEmpty { edit(String((search.text ?? "").dropLast())) }
            edit("\"container for chaos\"")
            _ = delegate.textFieldShouldReturn?(search)
            await settleSearchDebounce()
            let quoted = fixture.app.requests.count - 1
            XCTAssertGreaterThan(quoted, replacement)
            XCTAssertEqual(query(in: quoted), "\"container for chaos\"")
            fixture.app.reply(to: quoted, with: response(stories: makeStories(400..<402)))
            fixture.app.reply(to: firstSearch, with: response(stories: makeStories(100..<102)))
            fixture.app.fail(to: clearedRequest, code: NSURLErrorCancelled)
            await settle()
            XCTAssertEqual(fixture.hashes, ["first-page-400", "first-page-401"])
            XCTAssertFalse(fixture.controller.pageFetching)
            XCTAssertNil(fixture.controller.value(forKey: "firstPageLoad"))

            fixture.controller.fetchNextPage(nil)
            let nextPage = fixture.app.requests.count - 1
            XCTAssertGreaterThan(nextPage, quoted)
            XCTAssertEqual(query(in: nextPage), "\"container for chaos\"")
            XCTAssertTrue(fixture.app.requests.last?.url.contains("page=2&") == true)
        }
    }

    private func settleSearchDebounce() async {
        let reloaded = expectation(description: "Real search debounce submits the latest edit")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) { reloaded.fulfill() }
        await fulfillment(of: [reloaded], timeout: 2)
    }

    private func prime(_ fixture: FirstPageFixture, stories: [[String: Any]]? = nil) async throws {
        fixture.open()
        fixture.app.releaseReadFlush()
        fixture.app.releaseSavedFlush()
        await settle()
        XCTAssertEqual(fixture.app.requests.count, 1)
        fixture.app.reply(to: 0, with: response(stories: stories))
        await settle()
    }

    private func settle() async {
        // StoryFirstPageLoadingTests.swift leaves queued POST callbacks withheld; this only drains rendering/cache callbacks.
        let drained = expectation(description: "main queue and cache callbacks")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { drained.fulfill() }
        await fulfillment(of: [drained], timeout: 2)
    }

    private func makeFixture() -> FirstPageFixture {
        let app = FirstPageLoadingAppDelegate()
        app.activeUsername = "first-page-test-" + UUID().uuidString
        app.testURL = "https://example.test"
        app.interceptRequests()
        app.isPremium = true
        app.isPremiumArchive = true
        app.selectedIntelligence = 0
        app.recentlyReadStories = NSMutableDictionary()
        app.unreadStoryHashes = NSMutableDictionary()
        app.unsavedStoryHashes = NSMutableDictionary()
        app.dictFeeds = ["1": ["id": 1, "feed_title": "First feed", "active": 1]]
        app.dictActiveFeeds = NSMutableDictionary()
        app.dictFolders = [:]
        app.dictFoldersArray = NSMutableArray()
        let stories = FirstPageLoadingStories()
        stories.appDelegate = app
        stories.feedPage = 1
        stories.activeFeed = app.dictFeeds["1"] as? [AnyHashable: Any]
        app.storiesCollection = stories
        let controller = FirstPageLoadingController()
        controller.appDelegate = app
        controller.storiesCollection = stories
        controller.dashboardIndex = -1
        app.testController = controller
        let table = UITableView(frame: CGRect(x: 0, y: 0, width: 390, height: 320), style: .plain)
        table.estimatedRowHeight = 0
        controller.storyTitlesTable = table
        controller.view = UIView(frame: table.frame)
        controller.view.addSubview(table)
        controller.messageView = UIView()
        controller.messageView.isHidden = true
        controller.setValue(NSCache<NSString, NSString>(), forKey: "storyPreviewTextCache")
        controller.setValue(NSCache<NSString, NSNumber>(), forKey: "storyHeightCache")
        table.dataSource = controller
        table.delegate = controller
        return FirstPageFixture(app: app, stories: stories, controller: controller, table: table)
    }

    private func response(stories: [[String: Any]]? = nil) -> [String: Any] {
        ["feed_id": 1, "stories": stories ?? makeStories(0..<12), "classifiers": [:],
         "feed_authors": [], "feed_tags": [], "user_profiles": []]
    }

    private func makeStories(_ indices: Range<Int>) -> [[String: Any]] {
        indices.map { ["story_hash": "first-page-\($0)", "story_feed_id": 1,
                       "story_title": "Story \($0)", "story_content": "<p>Body \($0)</p>",
                       "story_timestamp": 1_800_000_000 - $0, "read_status": 0,
                       "starred": false, "user_tags": [], "image_urls": [],
                       "intelligence": ["feed": 0, "author": 0, "tags": 0, "title": 0]] }
    }
}

@MainActor private struct FirstPageFixture {
    let app: FirstPageLoadingAppDelegate
    let stories: FirstPageLoadingStories
    let controller: FirstPageLoadingController
    let table: UITableView
    var hashes: [String] { (stories.activeFeedStories as? [[String: Any]] ?? []).compactMap { $0["story_hash"] as? String } }

    func openRiver() {
        let selector = NSSelectorFromString("loadRiverFeedDetailView:withFolder:")
        typealias Load = @convention(c) (AnyObject, Selector, AnyObject, NSString) -> Void
        let implementation = unsafeBitCast(app.method(for: selector), to: Load.self)
        implementation(app, selector, controller, "everything")
    }

    func open() {
        let selector = NSSelectorFromString("loadFeedDetailView:")
        typealias Load = @convention(c) (AnyObject, Selector, Bool) -> Void
        let implementation = unsafeBitCast(app.method(for: selector), to: Load.self)
        implementation(app, selector, false)
    }
}

private final class FirstPageLoadingStories: StoriesCollection {
    var readFilter = "all"
    var order = "newest"
    override var activeReadFilter: String! { readFilter }
    override var activeOrder: String! { order }
}

@MainActor private final class FirstPageLoadingController: FeedDetailViewController {
    var markedHashes: [String] = []
    var holdCache = false
    var heldCache: [() -> Void] = []
    func releaseCache() { if !heldCache.isEmpty { heldCache.removeFirst()() } }
    @objc(lookupFirstPageRequest:completion:)
    func lookupSnapshot(_ request: StoryFirstPageRequest, completion: @escaping (StoryFirstPageSnapshot?) -> Void) {
        StoryFirstPageCache.shared.lookup(request) { snapshot in
            if self.holdCache { self.heldCache.append { completion(snapshot) } }
            else { completion(snapshot) }
        }
    }
    override var isLegacyTable: Bool { true }
    override var isMarkReadOnScroll: Bool { true }
    override func viewDidLoad() {}
    override func reload() { reloadTable() }
    override func loadingFeed() {}
    override func updateStoryTitlesHeaderPillState() {}
    override func loadFaviconsFromActiveFeed() {}
    override func showFetchingBanner(_ title: String!, isOffline: Bool) {}
    override func hideFetchingBanner() {}
    override func markStoryReadIfNeeded(_ story: [AnyHashable: Any]!, isScrolling: Bool) -> Bool {
        if isScrolling, let hash = story["story_hash"] as? String { markedHashes.append(hash) }
        return false
    }
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 80 }
    @objc(beginOfflineTimer) func suppressUnownedSQLiteFallback() {}
    @objc(cacheImagesForStories:) func suppressImageDownloads(_ stories: Any?) {}
    @objc(warmStoryPreviewCacheAroundLocation:) func suppressWarmup(_ location: Int) {}
    @objc(updateBottomNextFeedControlForScroll:) func suppressNavigationControls(_ scroll: UIScrollView) {}
}

private final class FirstPageLoadingAppDelegate: NewsBlurAppDelegate {
    struct CapturedRequest {
        let url: String
        let success: (URLSessionDataTask?, Any?) -> Void
        let failure: (URLSessionDataTask?, NSError?) -> Void
    }
    var requests: [CapturedRequest] = []
    var readFlushes: [() -> Void] = []
    var postResults: [(Bool) -> Void] = []
    override func post(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask?, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error?) -> Void)!) {
        postResults.append { passed in
            if passed { success(nil, [:]) }
            else { failure(nil, NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)) }
        }
    }
    func finishPOST(success: Bool) {
        guard !postResults.isEmpty else { XCTFail("Missing synthetic queued POST"); return }
        postResults.removeFirst()(success)
    }
    func beginQueuedReadPOST(hashes: NSDictionary) {
        guard !readFlushes.isEmpty else { XCTFail("Missing queued read flush"); return }
        let callback: @convention(block) () -> Void = readFlushes.removeFirst()
        let selector = NSSelectorFromString("syncQueuedReadStories:withStories:withCallback:")
        typealias Sync = @convention(c) (AnyObject, Selector, AnyObject?, NSDictionary, AnyObject) -> Void
        let implementation = unsafeBitCast(method(for: selector), to: Sync.self)
        implementation(self, selector, nil, hashes, callback as AnyObject)
    }
    func beginQueuedSavedPOST(params: NSDictionary) {
        guard !savedFlushes.isEmpty else { XCTFail("Missing queued saved flush"); return }
        let callback: @convention(block) () -> Void = savedFlushes.removeFirst()
        perform(NSSelectorFromString("syncQueuedSavedStoryParams:withCallback:"), with: params, with: callback as AnyObject)
    }
    var savedFlushes: [() -> Void] = []
    weak var testController: FeedDetailViewController?
    var testPages: StoryPagesViewController?
    var riverFeeds: [NSNumber] = []
    override func feedIdsForTopLevelRiver(withReadFilter readFilter: String!) -> [Any]! { riverFeeds }
    override func show(_ column: UISplitViewController.Column, debugInfo: String!, animated: Bool) {}
    override var storyPagesViewController: StoryPagesViewController! { testPages }
    override var feedDetailViewController: FeedDetailViewController! {
        get { testController }
        set { testController = newValue }
    }
    override func cleanUpTryFeed() {}
    override func adjustStoryDetailWebView() {}
    @objc(updateFeedDetailTitleView) func suppressTitleView() {}

    var testURL = "https://example.test"
    override var url: String! { testURL }
    func interceptRequests() { _ = Self.installInterceptors }

    func releaseReadFlush() { if !readFlushes.isEmpty { readFlushes.removeFirst()() } }
    func releaseSavedFlush() { if !savedFlushes.isEmpty { savedFlushes.removeFirst()() } }
    func reply(to index: Int, with response: [String: Any]) {
        guard requests.indices.contains(index) else { XCTFail("Missing intercepted page request \(index)"); return }
        requests[index].success(nil, response)
    }

    func fail(to index: Int, code: Int = NSURLErrorNotConnectedToInternet) {
        guard requests.indices.contains(index) else { XCTFail("Missing intercepted request"); return }
        requests[index].failure(nil, NSError(domain: NSURLErrorDomain, code: code))
    }

    // StoryFirstPageLoadingTests.swift installs selectors only on this synthetic delegate, never on the logged-in app.
    private static let installInterceptors: Void = {
        for (original, replacement) in [
            ("GETreturningTask:parameters:success:failure:", "nb_test_GET:parameters:success:failure:"),
            ("flushQueuedReadStories:withCallback:", "nb_test_readFlush:callback:"),
            ("flushQueuedSavedStories:withCallback:", "nb_test_savedFlush:callback:")
        ] {
            let method = class_getInstanceMethod(FirstPageLoadingAppDelegate.self, NSSelectorFromString(replacement))!
            class_replaceMethod(FirstPageLoadingAppDelegate.self, NSSelectorFromString(original),
                                method_getImplementation(method), method_getTypeEncoding(method))
        }
    }()

    @objc(nb_test_GET:parameters:success:failure:)
    func captureGET(_ url: String, parameters: Any?, success: @escaping (URLSessionDataTask?, Any?) -> Void,
                    failure: @escaping (URLSessionDataTask?, NSError?) -> Void) -> URLSessionDataTask? {
        requests.append(CapturedRequest(url: url, success: success, failure: failure))
        return nil
    }
    @objc(nb_test_readFlush:callback:)
    func holdReadFlush(_ force: Bool, callback: @escaping () -> Void) { readFlushes.append(callback) }
    @objc(nb_test_savedFlush:callback:)
    func holdSavedFlush(_ force: Bool, callback: @escaping () -> Void) { savedFlushes.append(callback) }
}

@MainActor private final class FirstPageLoadingPages: StoryPagesViewController {
    var pageChanges: [Int] = []
    var advances = 0
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)) }
    override func viewDidLoad() {}
    override func changePage(_ pageIndex: Int, animated: Bool) { pageChanges.append(pageIndex) }
    override func resizeScrollView() {}
    override func advanceToNextUnread() { advances += 1 }
    override func resetPages() {}
    override func hidePages() {}
}

@MainActor private final class FirstPageLoadingStoryPage: StoryDetailViewController {
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {}
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)) }
    override func viewDidLoad() {}
}

@MainActor private final class FirstPageGestureScroll: UIScrollView {
    var testingDrag = false
    override var isDragging: Bool { testingDrag }
}
