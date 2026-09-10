import XCTest
import UIKit

@testable import NewsBlur

final class Test_StoryThumbnailCache: XCTestCase {
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

        cacheStories(updated, on: current)

        XCTAssertEqual(current.requests.count, 2, "Completed source ownership must match the globally cached bitmap after another controller writes it")
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === oldImage, "Keep the displayed image while its replacement is pending")
        let retry = try XCTUnwrap(current.requests.dropFirst().first)
        finish(retry, with: newImage, on: current)
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === newImage)
        cacheStories(updated, on: current)
        XCTAssertEqual(current.requests.count, 2, "The verified replacement should be reused")
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
    private var objects: [String: Any] = [:]
    private(set) var readCount = 0
    var afterRead: (() -> Void)?

    @objc(objectForKey:)
    func object(forKey key: String) -> Any? {
        readCount += 1
        let result = objects[key]
        let completion = afterRead
        afterRead = nil
        completion?()
        return result
    }

    @objc(setObject:forKey:)
    func setObject(_ object: Any, forKey key: String) {
        objects[key] = object
    }

    @objc(setObject:forKey:withCost:)
    func setObject(_ object: Any, forKey key: String, withCost cost: UInt) {
        setObject(object, forKey: key)
    }

    @objc(removeObjectForKey:)
    func removeObject(forKey key: String) {
        objects.removeValue(forKey: key)
    }

    @objc func removeAllObjects() {
        objects.removeAll()
    }
}
