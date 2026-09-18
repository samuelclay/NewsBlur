import Foundation
import QuartzCore
import XCTest

@testable import NewsBlur

@MainActor final class Test_StoryFirstPageCache: XCTestCase {
    func test_bulkReadInvalidationRejectsFeedAndRiverSnapshotsWithoutDroppingOtherAccountsOrEdits() async throws {
        let fixture = makeCache()
        let river = try XCTUnwrap(StoryFirstPageRequest(account: "owner", host: fixture.request.host,
                                                       url: fixture.request.host + "/reader/river_stories?page=1"))
        let other = try XCTUnwrap(StoryFirstPageRequest(account: "other", host: fixture.request.host, url: fixture.request.url))
        let otherHost = try XCTUnwrap(StoryFirstPageRequest(account: "owner", host: "https://another.test",
                                                           url: "https://another.test/reader/feed/1/?page=1"))
        for request in [fixture.request, river, other, otherHost] {
            fixture.cache.store(["stories": [makeStory()]], request: request, revision: fixture.cache.newRevision())
        }
        let held = try await requireSnapshot(fixture.cache, request: fixture.request)
        fixture.cache.record(story: ["story_hash": "cache-story", "read_status": 0, "starred": true],
                             fields: ["read_status", "starred"], account: "owner", host: fixture.request.host)

        fixture.cache.invalidateSnapshots(account: "owner", host: fixture.request.host)

        XCTAssertNil(fixture.cache.response(for: held, provisional: true), "A snapshot already returned to an in-flight lookup must also be rejected")
        await assertMiss(fixture.cache, request: fixture.request)
        await assertMiss(fixture.cache, request: river)
        _ = try await requireSnapshot(fixture.cache, request: other)
        _ = try await requireSnapshot(fixture.cache, request: otherHost)
        await flush(fixture.cache)
        let relaunched = StoryFirstPageCache(directory: fixture.directory)
        await assertMiss(relaunched, request: fixture.request)
        await assertMiss(relaunched, request: river)
        _ = try await requireSnapshot(relaunched, request: other)
        _ = try await requireSnapshot(relaunched, request: otherHost)
        let response = relaunched.overlay(["stories": [makeStory()]], request: fixture.request, revision: 0)
        let story = try XCTUnwrap((response["stories"] as? [[String: Any]])?.first)
        XCTAssertEqual(story["read_status"] as? Int, 0)
        XCTAssertEqual(story["starred"] as? Bool, true, "Invalidation must preserve unsynced individual story edits")
    }

    func test_bulkReadInvalidationRejectsLateOldResponseButAcceptsFreshResponse() async throws {
        let fixture = makeCache()
        let oldRevision = fixture.cache.newRevision()
        fixture.cache.invalidateSnapshots(account: "owner", host: fixture.request.host)
        // StoryFirstPageCacheTests.swift models a request started before bulk Mark Read completing after it.
        fixture.cache.storeAuthoritative(["stories": [makeStory()]], request: fixture.request, revision: oldRevision)
        await assertMiss(fixture.cache, request: fixture.request)

        let newRevision = fixture.cache.newRevision()
        var readStory = makeStory()
        readStory["read_status"] = 1
        fixture.cache.storeAuthoritative(["stories": [readStory]], request: fixture.request, revision: newRevision)
        let fresh = try await requireSnapshot(fixture.cache, request: fixture.request)
        XCTAssertEqual((fixture.cache.response(for: fresh, provisional: false)?["stories"] as? [[String: Any]])?.first?["read_status"] as? Int, 1)

        fixture.cache.storeAuthoritative(["stories": [makeStory()]], request: fixture.request, revision: oldRevision)
        await flush(fixture.cache)
        let retained = try await requireSnapshot(fixture.cache, request: fixture.request)
        XCTAssertEqual(retained.revision, newRevision, "A late invalid response must not overwrite the fresh snapshot")
    }

    func test_snapshotOwnsImmutableNestedJSON() async throws {
        let fixture = makeCache()
        let content = NSMutableString(string: "<p>Original body</p>")
        let story = NSMutableDictionary(dictionary: makeStory())
        story["story_content"] = content
        let stories = NSMutableArray(object: story)
        let response = NSMutableDictionary(dictionary: ["stories": stories])
        fixture.cache.store(response, request: fixture.request, revision: fixture.cache.newRevision())
        content.setString("Changed body")
        story["read_status"] = 1
        stories.removeAllObjects()

        let snapshot = try await requireSnapshot(fixture.cache, request: fixture.request)
        let actual = try XCTUnwrap(fixture.cache.response(for: snapshot, provisional: false)?["stories"] as? [[String: Any]])
        XCTAssertEqual(actual.count, 1)
        XCTAssertEqual(actual.first?["story_content"] as? String, "<p>Original body</p>")
        XCTAssertEqual(actual.first?["read_status"] as? Int, 0)
    }

    func test_diskRelaunchOverlaysReadSaveReversalsAndRemovedFieldsOnlyForOwner() async throws {
        let fixture = makeCache()
        fixture.cache.store(["stories": [makeStory()]], request: fixture.request, revision: fixture.cache.newRevision())
        fixture.cache.record(story: ["story_hash": "cache-story", "read_status": 1, "starred": true,
                                     "starred_date": "Today", "user_tags": ["saved"]],
                             fields: ["read_status", "starred", "starred_date", "user_tags"], account: "owner", host: fixture.request.host)
        fixture.cache.record(story: ["story_hash": "cache-story", "read_status": 0, "starred": false,
                                     "user_tags": NSNull()],
                             fields: ["read_status", "starred", "starred_date", "user_tags"], account: "owner", host: fixture.request.host)
        await flush(fixture.cache)
        let relaunched = StoryFirstPageCache(directory: fixture.directory)
        let snapshot = try await requireSnapshot(relaunched, request: fixture.request)
        let response = try XCTUnwrap(relaunched.response(for: snapshot, provisional: true))
        let story = try XCTUnwrap((response["stories"] as? [[String: Any]])?.first)
        XCTAssertEqual(story["read_status"] as? Int, 0)
        XCTAssertEqual(story["starred"] as? Bool, false)
        XCTAssertNil(story["starred_date"])
        XCTAssertTrue(story["user_tags"] is NSNull)
        let other = try XCTUnwrap(StoryFirstPageRequest(account: "other", host: fixture.request.host, url: fixture.request.url))
        await assertMiss(relaunched, request: other)
    }

    func test_authoritativeResponseSupersedesOlderEditsButRetainsEditsDuringRequest() {
        let fixture = makeCache()
        fixture.cache.record(story: ["story_hash": "cache-story", "read_status": 1], fields: ["read_status"],
                             account: "owner", host: fixture.request.host)
        let started = fixture.cache.newRevision()
        fixture.cache.record(story: ["story_hash": "cache-story", "starred": true], fields: ["starred"],
                             account: "owner", host: fixture.request.host)
        let response = fixture.cache.overlay(["stories": [makeStory()]], request: fixture.request, revision: started)
        let story = (response["stories"] as? [[String: Any]])?.first
        XCTAssertEqual(story?["read_status"] as? Int, 0)
        XCTAssertEqual(story?["starred"] as? Bool, true)
        XCTAssertNil(story?[StoryFirstPageCache.provisionalReadKey])
    }

    func test_gapInBoundedJournalRejectsAnOlderSnapshot() async {
        let fixture = makeCache()
        fixture.cache.store(["stories": [makeStory()]], request: fixture.request, revision: fixture.cache.newRevision())
        for index in 0...StoryFirstPageCache.maximumJournalEntries {
            fixture.cache.record(story: ["story_hash": "journal-\(index)", "read_status": 1], fields: ["read_status"],
                                 account: "owner", host: fixture.request.host)
        }
        await flush(fixture.cache)
        await assertMiss(fixture.cache, request: fixture.request)
        let relaunched = StoryFirstPageCache(directory: fixture.directory)
        await assertMiss(relaunched, request: fixture.request)
    }

    func test_expiredAndFutureDatedSnapshotsAreMisses() async {
        for elapsed in [StoryFirstPageCache.snapshotTTL + 1, -1] {
            var now = Date()
            let fixture = makeCache(now: { now })
            fixture.cache.store(["stories": [makeStory()]], request: fixture.request, revision: fixture.cache.newRevision())
            await flush(fixture.cache)
            now = now.addingTimeInterval(elapsed)
            await assertMiss(fixture.cache, request: fixture.request)
        }
    }

    func test_malformedOversizedAndTooManyStoriesAreNotCached() async {
        let payloads: [NSDictionary] = [
            ["stories": "not an array"],
            ["stories": [["story_hash": "missing-required-fields"]]],
            ["stories": Array(repeating: makeStory(), count: 101)],
            ["stories": [makeStory(content: String(repeating: "x", count: StoryFirstPageCache.maximumSnapshotBytes + 1))]],
            ["stories": [makeStory()], "unsupported": Date()],
            ["stories": [makeStory()], "classifiers": "invalid metadata"],
            ["stories": [makeStory()], "user_profiles": ["invalid profile"]],
            ["stories": [makeStory()], "feed_authors": 42],
        ]
        for payload in payloads {
            let fixture = makeCache()
            fixture.cache.store(payload, request: fixture.request, revision: fixture.cache.newRevision())
            await assertMiss(fixture.cache, request: fixture.request)
        }
    }

    func test_corruptAndMisownedDiskEnvelopesAreMisses() async throws {
        for corrupt in [false, true] {
            let fixture = makeCache()
            fixture.cache.store(["stories": [makeStory()]], request: fixture.request, revision: fixture.cache.newRevision())
            await flush(fixture.cache)
            let path = fixture.directory.appendingPathComponent(fixture.request.cacheKey + ".json")
            if corrupt {
                try Data("broken json".utf8).write(to: path)
            } else {
                var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
                envelope["account"] = "other"
                try JSONSerialization.data(withJSONObject: envelope).write(to: path)
            }
            let relaunched = StoryFirstPageCache(directory: fixture.directory)
            await assertMiss(relaunched, request: fixture.request)
        }
    }

    func test_diskSnapshotCountStaysBounded() async throws {
        let fixture = makeCache()
        for index in 0..<(StoryFirstPageCache.maximumDiskEntries + 5) {
            let request = try XCTUnwrap(StoryFirstPageRequest(account: "owner", host: fixture.request.host,
                                                            url: fixture.request.host + "/reader/feed/\(index)/?page=1"))
            fixture.cache.store(["stories": [makeStory()]], request: request, revision: fixture.cache.newRevision())
        }
        await flush(fixture.cache)
        let files = try FileManager.default.contentsOfDirectory(at: fixture.directory, includingPropertiesForKeys: nil)
        XCTAssertLessThanOrEqual(files.filter { $0.pathExtension == "json" }.count, StoryFirstPageCache.maximumDiskEntries)
    }

    func test_clusterChildJournalDoesNotChangeParentReadState() async throws {
        let fixture = makeCache()
        var parent = makeStory()
        parent["cluster_stories"] = [["story_hash": "child", "read_status": 0]]
        fixture.cache.store(["stories": [parent]], request: fixture.request, revision: fixture.cache.newRevision())
        fixture.cache.record(story: ["story_hash": "child", "read_status": 1], fields: ["read_status"], account: "owner", host: fixture.request.host)
        let snapshot = try await requireSnapshot(fixture.cache, request: fixture.request)
        let actual = (fixture.cache.response(for: snapshot, provisional: true)?["stories"] as? [[String: Any]])?.first
        XCTAssertEqual(actual?["read_status"] as? Int, 0)
        XCTAssertEqual((actual?["cluster_stories"] as? [[String: Any]])?.first?["read_status"] as? Int, 1)
    }

    func test_missingAndCorruptJournalsRejectOtherwiseValidDiskSnapshot() async throws {
        for corruption in ["missing", "corrupt", "wrong owner"] {
            let fixture = makeCache()
            fixture.cache.store(["stories": [makeStory()]], request: fixture.request, revision: fixture.cache.newRevision())
            await flush(fixture.cache)
            let path = fixture.directory.appendingPathComponent(fixture.request.scopeKey + ".journal")
            if corruption == "missing" { try FileManager.default.removeItem(at: path) }
            else if corruption == "corrupt" { try Data("broken".utf8).write(to: path) }
            else {
                var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
                envelope["account"] = "another owner"
                try JSONSerialization.data(withJSONObject: envelope).write(to: path)
            }
            await assertMiss(StoryFirstPageCache(directory: fixture.directory), request: fixture.request)
        }
    }

    func test_uncleanForegroundTerminationRejectsSnapshotEvenIfLatestEditWasNotFlushed() async throws {
        let fixture = makeCache()
        fixture.cache.store(["stories": [makeStory()]], request: fixture.request, revision: fixture.cache.newRevision())
        // StoryFirstPageCacheTests.swift waits for the first published snapshot but intentionally skips the background checkpoint.
        _ = try await requireSnapshot(fixture.cache, request: fixture.request)
        let relaunched = StoryFirstPageCache(directory: fixture.directory)
        await assertMiss(relaunched, request: fixture.request)
    }

    func test_uncleanRelaunchDropsIncompletePersistedHistoryButKeepsNewSessionEdits() async throws {
        let fixture = makeCache()
        fixture.cache.store(["stories": [makeStory()]], request: fixture.request, revision: fixture.cache.newRevision())
        fixture.cache.record(story: ["story_hash": "cache-story", "read_status": 1], fields: ["read_status"], account: "owner", host: fixture.request.host)
        await flush(fixture.cache)
        fixture.cache.markForeground()
        let held = expectation(description: "old session journal write held")
        let gate = DispatchSemaphore(value: 0)
        fixture.cache.queue.async { held.fulfill(); _ = gate.wait(timeout: .now() + 5) }
        await fulfillment(of: [held], timeout: 2)
        defer { gate.signal() }
        fixture.cache.record(story: ["story_hash": "cache-story", "read_status": 0], fields: ["read_status"], account: "owner", host: fixture.request.host)
        let relaunched = StoryFirstPageCache(directory: fixture.directory)
        relaunched.record(story: ["story_hash": "cache-story", "user_tags": ["new session"]], fields: ["user_tags"], account: "owner", host: fixture.request.host)
        await assertMiss(relaunched, request: fixture.request)
        let response = relaunched.overlay(["stories": [makeStory()]], request: fixture.request, revision: 0)
        let story = try XCTUnwrap((response["stories"] as? [[String: Any]])?.first)
        XCTAssertEqual(story["read_status"] as? Int, 0, "An unclean journal may have lost a reversal, so its older persisted value is no longer safe to reassert")
        XCTAssertEqual(story["user_tags"] as? [String], ["new session"])
        await flush(relaunched)
    }

    func test_backgroundCheckpointIncludesEditThatArrivesWhileFlushIsPending() async throws {
        let fixture = makeCache()
        fixture.cache.store(["stories": [makeStory()]], request: fixture.request, revision: fixture.cache.newRevision())
        let finished = expectation(description: "background checkpoint")
        fixture.cache.flush { finished.fulfill() }
        fixture.cache.record(story: ["story_hash": "cache-story", "read_status": 1], fields: ["read_status"],
                             account: "owner", host: fixture.request.host)
        await fulfillment(of: [finished], timeout: 2)
        let relaunched = StoryFirstPageCache(directory: fixture.directory)
        let snapshot = try await requireSnapshot(relaunched, request: fixture.request)
        let story = (relaunched.response(for: snapshot, provisional: true)?["stories"] as? [[String: Any]])?.first
        XCTAssertEqual(story?["read_status"] as? Int, 1)
    }

    func test_cacheProvenanceNeverEntersStoredRawResponse() async throws {
        let fixture = makeCache()
        fixture.cache.store(["stories": [makeStory()]], request: fixture.request, revision: fixture.cache.newRevision())
        let snapshot = try await requireSnapshot(fixture.cache, request: fixture.request)
        let provisional = try XCTUnwrap(fixture.cache.response(for: snapshot, provisional: true))
        let raw = fixture.cache.response(for: snapshot, provisional: false)
        XCTAssertEqual((provisional["stories"] as? [[String: Any]])?.first?[StoryFirstPageCache.provisionalReadKey] as? Bool, true)
        XCTAssertNil((raw?["stories"] as? [[String: Any]])?.first?[StoryFirstPageCache.provisionalReadKey])
        await flush(fixture.cache)
        let data = try Data(contentsOf: fixture.directory.appendingPathComponent(fixture.request.cacheKey + ".json"))
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains(StoryFirstPageCache.provisionalReadKey))
    }

    func test_warmLookupAndLocalJournalCostAtFiveThousandEdits() async throws {
        let fixture = makeCache()
        fixture.cache.store(["stories": [makeStory()]], request: fixture.request, revision: fixture.cache.newRevision())
        _ = try await requireSnapshot(fixture.cache, request: fixture.request)
        let began = CACurrentMediaTime()
        for index in 0..<5_000 {
            fixture.cache.record(story: ["story_hash": "journal-benchmark-\(index)", "read_status": index % 2], fields: ["read_status"],
                                 account: "owner", host: fixture.request.host)
        }
        let elapsed = (CACurrentMediaTime() - began) * 1_000
        print("FIRST_PAGE_JOURNAL edits=5000 elapsed_ms=\(elapsed) per_edit_ms=\(elapsed / 5000)")
        XCTAssertLessThan(elapsed, 500, "A read mutation must not parse URLs, hash request keys, serialize the journal, or perform file I/O")
    }

    func test_foregroundMarkerBarrierFinishesBeforeLocalEditsCanResume() async throws {
        let fixture = makeCache()
        fixture.cache.store(["stories": [makeStory()]], request: fixture.request, revision: fixture.cache.newRevision())
        await flush(fixture.cache)
        let held = expectation(description: "marker queue held")
        let gate = DispatchSemaphore(value: 0)
        fixture.cache.markerQueue.async { held.fulfill(); _ = gate.wait(timeout: .now() + 2) }
        await fulfillment(of: [held], timeout: 2)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { gate.signal() }
        let began = CACurrentMediaTime()
        fixture.cache.markForeground()
        XCTAssertGreaterThan(CACurrentMediaTime() - began, 0.035)
        fixture.cache.record(story: ["story_hash": "cache-story", "read_status": 1], fields: ["read_status"], account: "owner", host: fixture.request.host)
        await assertMiss(StoryFirstPageCache(directory: fixture.directory), request: fixture.request)
    }

    func test_backgroundCleanCommitCannotOvertakeANewerForegroundGeneration() async throws {
        let fixture = makeCache()
        fixture.cache.store(["stories": [makeStory()]], request: fixture.request, revision: fixture.cache.newRevision())
        _ = try await requireSnapshot(fixture.cache, request: fixture.request)
        let held = expectation(description: "snapshot queue held")
        let gate = DispatchSemaphore(value: 0)
        fixture.cache.queue.async { held.fulfill(); _ = gate.wait(timeout: .now() + 2) }
        await fulfillment(of: [held], timeout: 2)
        let finished = expectation(description: "superseded background flush")
        fixture.cache.flush { finished.fulfill() }
        let began = CACurrentMediaTime()
        fixture.cache.markForeground()
        let elapsed = (CACurrentMediaTime() - began) * 1000
        print("FIRST_PAGE_FOREGROUND_MARKER elapsed_ms=\(elapsed)")
        XCTAssertLessThan(elapsed, 100, "The small marker must not wait for the general snapshot/journal queue")
        gate.signal()
        await fulfillment(of: [finished], timeout: 2)
        await assertMiss(StoryFirstPageCache(directory: fixture.directory), request: fixture.request)
    }

    func test_immutableNetworkResponseCanBeStoredOffMainAndImmediatelyReopened() async throws {
        let fixture = makeCache()
        let serialized = try JSONSerialization.data(withJSONObject: ["stories": [makeStory(content: String(repeating: "body ", count: 100_000))]])
        let response = try XCTUnwrap(JSONSerialization.jsonObject(with: serialized) as? NSDictionary)
        let stories = try XCTUnwrap(response["stories"] as? [NSDictionary])
        XCTAssertFalse(response is NSMutableDictionary)
        XCTAssertFalse(stories[0] is NSMutableDictionary)
        let began = CACurrentMediaTime()
        fixture.cache.storeAuthoritative(response, request: fixture.request, revision: fixture.cache.newRevision())
        let elapsed = (CACurrentMediaTime() - began) * 1000
        let edited = stories[0].mutableCopy() as! NSMutableDictionary
        edited["story_content"] = "Local replacement"
        edited["read_status"] = 1
        let snapshot = try await requireSnapshot(fixture.cache, request: fixture.request)
        let cached = (fixture.cache.response(for: snapshot, provisional: false)?["stories"] as? [[String: Any]])?.first
        XCTAssertEqual(cached?["story_content"] as? String, stories[0]["story_content"] as? String)
        XCTAssertEqual(cached?["read_status"] as? Int, 0)
        print("FIRST_PAGE_AUTHORITATIVE_ENQUEUE bytes=\(serialized.count) elapsed_ms=\(elapsed)")
        XCTAssertLessThan(elapsed, 10, "Immutable network response validation and copying must run off the rendering thread")
    }

    func test_fieldRemovalAndExplicitNullRemainDistinctAfterRelaunch() async throws {
        let fixture = makeCache()
        fixture.cache.store(["stories": [makeStory()]], request: fixture.request, revision: fixture.cache.newRevision())
        fixture.cache.record(story: ["story_hash": "cache-story", "user_tags": NSNull()], fields: ["user_tags", "starred_date"], account: "owner", host: fixture.request.host)
        await flush(fixture.cache)
        let relaunched = StoryFirstPageCache(directory: fixture.directory)
        let snapshot = try await requireSnapshot(relaunched, request: fixture.request)
        let story = (relaunched.response(for: snapshot, provisional: true)?["stories"] as? [[String: Any]])?.first
        XCTAssertTrue(story?["user_tags"] is NSNull)
        XCTAssertNil(story?["starred_date"])
    }

    func test_realReadUnreadReplacementWithJournalEnabledAtFiveThousandStories() {
        for journalEnabled in [false, true, false, true] {
            let app = NewsBlurAppDelegate()
            app.activeUsername = journalEnabled ? "first-page-replacement-" + UUID().uuidString : ""
            let collection = StoriesCollection()
            collection.appDelegate = app
            collection.activeFeedStories = (0..<5_000).map { ["story_hash": "replacement-\($0)", "read_status": 0, "story_content": "Benchmark body"] }
            let warm = collection.activeFeedStories.last as! [AnyHashable: Any]
            collection.markStoryRead(warm, feed: nil)
            let began = CACurrentMediaTime()
            for _ in 0..<20 {
                collection.markStoryUnread(collection.activeFeedStories.last as! [AnyHashable: Any], feed: nil)
                collection.markStoryRead(collection.activeFeedStories.last as! [AnyHashable: Any], feed: nil)
            }
            let elapsed = (CACurrentMediaTime() - began) * 1000
            print("FIRST_PAGE_REAL_REPLACEMENT stories=5000 replacements=40 journal_enabled=\(journalEnabled) elapsed_ms=\(elapsed) per_replace_ms=\(elapsed / 40)")
            XCTAssertEqual((collection.activeFeedStories.last as? [String: Any])?["read_status"] as? Int, 1)
            XCTAssertEqual(collection.activeFeedStories.count, 5_000)
        }
    }

    private func makeCache(now: @escaping () -> Date = Date.init) -> (cache: StoryFirstPageCache, request: StoryFirstPageRequest, directory: URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("first-page-cache-test-" + UUID().uuidString)
        let request = StoryFirstPageRequest(account: "owner", host: "https://example.test",
                                             url: "https://example.test/reader/feed/1/?include_hidden=true&page=1&order=newest&read_filter=all")!
        let cache = StoryFirstPageCache(directory: directory, now: now)
        addTeardownBlock {
            await withCheckedContinuation { continuation in cache.flush { continuation.resume() } }
            try? FileManager.default.removeItem(at: directory)
        }
        return (cache, request, directory)
    }

    private func makeStory(content: String = "<p>Original body</p>") -> [String: Any] {
        ["story_hash": "cache-story", "story_title": "Cached title", "story_content": content,
         "read_status": 0, "starred": false, "starred_date": "Old date", "user_tags": ["old"]]
    }

    private func lookup(_ cache: StoryFirstPageCache, request: StoryFirstPageRequest) async -> StoryFirstPageSnapshot? {
        await withCheckedContinuation { continuation in cache.lookup(request) { continuation.resume(returning: $0) } }
    }

    private func requireSnapshot(_ cache: StoryFirstPageCache, request: StoryFirstPageRequest) async throws -> StoryFirstPageSnapshot {
        let snapshot = await lookup(cache, request: request)
        return try XCTUnwrap(snapshot)
    }

    private func assertMiss(_ cache: StoryFirstPageCache, request: StoryFirstPageRequest) async {
        let snapshot = await lookup(cache, request: request)
        XCTAssertNil(snapshot)
    }

    private func flush(_ cache: StoryFirstPageCache) async {
        await withCheckedContinuation { continuation in cache.flush { continuation.resume() } }
    }
}
