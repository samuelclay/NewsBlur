import XCTest
import UIKit

@testable import NewsBlur

final class Test_FaviconCache: XCTestCase {
    func test_warmLookupsDoNotTouchCombinedOrDiskCache() {
        let (appDelegate, cache) = makeCache()
        let image = makeImage()
        cache.memoryCache.setObject(image, forKey: "feed")

        for _ in 0..<500 {
            XCTAssertTrue(appDelegate.getFavicon("feed") === image)
        }

        XCTAssertEqual(cache.combinedReadCount, 0)
        XCTAssertEqual(cache.diskCache.readCount, 0)
    }

    func test_missingIconIsReadFromDiskOnlyOnceAcrossCellReuse() {
        let (appDelegate, cache) = makeCache()

        for _ in 0..<500 {
            XCTAssertNil(appDelegate.getFavicon("missing", isSocial: true))
        }

        XCTAssertEqual(cache.diskCache.readCount, 1)
    }

    func test_savedFaviconReplacesRememberedMiss() {
        let (appDelegate, cache) = makeCache()
        XCTAssertNil(appDelegate.getFavicon("feed", isSocial: true))
        let image = makeImage()

        appDelegate.saveFavicon(image, feedId: "feed")
        XCTAssertTrue(appDelegate.getFavicon("feed") === image)

        cache.memoryCache.removeAllObjects()
        XCTAssertTrue(appDelegate.getFavicon("feed") === image)
        XCTAssertEqual(cache.diskCache.readCount, 2)
    }

    func test_accountResetInvalidatesRememberedMisses() {
        let (appDelegate, cache) = makeCache()
        XCTAssertNil(appDelegate.getFavicon("feed", isSocial: true))
        let image = makeImage()
        cache.diskCache.setObject(image, forKey: "feed")

        appDelegate.dictFeeds = nil

        XCTAssertTrue(appDelegate.getFavicon("feed") === image)
        XCTAssertEqual(cache.diskCache.readCount, 2)
    }

    func test_diskPromotionUsesDecodedPixelCost() {
        let (appDelegate, cache) = makeCache()
        let image = makeImage()
        cache.diskCache.setObject(image, forKey: "feed")

        XCTAssertTrue(appDelegate.getFavicon("feed") === image)

        XCTAssertEqual(cache.memoryCache.costs["feed"], 96 * 96 * 4)
    }

    private func makeCache() -> (NewsBlurAppDelegate, FaviconCacheDouble) {
        let appDelegate = NewsBlurAppDelegate()
        let cache = FaviconCacheDouble()
        // FaviconCacheTests.swift exercises the Objective-C cache selectors without importing PINCache internals.
        appDelegate.setValue(cache, forKey: "cachedFavicons")
        return (appDelegate, cache)
    }

    private func makeImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
    }
}

private final class FaviconCacheDouble: NSObject {
    @objc let memoryCache = FaviconStorageDouble()
    @objc let diskCache = FaviconStorageDouble()
    private(set) var combinedReadCount = 0

    @objc(objectForKey:)
    func object(forKey key: String) -> Any? {
        combinedReadCount += 1
        if let image = memoryCache.object(forKey: key) {
            return image
        }
        let image = diskCache.object(forKey: key)
        if let image {
            memoryCache.setObject(image, forKey: key)
        }
        return image
    }
}

private final class FaviconStorageDouble: NSObject {
    private var objects: [String: Any] = [:]
    private(set) var costs: [String: UInt] = [:]
    private(set) var readCount = 0

    @objc(objectForKey:)
    func object(forKey key: String) -> Any? {
        readCount += 1
        return objects[key]
    }

    @objc(setObject:forKey:)
    func setObject(_ object: Any, forKey key: String) {
        objects[key] = object
    }

    @objc(setObject:forKey:withCost:)
    func setObject(_ object: Any, forKey key: String, withCost cost: UInt) {
        objects[key] = object
        costs[key] = cost
    }

    @objc func removeAllObjects() {
        objects.removeAll()
        costs.removeAll()
    }
}
