import XCTest
import UIKit

@testable import NewsBlur

final class Test_StoryThumbnailCache: XCTestCase {
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

    func test_renderingCachedStoryAndClusterSkipsRedundantImageDownloads() {
        let (appDelegate, cache) = makeCache()
        let storyImage = makeImage()
        let clusterImage = makeImage()
        cache.memoryCache.setObject(storyImage, forKey: "story")
        cache.diskCache.setObject(clusterImage, forKey: "cluster")
        let controller = makeController(appDelegate: appDelegate)

        cacheStories([
            ["story_hash": "story", "image_urls": ["https://example.test/story.jpg"],
             "cluster_stories": [["story_hash": "cluster", "image_urls": ["https://example.test/cluster.jpg"]]]]
        ], on: controller)

        XCTAssertEqual(controller.requestedStoryHashes, [])
        XCTAssertTrue(cache.object(forKey: "story") as? UIImage === storyImage)
        XCTAssertTrue(cache.object(forKey: "cluster") as? UIImage === clusterImage)
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

    @objc(getFirstImage:forStoryHash:withManager:)
    func recordImageRequest(_ urls: Any?, forStoryHash hash: String?, withManager manager: Any?) {
        if let hash {
            requestedStoryHashes.append(hash)
        }
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
}

private final class ThumbnailStorageDouble: NSObject {
    private var objects: [String: Any] = [:]

    @objc(objectForKey:)
    func object(forKey key: String) -> Any? {
        objects[key]
    }

    @objc(setObject:forKey:)
    func setObject(_ object: Any, forKey key: String) {
        objects[key] = object
    }

    @objc(setObject:forKey:withCost:)
    func setObject(_ object: Any, forKey key: String, withCost cost: UInt) {
        setObject(object, forKey: key)
    }
}
