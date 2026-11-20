import XCTest

@testable import NewsBlur

@MainActor final class Test_StoryReplacementPerformance: XCTestCase {
    func test_replacementDoesNotCopyScannedStoriesAtLargeCollectionSizes() {
        for count in [100, 1_000, 5_000] {
            let copies = StoryCopyCounter()
            let original = (0..<count).map { CopyTrackingStory(hash: "story-\($0)", counter: copies) }
            let collection = makeCollection(original)
            let replacement: NSDictionary = ["story_hash": "story-\(count - 1)", "read_status": 1]

            replace(replacement, withID: "story-\(count - 1)", on: collection)

            XCTAssertEqual(copies.count, 0, "Searching \(count) stories should not copy their dictionaries")
            XCTAssertTrue((collection.activeFeedStories as NSArray).lastObject as AnyObject === replacement)
            XCTAssertTrue((collection.activeFeedStories as NSArray)[0] as AnyObject === original[0])
        }
    }

    func test_realReadAndUnreadPreserveSnapshotsAndUnrelatedStoryIdentity() {
        let first: NSDictionary = ["story_hash": "first", "read_status": 0]
        let target: NSDictionary = ["story_hash": "target", "read_status": 0, "starred": true]
        let last: NSDictionary = ["story_hash": "last", "read_status": 1]
        let collection = makeCollection([first, target, last])
        let unreadSnapshot = collection.activeFeedStories as NSArray

        collection.markStoryRead(target as! [AnyHashable: Any], feed: nil)
        let readSnapshot = collection.activeFeedStories as NSArray
        let readStory = readSnapshot[1] as! NSDictionary

        XCTAssertEqual(readStory["read_status"] as? Int, 1)
        XCTAssertEqual(readStory["starred"] as? Bool, true)
        XCTAssertEqual((unreadSnapshot[1] as! NSDictionary)["read_status"] as? Int, 0)
        XCTAssertTrue(readSnapshot[0] as AnyObject === first)
        XCTAssertTrue(readSnapshot[2] as AnyObject === last)

        collection.markStoryUnread(readStory as! [AnyHashable: Any], feed: nil)
        let final = collection.activeFeedStories as NSArray

        XCTAssertEqual((final[1] as! NSDictionary)["read_status"] as? Int, 0)
        XCTAssertEqual(readStory["read_status"] as? Int, 1)
        XCTAssertTrue(final[0] as AnyObject === first)
        XCTAssertTrue(final[2] as AnyObject === last)
        XCTAssertEqual(final.count, 3)
    }

    func test_duplicateHashReplacesOnlyFirstMatchAndRetainsOrder() {
        let first: NSDictionary = ["story_hash": "duplicate", "story_title": "first"]
        let second: NSDictionary = ["story_hash": "duplicate", "story_title": "second"]
        let replacement: NSDictionary = ["story_hash": "duplicate", "read_status": 1]
        let collection = makeCollection([first, second])
        let snapshot = collection.activeFeedStories as NSArray

        replace(replacement, withID: "duplicate", on: collection)

        XCTAssertTrue((collection.activeFeedStories as NSArray)[0] as AnyObject === replacement)
        XCTAssertTrue((collection.activeFeedStories as NSArray)[1] as AnyObject === second)
        XCTAssertTrue(snapshot[0] as AnyObject === first)
    }

    func test_missingAndNilTargetHashesDoNotReplaceAnyStory() {
        let story: NSDictionary = ["story_hash": "existing", "read_status": 0]
        let replacement: NSDictionary = ["story_hash": "new", "read_status": 1]
        let collection = makeCollection([story])

        replace(replacement, withID: "missing", on: collection)
        replace(replacement, withID: nil, on: collection)

        XCTAssertEqual(collection.activeFeedStories.count, 1)
        XCTAssertTrue((collection.activeFeedStories as NSArray)[0] as AnyObject === story)
    }

    func test_nonStringAndAbsentHashesRetainExistingStringComparisonSemantics() {
        let examples: [(NSDictionary, String)] = [
            (["story_hash": 42], "42"),
            (["story_hash": NSNull()], NSNull().description),
            ([:], "(null)")
        ]

        for (story, identifier) in examples {
            let collection = makeCollection([story])
            let replacement: NSDictionary = ["story_hash": identifier, "read_status": 1]

            replace(replacement, withID: identifier, on: collection)

            XCTAssertTrue((collection.activeFeedStories as NSArray)[0] as AnyObject === replacement)
        }
    }

    func test_benchmark100StoryReadUnreadReplacement() {
        benchmarkReplacement(storyCount: 100)
    }

    func test_benchmark1000StoryReadUnreadReplacement() {
        benchmarkReplacement(storyCount: 1_000)
    }

    func test_benchmark5000StoryReadUnreadReplacement() {
        benchmarkReplacement(storyCount: 5_000)
    }

    private func benchmarkReplacement(storyCount: Int) {
        let stories: [NSDictionary] = (0..<storyCount).map { index in
            ["story_hash": "story-\(index)", "read_status": 0, "story_feed_id": 1,
             "story_title": "A realistic story title \(index)", "story_content": String(repeating: "Story content. ", count: 50),
             "story_authors": "Author", "story_timestamp": 1_000, "starred": false,
             "shared": false, "image_urls": ["https://example.test/image.jpg"]]
        }
        let collection = makeCollection(stories)
        let options = XCTMeasureOptions()
        options.iterationCount = 5

        // StoryReplacementPerformanceTests.swift: each sample measures 40 real read/unread replacements at the end of the list.
        measure(metrics: [XCTClockMetric()], options: options) {
            for _ in 0..<20 {
                let unread = collection.activeFeedStories.last as! [AnyHashable: Any]
                collection.markStoryRead(unread, feed: nil)
                let read = collection.activeFeedStories.last as! [AnyHashable: Any]
                collection.markStoryUnread(read, feed: nil)
            }
        }
    }

    private func makeCollection(_ stories: [Any]) -> StoriesCollection {
        let collection = StoriesCollection()
        collection.appDelegate = nil
        collection.activeFeedStories = stories
        return collection
    }

    private func replace(_ story: NSDictionary, withID identifier: String?, on collection: StoriesCollection) {
        collection.perform(NSSelectorFromString("replaceStory:withId:"), with: story, with: identifier)
    }
}

private final class StoryCopyCounter {
    var count = 0
}

private final class CopyTrackingStory: NSObject, NSMutableCopying {
    let hashValueForStory: String
    let counter: StoryCopyCounter

    init(hash: String, counter: StoryCopyCounter) {
        hashValueForStory = hash
        self.counter = counter
    }

    @objc(objectForKey:)
    func object(forKey key: String) -> Any? {
        key == "story_hash" ? hashValueForStory : nil
    }

    override func value(forKey key: String) -> Any? {
        object(forKey: key)
    }

    func mutableCopy(with zone: NSZone? = nil) -> Any {
        counter.count += 1
        return NSMutableDictionary(dictionary: ["story_hash": hashValueForStory, "read_status": 0])
    }
}
