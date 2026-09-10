import XCTest
import UIKit

@testable import NewsBlur

final class Test_StoryThumbnailCache: XCTestCase {
    @MainActor func test_reversePrefetchRestoresEvictedDiskThumbnailBeforeTheOlderCellDraws() throws {
        let defaults = UserDefaults.standard
        let imagePreference = defaults.object(forKey: "story_list_preview_images_size")
        defaults.set("small_right", forKey: "story_list_preview_images_size")
        defer {
            if let imagePreference { defaults.set(imagePreference, forKey: "story_list_preview_images_size") }
            else { defaults.removeObject(forKey: "story_list_preview_images_size") }
        }
        let (app, cache) = makeCache()
        app.fontDescriptorTitleSize = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption1).withSize(13)
        app.recentlyReadStories = NSMutableDictionary()
        app.dictFeeds = ["1": ["id": 1, "feed_title": "Reverse thumbnail fixture", "active": 1]]
        let stories = StoriesCollection()
        stories.appDelegate = app
        stories.activeFeed = ["id": 1]
        stories.setStories((0..<1_000).map { index -> [String: Any] in
            ["story_hash": "reverse-\(index)", "story_feed_id": 1,
             "story_title": "Reverse thumbnail fixture \(index)", "story_content": "Preview text",
             "story_authors": "Author", "short_parsed_date": "3m", "story_timestamp": 1_800_000_000 - index,
             "image_urls": ["https://example.test/\(index).jpg"], "read_status": 0,
             "intelligence": ["feed": 0, "title": 0, "author": 0, "tags": 0]]
        })
        let controller = ThumbnailPrefetchController()
        controller.appDelegate = app
        controller.storiesCollection = stories
        controller.textSize = FeedDetailTextSize(rawValue: 0)!
        controller.pageFetching = true
        let table = UITableView(frame: CGRect(x: 0, y: 0, width: 390, height: 780), style: .plain)
        controller.storyTitlesTable = table
        controller.view = UIView(frame: table.frame)
        controller.messageView = UIView()
        controller.messageView.isHidden = true
        controller.setValue((0..<1_000).map { ["type": 0, "story_location": $0] }, forKey: "visibleStoryRows")
        let path = IndexPath(row: 0, section: 0)
        cache.diskCache.setObject(makeImage(), forKey: "reverse-0")
        func drawOlderCell() throws -> Data? {
            let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: path) as? FeedDetailTableCell)
            cell.setValue(app, forKey: "appDelegate")
            let height = controller.tableView(table, heightForRowAt: path)
            let view = FeedDetailTableCellView(frame: CGRect(x: 0, y: 0, width: 390, height: height))
            view.cell = cell
            view.appDelegate = app
            return UIGraphicsImageRenderer(size: view.bounds.size).image { _ in view.draw(view.bounds) }.pngData()
        }
        let reference = try drawOlderCell()
        XCTAssertNotNil(cache.memoryCache.object(forKey: "reverse-0"))
        // StoryThumbnailCacheTests.swift reproduces an older image falling out of the bounded memory cache during a long forward scroll.
        cache.memoryCache.removeAllObjects()
        cache.diskCache.resetReadTracking()
        let warmed = expectation(description: "Evicted thumbnail read from disk before the reverse row becomes visible")
        cache.diskCache.onRead = { hash, isMain in
            if hash == "reverse-0" && !isMain { warmed.fulfill() }
        }
        defer { cache.diskCache.onRead = nil }
        let prefetcher = try XCTUnwrap(controller as? UITableViewDataSourcePrefetching)
        prefetcher.tableView(table, prefetchRowsAt: [path])
        wait(for: [warmed], timeout: 2)
        let promoted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            cache.memoryCache.object(forKey: "reverse-0") is UIImage
        }, object: nil)
        wait(for: [promoted], timeout: 2)
        let started = CACurrentMediaTime()
        let actual = try drawOlderCell()
        print("THUMBNAIL_REVERSE_BENCHMARK loaded_stories=1000 main_disk_reads=\(cache.diskCache.mainReadCount) worker_disk_reads=\(cache.diskCache.readCount - cache.diskCache.mainReadCount) first_cell_draw_ms=\((CACurrentMediaTime() - started) * 1_000)")
        XCTAssertEqual(actual, reference, "The prefetched image keeps the exact existing cell rendering")
        XCTAssertEqual(cache.diskCache.mainReadCount, 0, "Reverse scrolling must not synchronously unarchive the evicted thumbnail while drawing")
        XCTAssertEqual(cache.diskCache.readCount, 1)
    }

    func test_removingThumbnailDuringDiskReadRejectsItsOldResult() {
        let (appDelegate, cache) = makeCache()
        cache.diskCache.setObject(makeImage(), forKey: "story")
        cache.diskCache.afterRead = {
            appDelegate.removeCachedStoryImage(forStoryHash: "story")
        }

        XCTAssertNil(appDelegate.cachedImage(forStoryHash: "story"))
        XCTAssertNil(appDelegate.cachedImage(forStoryHash: "story"))
        XCTAssertFalse(cache.diskCache.object(forKey: "story") is UIImage)
    }

    func test_removingAllThumbnailsDuringDiskReadRejectsItsOldResult() {
        let (appDelegate, cache) = makeCache()
        cache.diskCache.setObject(makeImage(), forKey: "story")
        cache.diskCache.afterRead = {
            appDelegate.removeAllCachedStoryImages()
        }

        XCTAssertNil(appDelegate.cachedImage(forStoryHash: "story"))
        XCTAssertNil(appDelegate.cachedImage(forStoryHash: "story"))
        XCTAssertFalse(cache.diskCache.object(forKey: "story") is UIImage)
    }

    func test_removingOneThumbnailPreservesOtherImagesAndAllowsNewSave() {
        let (appDelegate, cache) = makeCache()
        let unrelated = makeImage()
        appDelegate.cacheStoryImage(makeImage(), forStoryHash: "story")
        appDelegate.cacheStoryImage(unrelated, forStoryHash: "other")

        appDelegate.removeCachedStoryImage(forStoryHash: "story")

        XCTAssertNil(appDelegate.cachedImage(forStoryHash: "story"))
        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "other") === unrelated)
        let replacement = makeImage()
        appDelegate.cacheStoryImage(replacement, forStoryHash: "story")
        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "story") === replacement)
        XCTAssertTrue(cache.diskCache.object(forKey: "story") as? UIImage === replacement)
    }

    func test_removingAllThumbnailsAllowsDiskRecoveryAfterNewSave() {
        let (appDelegate, cache) = makeCache()
        XCTAssertNil(appDelegate.cachedImage(forStoryHash: "story"))
        appDelegate.removeAllCachedStoryImages()
        let image = makeImage()
        appDelegate.cacheStoryImage(image, forStoryHash: "story")
        cache.memoryCache.removeAllObjects()

        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "story") === image)
    }

    func test_explicitFeedRefreshRequestsSameURLAgainWithoutHidingThumbnail() {
        let appDelegate = ThumbnailRefreshAppDelegate()
        let cache = ThumbnailCacheDouble()
        appDelegate.setValue(cache, forKey: "cachedStoryImages")
        let controller = makeController(appDelegate: appDelegate)
        let collection = StoriesCollection()
        collection.appDelegate = appDelegate
        collection.activeFeed = ["id": 1]
        controller.storiesCollection = collection
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
        let image = makeImage()
        cacheStories(stories, on: controller)
        finish(controller.requests[0], with: image, on: controller)

        controller.instafetchFeed()
        cacheStories(stories, on: controller)

        XCTAssertEqual(appDelegate.feedRefreshRequests, 1)
        XCTAssertEqual(controller.requestedStoryHashes, ["story", "story"])
        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "story") === image)
    }

    func test_accountChangeRequestsSameURLAgainWithoutHidingThumbnail() {
        let appDelegate = ThumbnailRefreshAppDelegate()
        let cache = ThumbnailCacheDouble()
        appDelegate.setValue(cache, forKey: "cachedStoryImages")
        let controller = makeController(appDelegate: appDelegate)
        appDelegate.testFeedDetail = controller
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
        let image = makeImage()
        cacheStories(stories, on: controller)
        finish(controller.requests[0], with: image, on: controller)

        // StoryThumbnailCacheTests.swift exercises the same feed reset used by NewsBlurAppDelegate.showLogin.
        appDelegate.dictFeeds = nil
        cacheStories(stories, on: controller)

        XCTAssertEqual(controller.requestedStoryHashes, ["story", "story"])
        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "story") === image)
    }

    func test_missingThumbnailIsReadFromDiskOnlyOnceAcrossCellReuse() {
        let (appDelegate, cache) = makeCache()
        appDelegate.cacheStoryImagePlaceholder("missing")

        for _ in 0..<500 {
            XCTAssertNil(appDelegate.cachedImage(forStoryHash: "missing"))
        }

        XCTAssertEqual(cache.diskCache.readCount, 1)
    }

    func test_legacyPlaceholderStillRecoversRealDiskThumbnail() {
        let (appDelegate, cache) = makeCache()
        let image = makeImage()
        cache.memoryCache.setObject(NSNull(), forKey: "story")
        cache.diskCache.setObject(image, forKey: "story")

        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "story") === image)
        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "story") === image)
        XCTAssertEqual(cache.diskCache.readCount, 1)
    }

    func test_savedThumbnailReplacesKnownMissAndSurvivesMemoryEviction() {
        let (appDelegate, cache) = makeCache()
        XCTAssertNil(appDelegate.cachedImage(forStoryHash: "story"))
        let image = makeImage()

        appDelegate.cacheStoryImage(image, forStoryHash: "story")
        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "story") === image)
        cache.memoryCache.removeAllObjects()
        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "story") === image)
        XCTAssertEqual(cache.diskCache.readCount, 2)
    }

    func test_clearingMemoryCacheInvalidatesKnownMiss() {
        let (appDelegate, cache) = makeCache()
        XCTAssertNil(appDelegate.cachedImage(forStoryHash: "story"))
        let image = makeImage()
        cache.diskCache.setObject(image, forKey: "story")
        cache.memoryCache.removeAllObjects()

        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "story") === image)
        XCTAssertEqual(cache.diskCache.readCount, 2)
    }

    func test_placeholderCannotOverwriteDownloadFinishingAfterItsLookup() {
        let appDelegate = ThumbnailLookupRaceAppDelegate()
        let cache = ThumbnailCacheDouble()
        let image = makeImage()
        appDelegate.setValue(cache, forKey: "cachedStoryImages")
        appDelegate.afterLookup = {
            appDelegate.cacheStoryImage(image, forStoryHash: "story")
        }

        appDelegate.cacheStoryImagePlaceholder("story")

        XCTAssertTrue(cache.memoryCache.object(forKey: "story") as? UIImage === image)
    }

    func test_diskPromotionCannotOverwriteNewerDownload() {
        let (appDelegate, cache) = makeCache()
        let oldImage = makeImage()
        let newImage = makeImage()
        cache.diskCache.setObject(oldImage, forKey: "story")
        cache.diskCache.afterRead = {
            appDelegate.cacheStoryImage(newImage, forStoryHash: "story")
        }

        XCTAssertTrue(appDelegate.cachedImage(forStoryHash: "story") === newImage)
        XCTAssertTrue(cache.memoryCache.object(forKey: "story") as? UIImage === newImage)
    }

    func test_placeholderDoesNotReplaceWarmThumbnail() {
        let (appDelegate, cache) = makeCache()
        let image = makeImage()
        cache.memoryCache.setObject(image, forKey: "story")

        appDelegate.cacheStoryImagePlaceholder("story")

        XCTAssertTrue(cache.memoryCache.object(forKey: "story") as? UIImage === image)
    }

    func test_placeholderDoesNotMaskThumbnailAlreadyOnDisk() {
        let (appDelegate, cache) = makeCache()
        let image = makeImage()
        cache.diskCache.setObject(image, forKey: "story")

        appDelegate.cacheStoryImagePlaceholder("story")

        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === image)
    }

    func test_existingStoryAndClusterThumbnailsRemainVisibleDuringFirstSessionRefresh() {
        let (appDelegate, cache) = makeCache()
        let storyImage = makeImage()
        let clusterImage = makeImage()
        cache.memoryCache.setObject(storyImage, forKey: "story")
        cache.diskCache.setObject(clusterImage, forKey: "cluster")
        let controller = makeController(appDelegate: appDelegate)

        let stories: [[String: Any]] = [
            ["story_hash": "story", "image_urls": ["https://example.test/story.jpg"],
             "cluster_stories": [["story_hash": "cluster", "image_urls": ["https://example.test/cluster.jpg"]]]]
        ]
        cacheStories(stories, on: controller)
        cacheStories(stories, on: controller)

        XCTAssertEqual(controller.requestedStoryHashes, ["story", "cluster"])
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === storyImage)
        XCTAssertTrue(cache.object(forKey: "cluster") as? UIImage === clusterImage)

        finish(controller.requests[0], with: storyImage, on: controller)
        finish(controller.requests[1], with: clusterImage, on: controller)
        cacheStories(stories, on: controller)
        XCTAssertEqual(controller.requestedStoryHashes, ["story", "cluster"])
    }

    func test_missingThumbnailStillStartsDownload() {
        let (appDelegate, _) = makeCache()
        let controller = makeController(appDelegate: appDelegate)

        cacheStories([["story_hash": "missing", "image_urls": ["https://example.test/missing.jpg"]]], on: controller)

        XCTAssertEqual(controller.requestedStoryHashes, ["missing"])
    }

    func test_failedThumbnailPlaceholderCanRetryOnLaterPageLoad() {
        let (appDelegate, cache) = makeCache()
        cache.memoryCache.setObject(NSNull(), forKey: "retry")
        let controller = makeController(appDelegate: appDelegate)

        cacheStories([["story_hash": "retry", "image_urls": ["https://example.test/retry.jpg"]]], on: controller)

        XCTAssertEqual(controller.requestedStoryHashes, ["retry"])
    }

    func test_changedSourceRefreshesWithoutHidingPreviousThumbnail() {
        let (appDelegate, cache) = makeCache()
        let original = makeImage()
        let replacement = makeImage()
        cache.memoryCache.setObject(original, forKey: "story")
        let controller = makeController(appDelegate: appDelegate)

        cacheStories([["story_hash": "story", "image_urls": ["https://example.test/old.jpg"]]], on: controller)
        finish(controller.requests[0], with: original, on: controller)
        cacheStories([["story_hash": "story", "image_urls": ["https://example.test/new.jpg"]]], on: controller)

        XCTAssertEqual(controller.requestedStoryHashes, ["story", "story"])
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === original)

        finish(controller.requests[1], with: replacement, on: controller)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === replacement)
        cacheStories([["story_hash": "story", "image_urls": ["https://example.test/new.jpg"]]], on: controller)
        XCTAssertEqual(controller.requestedStoryHashes.count, 2)
    }

    func test_obsoleteDownloadCannotOverwriteNewerSource() {
        let (appDelegate, cache) = makeCache()
        let controller = makeController(appDelegate: appDelegate)
        let replacement = makeImage()

        cacheStories([["story_hash": "story", "image_urls": ["https://example.test/old.jpg"]]], on: controller)
        cacheStories([["story_hash": "story", "image_urls": ["https://example.test/new.jpg"]]], on: controller)
        finish(controller.requests[1], with: replacement, on: controller)
        finish(controller.requests[0], with: makeImage(), on: controller)

        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === replacement)
    }

    func test_failedRefreshRetriesAndKeepsOldThumbnail() {
        let (appDelegate, cache) = makeCache()
        let image = makeImage()
        cache.memoryCache.setObject(image, forKey: "story")
        let controller = makeController(appDelegate: appDelegate)
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]

        cacheStories(stories, on: controller)
        finish(controller.requests[0], with: nil, on: controller)
        cacheStories(stories, on: controller)

        XCTAssertEqual(controller.requestedStoryHashes, ["story", "story"])
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === image)
    }

    func test_revertingToCachedSourceDiscardsPendingReplacement() {
        let (appDelegate, cache) = makeCache()
        let image = makeImage()
        let controller = makeController(appDelegate: appDelegate)
        let original: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/old.jpg"]]]

        cacheStories(original, on: controller)
        finish(controller.requests[0], with: image, on: controller)
        cacheStories([["story_hash": "story", "image_urls": ["https://example.test/new.jpg"]]], on: controller)
        cacheStories(original, on: controller)
        finish(controller.requests[1], with: makeImage(), on: controller)

        XCTAssertEqual(controller.requestedStoryHashes.count, 2)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === image)
    }

    func test_explicitlyEmptyImageSourcesRemoveOldThumbnailAndRejectPendingResult() {
        let (appDelegate, cache) = makeCache()
        let controller = makeController(appDelegate: appDelegate)
        cache.memoryCache.setObject(makeImage(), forKey: "story")

        cacheStories([["story_hash": "story", "image_urls": ["https://example.test/old.jpg"]]], on: controller)
        cacheStories([["story_hash": "story", "image_urls": []]], on: controller)
        finish(controller.requests[0], with: makeImage(), on: controller)

        XCTAssertFalse(cache.object(forKey: "story") is UIImage)
    }

    func test_resetAllowsCancelledSourceToBeRequestedAgain() {
        let (appDelegate, cache) = makeCache()
        let controller = makeController(appDelegate: appDelegate)
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]

        cacheStories(stories, on: controller)
        controller.perform(NSSelectorFromString("resetStoryImageRequests"))
        cacheStories(stories, on: controller)
        finish(controller.requests[0], with: makeImage(), on: controller)

        XCTAssertEqual(controller.requestedStoryHashes.count, 2)
        XCTAssertFalse(cache.object(forKey: "story") is UIImage)
    }

    func test_anotherControllerCannotMakeCompletedSourcesHideAStaleSharedThumbnail() throws {
        let (appDelegate, cache) = makeCache()
        let previous = makeController(appDelegate: appDelegate)
        let current = makeController(appDelegate: appDelegate)
        let old: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/old.jpg"]]]
        let updated: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/new.jpg"]]]
        cacheStories(old, on: previous)
        cacheStories(updated, on: current)
        let newImage = makeImage()
        finish(current.requests[0], with: newImage, on: current)
        let oldImage = makeImage()
        finish(previous.requests[0], with: oldImage, on: previous)

        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === newImage, "An older controller must not overwrite a newer completed request, even before the next source lookup")
        cacheStories(updated, on: current)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === newImage)
        XCTAssertEqual(current.requests.count, 1, "The verified replacement should be reused")
    }

    func test_completedSourceStillReusesDiskImageAfterMemoryEviction() {
        let (appDelegate, cache) = makeCache()
        let controller = makeController(appDelegate: appDelegate)
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
        cacheStories(stories, on: controller)
        let image = makeImage()
        finish(controller.requests[0], with: image, on: controller)
        cache.memoryCache.removeAllObjects()
        cacheStories(stories, on: controller)
        XCTAssertEqual(controller.requests.count, 1)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === image)
    }

    func test_sourceLessImageSaveInvalidatesCompletedSourceOwnership() {
        let (appDelegate, cache) = makeCache()
        let controller = makeController(appDelegate: appDelegate)
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
        cacheStories(stories, on: controller)
        finish(controller.requests[0], with: makeImage(), on: controller)
        let replacement = makeImage()
        appDelegate.cacheStoryImage(replacement, forStoryHash: "story")
        cacheStories(stories, on: controller)
        XCTAssertEqual(controller.requests.count, 2)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === replacement)
    }

    func test_accountResetInvalidatesSourceOwnershipForAnotherLiveController() {
        let appDelegate = ThumbnailRefreshAppDelegate()
        let cache = ThumbnailCacheDouble()
        appDelegate.setValue(cache, forKey: "cachedStoryImages")
        let primary = makeController(appDelegate: appDelegate)
        appDelegate.testFeedDetail = primary
        let supplementary = makeController(appDelegate: appDelegate)
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
        cacheStories(stories, on: supplementary)
        let image = makeImage()
        finish(supplementary.requests[0], with: image, on: supplementary)
        appDelegate.dictFeeds = nil
        cacheStories(stories, on: supplementary)
        XCTAssertEqual(supplementary.requests.count, 2)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === image)
    }

    func test_sameSourceAcrossControllersAllowsEitherDownloadToSucceed() {
        for failedRequestFinishesFirst in [false, true] {
            let (appDelegate, cache) = makeCache()
            let first = makeController(appDelegate: appDelegate)
            let second = makeController(appDelegate: appDelegate)
            let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
            cacheStories(stories, on: first)
            cacheStories(stories, on: second)
            let image = makeImage()
            if failedRequestFinishesFirst { finish(first.requests[0], with: nil, on: first) }
            finish(second.requests[0], with: image, on: second)
            if !failedRequestFinishesFirst { finish(first.requests[0], with: nil, on: first) }

            XCTAssertTrue(cache.object(forKey: "story") as? UIImage === image)
            cacheStories(stories, on: second)
            XCTAssertEqual(second.requests.count, 1)
        }
    }

    func test_sameSourceAcrossControllersKeepsBothSuccessfulRequestsValid() {
        let (appDelegate, cache) = makeCache()
        let first = makeController(appDelegate: appDelegate)
        let second = makeController(appDelegate: appDelegate)
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
        cacheStories(stories, on: first)
        cacheStories(stories, on: second)
        let firstImage = makeImage()
        let secondImage = makeImage()
        finish(first.requests[0], with: firstImage, on: first)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === firstImage)
        finish(second.requests[0], with: secondImage, on: second)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === secondImage)
        cacheStories(stories, on: first)
        cacheStories(stories, on: second)
        XCTAssertEqual(first.requests.count, 1)
        XCTAssertEqual(second.requests.count, 1)
    }

    func test_rejectedRequestClearsItsPendingStateAndCanRetry() throws {
        let (appDelegate, cache) = makeCache()
        let first = makeController(appDelegate: appDelegate)
        let second = makeController(appDelegate: appDelegate)
        let old: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/old.jpg"]]]
        cacheStories(old, on: first)
        cacheStories([["story_hash": "story", "image_urls": ["https://example.test/new.jpg"]]], on: second)
        finish(first.requests[0], with: makeImage(), on: first)
        XCTAssertFalse(cache.object(forKey: "story") is UIImage)
        XCTAssertNil((first.value(forKey: "pendingStoryImageRequests") as? NSDictionary)?["story"])

        cacheStories(old, on: first)
        XCTAssertEqual(first.requests.count, 2)
        let retry = try XCTUnwrap(first.requests.last)
        let image = makeImage()
        finish(retry, with: image, on: first)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === image)
    }

    func test_evictedSharedRequestDoesNotSuppressCompletionRetryOrPendingRetry() throws {
        for finishBeforeRetry in [false, true] {
            let (appDelegate, cache) = makeCache()
            let controller = makeController(appDelegate: appDelegate)
            let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
            cacheStories(stories, on: controller)
            let sharedRequests = try XCTUnwrap(appDelegate.value(forKey: "storyImageRequests") as? NSCache<NSString, NSDictionary>)
            sharedRequests.removeAllObjects()
            if finishBeforeRetry {
                finish(controller.requests[0], with: makeImage(), on: controller)
                XCTAssertFalse(cache.object(forKey: "story") is UIImage)
                XCTAssertNil((controller.value(forKey: "pendingStoryImageRequests") as? NSDictionary)?["story"])
            }

            cacheStories(stories, on: controller)
            XCTAssertEqual(controller.requests.count, 2)
            let retry = try XCTUnwrap(controller.requests.last)
            let image = makeImage()
            finish(retry, with: image, on: controller)
            finish(controller.requests[0], with: makeImage(), on: controller)
            XCTAssertTrue(cache.object(forKey: "story") as? UIImage === image)
        }
    }

    func test_explicitRefreshRejectsEarlierSameSourceFromAnotherControllerOnly() throws {
        let (appDelegate, cache) = makeCache()
        let previous = makeController(appDelegate: appDelegate)
        let current = makeController(appDelegate: appDelegate)
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
        cacheStories(stories + [["story_hash": "other", "image_urls": ["https://example.test/other.jpg"]]], on: previous)
        cacheStories(stories, on: current)
        let original = makeImage()
        finish(current.requests[0], with: original, on: current)
        current.resetStoryImageSources()
        cacheStories(stories, on: current)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === original)

        XCTAssertEqual(current.requests.count, 2)
        let refreshedRequest = try XCTUnwrap(current.requests.last)
        let refreshed = makeImage()
        finish(refreshedRequest, with: refreshed, on: current)
        finish(previous.requests[0], with: makeImage(), on: previous)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === refreshed)
        let unrelated = makeImage()
        finish(previous.requests[1], with: unrelated, on: previous)
        XCTAssertTrue(cache.object(forKey: "other") as? UIImage === unrelated)
    }

    func test_externalSaveOrRemovalRejectsAnotherControllersPendingImage() {
        for removeImage in [false, true] {
            let (appDelegate, cache) = makeCache()
            let controller = makeController(appDelegate: appDelegate)
            let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
            cacheStories(stories, on: controller)
            let savedImage = makeImage()
            appDelegate.cacheStoryImage(savedImage, forStoryHash: "story")
            if removeImage { appDelegate.removeCachedStoryImage(forStoryHash: "story") }
            finish(controller.requests[0], with: makeImage(), on: controller)
            if removeImage {
                XCTAssertFalse(cache.object(forKey: "story") is UIImage)
            } else {
                XCTAssertTrue(cache.object(forKey: "story") as? UIImage === savedImage)
            }
            cacheStories(stories, on: controller)
            XCTAssertEqual(controller.requests.count, 2)
        }
    }

    func test_accountResetRejectsAnotherControllersPendingImageAndAllowsRetry() {
        let appDelegate = ThumbnailRefreshAppDelegate()
        let cache = ThumbnailCacheDouble()
        appDelegate.setValue(cache, forKey: "cachedStoryImages")
        let primary = makeController(appDelegate: appDelegate)
        appDelegate.testFeedDetail = primary
        let supplementary = makeController(appDelegate: appDelegate)
        let stories: [[String: Any]] = [["story_hash": "story", "image_urls": ["https://example.test/story.jpg"]]]
        cacheStories(stories, on: supplementary)
        appDelegate.dictFeeds = nil
        finish(supplementary.requests[0], with: makeImage(), on: supplementary)
        XCTAssertFalse(cache.object(forKey: "story") is UIImage)
        cacheStories(stories, on: supplementary)
        XCTAssertEqual(supplementary.requests.count, 2)
    }

    private func finish(_ request: NSDictionary, with image: UIImage?, on controller: ThumbnailDownloadController) {
        controller.perform(NSSelectorFromString("finishStoryImageRequest:withImage:"), with: request, with: image)
    }

    private func cacheStories(_ stories: [[String: Any]], on controller: ThumbnailDownloadController) {
        // StoryThumbnailCacheTests.swift intercepts the private download selector before any network work.
        controller.perform(NSSelectorFromString("cacheImagesForStories:"), with: stories)
        controller.appDelegate.cacheImagesOperationQueue.waitUntilAllOperationsAreFinished()
    }

    private func makeController(appDelegate: NewsBlurAppDelegate) -> ThumbnailDownloadController {
        appDelegate.cacheImagesOperationQueue = OperationQueue()
        appDelegate.cacheImagesOperationQueue.maxConcurrentOperationCount = 1
        let controller = ThumbnailDownloadController()
        controller.appDelegate = appDelegate
        return controller
    }

    private func makeCache() -> (NewsBlurAppDelegate, ThumbnailCacheDouble) {
        let appDelegate = NewsBlurAppDelegate()
        let cache = ThumbnailCacheDouble()
        appDelegate.setValue(cache, forKey: "cachedStoryImages")
        return (appDelegate, cache)
    }

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 60, height: 60)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
        }
    }
}

private final class ThumbnailDownloadController: FeedDetailViewController {
    private(set) var requestedStoryHashes = [String]()
    private(set) var requests = [NSDictionary]()

    override var isLegacyTable: Bool { false }
    override func reload() {}

    @objc(getFirstImage:forStoryHash:withManager:)
    func recordImageRequest(_ urls: Any?, forStoryHash hash: String?, withManager manager: Any?) {
        if let hash {
            requestedStoryHashes.append(hash)
            if let pending = value(forKey: "pendingStoryImageRequests") as? NSDictionary,
               let request = pending[hash] as? NSDictionary {
                requests.append(request)
            }
        }
    }

    @objc(showImageForStoryHash:)
    func ignoreVisibleImageRefresh(_ hash: String) {
    }
}

@MainActor private final class ThumbnailPrefetchController: FeedDetailViewController {
    override var isLegacyTable: Bool { true }
    override var isDashboard: Bool { false }
    override func reload() {}
}

private final class ThumbnailRefreshAppDelegate: NewsBlurAppDelegate {
    var feedRefreshRequests = 0
    weak var testFeedDetail: FeedDetailViewController?

    override var feedDetailViewController: FeedDetailViewController! {
        get { testFeedDetail }
        set { testFeedDetail = newValue }
    }

    override func get(_ urlString: String!, parameters: Any!, success: ((URLSessionDataTask?, Any?) -> Void)!, failure: ((URLSessionDataTask?, Error?) -> Void)!) {
        // StoryThumbnailCacheTests.swift stops the real refresh before network access or response rendering.
        feedRefreshRequests += 1
    }
}

private final class ThumbnailLookupRaceAppDelegate: NewsBlurAppDelegate {
    var afterLookup: (() -> Void)?

    override func cachedImage(forStoryHash storyHash: String!) -> UIImage! {
        let result = super.cachedImage(forStoryHash: storyHash)
        let completion = afterLookup
        afterLookup = nil
        completion?()
        return result
    }
}

private final class ThumbnailCacheDouble: NSObject {
    @objc let memoryCache = ThumbnailStorageDouble()
    @objc let diskCache = ThumbnailStorageDouble()

    @objc(objectForKey:)
    func object(forKey key: String) -> Any? {
        if let image = memoryCache.object(forKey: key) {
            return image
        }
        let image = diskCache.object(forKey: key)
        if let image {
            memoryCache.setObject(image, forKey: key)
        }
        return image
    }

    @objc(objectForKeyedSubscript:)
    func objectForKeyedSubscript(_ key: String) -> Any? {
        object(forKey: key)
    }

    @objc(removeObjectForKey:)
    func removeObject(forKey key: String) {
        memoryCache.removeObject(forKey: key)
        diskCache.removeObject(forKey: key)
    }

    @objc func removeAllObjects() {
        memoryCache.removeAllObjects()
        diskCache.removeAllObjects()
    }
}

private final class ThumbnailStorageDouble: NSObject {
    private let lock = NSLock()
    private var objects: [String: Any] = [:]
    private var reads = 0
    private var mainReads = 0
    var readCount: Int { lock.lock(); defer { lock.unlock() }; return reads }
    var mainReadCount: Int { lock.lock(); defer { lock.unlock() }; return mainReads }
    var afterRead: (() -> Void)?
    var onRead: ((String, Bool) -> Void)?

    func resetReadTracking() {
        lock.lock()
        reads = 0
        mainReads = 0
        lock.unlock()
    }

    @objc(objectForKey:)
    func object(forKey key: String) -> Any? {
        lock.lock()
        reads += 1
        if Thread.isMainThread { mainReads += 1 }
        let result = objects[key]
        let completion = afterRead
        afterRead = nil
        let recorder = onRead
        lock.unlock()
        recorder?(key, Thread.isMainThread)
        completion?()
        return result
    }

    @objc(setObject:forKey:)
    func setObject(_ object: Any, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        objects[key] = object
    }

    @objc(setObject:forKey:withCost:)
    func setObject(_ object: Any, forKey key: String, withCost cost: UInt) {
        setObject(object, forKey: key)
    }

    @objc(removeObjectForKey:)
    func removeObject(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        objects.removeValue(forKey: key)
    }

    @objc func removeAllObjects() {
        lock.lock()
        defer { lock.unlock() }
        objects.removeAll()
    }
}
