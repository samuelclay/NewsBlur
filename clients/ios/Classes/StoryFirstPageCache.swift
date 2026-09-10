import CryptoKit
import Foundation
import UIKit

@objc final class StoryFirstPageRequest: NSObject {
    @objc let account: String
    @objc let host: String
    @objc let url: String
    let scopeKey: String
    let cacheKey: String

    @objc init?(account: String?, host: String?, url: String?) {
        guard let account, !account.isEmpty, account.utf8.count <= 256,
              let host, let base = URL(string: host), ["http", "https"].contains(base.scheme?.lowercased() ?? ""),
              base.host != nil, let url, url.hasPrefix(host + "/"), url.utf8.count <= 32_768 else { return nil }
        self.account = account
        self.host = host
        self.url = url
        scopeKey = Self.digest(account + "\u{0}" + host)
        cacheKey = Self.digest(account + "\u{0}" + host + "\u{0}" + url)
    }

    private static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

@objc final class StoryFirstPageSnapshot: NSObject {
    let request: StoryFirstPageRequest
    let response: NSDictionary
    let createdAt: TimeInterval
    let revision: UInt64
    let memoryCost: Int
    let journalEpoch: String

    init(request: StoryFirstPageRequest, response: NSDictionary, createdAt: TimeInterval, revision: UInt64, memoryCost: Int, journalEpoch: String) {
        self.request = request
        self.response = response
        self.createdAt = createdAt
        self.revision = revision
        self.memoryCost = memoryCost
        self.journalEpoch = journalEpoch
    }
}

@objc final class StoryFirstPageCache: NSObject {
    @objc static let shared = StoryFirstPageCache()
    static let provisionalReadKey = "_nb_provisional_read_state"
    static let snapshotTTL: TimeInterval = 30 * 60
    static let journalTTL: TimeInterval = 6 * 60 * 60
    static let maximumSnapshotBytes = 2 * 1_024 * 1_024
    static let maximumDiskBytes = 32 * 1_024 * 1_024
    static let maximumDiskEntries = 64
    static let maximumJournalEntries = 8_192
    static let maximumJournalCost = 2 * 1_024 * 1_024
    static let maximumJournalScopes = 8

    private let directory: URL
    private let now: () -> Date
    let queue = DispatchQueue(label: "com.newsblur.first-page-cache", qos: .utility)
    private let lock = NSLock()
    let markerQueue = DispatchQueue(label: "com.newsblur.first-page-session", qos: .userInitiated)
    private var previousSessionWasClean = false
    private var foregroundGeneration: UInt64 = 0
    private var isForeground = true
    private var markerIsWritable = false
    private let snapshots = NSCache<NSString, StoryFirstPageSnapshot>()
    private var journals: [String: Journal] = [:]
    private var lastRevision: UInt64 = 0
    private var lastMutationRequest: StoryFirstPageRequest?
    private let sessionID = UUID().uuidString
    private var observers: [NSObjectProtocol] = []

    override convenience init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.init(directory: caches.appendingPathComponent("StoryFirstPages-v1", isDirectory: true))
    }

    init(directory: URL, now: @escaping () -> Date = Date.init) {
        self.directory = directory
        self.now = now
        super.init()
        snapshots.countLimit = 16
        snapshots.totalCostLimit = 16 * 1_024 * 1_024
        markerQueue.sync {
            if let data = readBounded(directory.appendingPathComponent("session.marker"), maximumBytes: 1_024),
               let marker = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                previousSessionWasClean = marker["format"] as? Int == 1 && marker["clean"] as? Bool == true
            }
        }
        markForeground()
        observers = [
            NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
                self?.flush(completion: {})
            },
            NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
                self?.markForeground()
            }
        ]
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    func markForeground() {
        lock.lock()
        foregroundGeneration += 1
        isForeground = true
        let generation = foregroundGeneration
        lock.unlock()
        // StoryFirstPageCache.swift uses one tiny foreground barrier, isolated from snapshot/journal I/O, so a crash cannot reuse a previous clean marker.
        markerQueue.sync {
            let written = writeMarker(clean: false, generation: generation)
            lock.lock()
            markerIsWritable = written
            if !written { previousSessionWasClean = false }
            lock.unlock()
        }
    }

    private func writeMarker(clean: Bool, generation: UInt64) -> Bool {
        let marker: [String: Any] = ["format": 1, "session": sessionID, "generation": generation, "clean": clean]
        guard let data = try? JSONSerialization.data(withJSONObject: marker) else { return false }
        return write(data, to: directory.appendingPathComponent("session.marker"))
    }

    @objc func newRevision() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        lastRevision = max(lastRevision + 1, UInt64(max(0, now().timeIntervalSince1970) * 1_000_000))
        return lastRevision
    }

    @objc(lookupRequest:completion:)
    func lookup(_ request: StoryFirstPageRequest, completion: @escaping (StoryFirstPageSnapshot?) -> Void) {
        lock.lock()
        let journal = journalForRequest(request)
        let warm = snapshots.object(forKey: request.cacheKey as NSString)
        let journalLoaded = journal.loaded
        lock.unlock()
        if journalLoaded, let warm, isFresh(warm) {
            completion(warm)
            return
        }
        queue.async { [self] in
            loadJournal(request)
            let snapshot = warm.flatMap { isFresh($0) ? $0 : nil } ?? readSnapshot(request)
            DispatchQueue.main.async { completion(snapshot) }
        }
    }

    @objc(storeResponse:request:revision:)
    func store(_ response: NSDictionary, request: StoryFirstPageRequest, revision: UInt64) {
        guard let (response, cost) = Self.validatedResponse(response) else { return }
        let createdAt = now().timeIntervalSince1970
        queue.async { [self] in storeValidated(response, cost: cost, request: request, revision: revision, createdAt: createdAt) }
    }

    @objc(storeAuthoritativeResponse:request:revision:)
    func storeAuthoritative(_ response: NSDictionary, request: StoryFirstPageRequest, revision: UInt64) {
        // StoryFirstPageCache.swift receives AFJSONResponseSerializer's immutable JSON containers here. StoriesCollection.m replaces dictionaries for local edits.
        let ownedResponse = response.copy() as! NSDictionary
        let createdAt = now().timeIntervalSince1970
        queue.async { [self] in
            guard let (validated, cost) = Self.validatedResponse(ownedResponse) else { return }
            storeValidated(validated, cost: cost, request: request, revision: revision, createdAt: createdAt)
        }
    }

    private func storeValidated(_ response: NSDictionary, cost: Int, request: StoryFirstPageRequest, revision: UInt64, createdAt: TimeInterval) {
        loadJournal(request)
        lock.lock()
        let epoch = journalForRequest(request).epoch
        lock.unlock()
        let snapshot = StoryFirstPageSnapshot(request: request, response: response, createdAt: createdAt,
                                             revision: revision, memoryCost: cost, journalEpoch: epoch)
        snapshots.setObject(snapshot, forKey: request.cacheKey as NSString, cost: cost)
        let envelope: [String: Any] = ["format": 1, "account": request.account, "host": request.host,
                                       "url": request.url, "created": snapshot.createdAt,
                                       "revision": revision, "journal_epoch": epoch, "response": response]
        guard let data = try? JSONSerialization.data(withJSONObject: envelope), data.count <= Self.maximumSnapshotBytes else { return }
        persistJournal(request)
        write(data, to: snapshotURL(request))
        trimDiskSnapshots()
    }

    @objc(responseForSnapshot:provisional:)
    func response(for snapshot: StoryFirstPageSnapshot, provisional: Bool) -> NSDictionary? {
        guard isFresh(snapshot) else { return nil }
        return overlay(snapshot.response, request: snapshot.request, revision: snapshot.revision, provisional: provisional)
    }

    @objc(overlayResponse:request:revision:)
    func overlay(_ response: NSDictionary, request: StoryFirstPageRequest, revision: UInt64) -> NSDictionary {
        overlay(response, request: request, revision: revision, provisional: false)
    }

    @objc(recordStory:fields:account:host:)
    func record(story: NSDictionary, fields: [String], account: String?, host: String?) {
        guard let hash = story["story_hash"] as? String, !hash.isEmpty, hash.utf8.count <= 256,
              let account, !account.isEmpty, let host else { return }
        let timestamp = now().timeIntervalSince1970
        lock.lock()
        let request: StoryFirstPageRequest
        if let recent = lastMutationRequest, recent.account == account, recent.host == host {
            request = recent
        } else if let validated = StoryFirstPageRequest(account: account, host: host, url: host + "/") {
            request = validated
            lastMutationRequest = validated
        } else { lock.unlock(); return }
        let journal = journalForRequest(request)
        for field in fields {
            let original = story[field] ?? NSNull()
            let value: Any
            if let tags = original as? [String] { value = Array(tags) }
            else if let text = original as? String { value = String(text) }
            else { value = original }
            guard Self.validMutationValue(value, field: field) else { continue }
            lastRevision = max(lastRevision + 1, UInt64(max(0, timestamp) * 1_000_000))
            journal.append(Mutation(hash: hash, field: field, value: value, removed: story[field] == nil, revision: lastRevision, createdAt: timestamp))
        }
        let schedule = !journal.writeScheduled
        journal.writeScheduled = true
        lock.unlock()
        if schedule {
            queue.asyncAfter(deadline: .now() + 0.1) { [self] in
                loadJournal(request)
                persistJournal(request)
            }
        }
    }

    func flush(completion: @escaping () -> Void) {
        lock.lock()
        isForeground = false
        let generation = foregroundGeneration
        lock.unlock()
        queue.async { [self] in
            var completed = false
            while !completed {
                lock.lock()
                let requests = journals.values.map(\.request)
                lock.unlock()
                for request in requests {
                    loadJournal(request)
                    persistJournal(request, clean: true)
                }
                markerQueue.sync {
                    lock.lock()
                    // StoryFirstPageCache.swift commits clean only after the full journal and only for the same background generation.
                    if foregroundGeneration != generation || isForeground || !markerIsWritable {
                        completed = true
                    } else if !journals.values.contains(where: { $0.writeScheduled }) {
                        _ = writeMarker(clean: true, generation: generation)
                        completed = true
                    }
                    lock.unlock()
                }
            }
            DispatchQueue.main.async(execute: completion)
        }
    }

    private func overlay(_ response: NSDictionary, request: StoryFirstPageRequest, revision: UInt64, provisional: Bool) -> NSDictionary {
        let timestamp = now().timeIntervalSince1970
        func storyWithEdits(_ story: NSDictionary) -> NSDictionary {
            let updated = story.mutableCopy() as! NSMutableDictionary
            if let hash = story["story_hash"] as? String {
                lock.lock()
                let mutations = journals[request.scopeKey]?.latest[hash] ?? [:]
                lock.unlock()
                for mutation in mutations.values where mutation.revision > revision && timestamp >= mutation.createdAt && timestamp - mutation.createdAt <= Self.journalTTL {
                    if mutation.removed { updated.removeObject(forKey: mutation.field) }
                    else { updated[mutation.field] = mutation.value }
                }
            }
            if let children = story["cluster_stories"] as? [NSDictionary] {
                updated["cluster_stories"] = children.map(storyWithEdits)
            }
            if provisional { updated[Self.provisionalReadKey] = true }
            else { updated.removeObject(forKey: Self.provisionalReadKey) }
            return updated.copy() as! NSDictionary
        }
        let result = response.mutableCopy() as! NSMutableDictionary
        if let stories = response["stories"] as? [NSDictionary] { result["stories"] = stories.map(storyWithEdits) }
        return result.copy() as! NSDictionary
    }

    private func isFresh(_ snapshot: StoryFirstPageSnapshot) -> Bool {
        let age = now().timeIntervalSince1970 - snapshot.createdAt
        lock.lock()
        let journal = journals[snapshot.request.scopeKey]
        let covered = journal?.loaded == true && journal?.persistenceReady == true && journal?.epoch == snapshot.journalEpoch && snapshot.revision >= (journal?.floorRevision ?? UInt64.max)
        lock.unlock()
        return age >= 0 && age <= Self.snapshotTTL && covered
    }

    private func journalForRequest(_ request: StoryFirstPageRequest) -> Journal {
        if let existing = journals[request.scopeKey] { existing.lastAccess = now().timeIntervalSince1970; return existing }
        if journals.count >= Self.maximumJournalScopes, let oldest = journals.values.min(by: { $0.lastAccess < $1.lastAccess }) {
            // StoryFirstPageCache.swift bounds resident scopes; pending writes retain their immutable ring snapshot until the utility queue saves it.
            let rows = oldest.ring
            let epoch = oldest.loaded ? oldest.epoch : UUID().uuidString
            let floor = oldest.floorRevision
            let oldRequest = oldest.request
            queue.async { [self] in writeJournal(rows.compactMap { $0 }, request: oldRequest, epoch: epoch, floor: floor) }
            journals[oldRequest.scopeKey] = nil
        }
        let journal = Journal(request: request)
        journal.lastAccess = now().timeIntervalSince1970
        journals[request.scopeKey] = journal
        return journal
    }

    private func loadJournal(_ request: StoryFirstPageRequest) {
        lock.lock()
        let journal = journalForRequest(request)
        let loaded = journal.loaded
        lock.unlock()
        guard !loaded else { return }
        let timestamp = now().timeIntervalSince1970
        lock.lock()
        let mayRestorePreviousSession = previousSessionWasClean
        lock.unlock()
        var persisted: [Mutation] = []
        var floor: UInt64 = 0
        var epoch = UUID().uuidString
        if let data = readBounded(journalURL(request), maximumBytes: Self.maximumJournalCost),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           object["format"] as? Int == 1, object["account"] as? String == request.account,
           object["host"] as? String == request.host, let persistedEpoch = object["epoch"] as? String, UUID(uuidString: persistedEpoch) != nil,
           let rows = object["mutations"] as? [[String: Any]], rows.count <= Self.maximumJournalEntries {
            if mayRestorePreviousSession || object["session"] as? String == sessionID { epoch = persistedEpoch }
            floor = (object["floor"] as? NSNumber)?.uint64Value ?? 0
            for row in rows {
                guard let hash = row["hash"] as? String, !hash.isEmpty, hash.utf8.count <= 256,
                      let field = row["field"] as? String, let value = row["value"], Self.validMutationValue(value, field: field),
                      let revision = row["revision"] as? NSNumber, let created = row["created"] as? TimeInterval,
                      created <= timestamp else { epoch = UUID().uuidString; persisted.removeAll(); break }
                if timestamp - created > Self.journalTTL { floor = max(floor, revision.uint64Value); continue }
                persisted.append(Mutation(hash: hash, field: field, value: value, removed: row["removed"] as? Bool ?? false, revision: revision.uint64Value, createdAt: created))
            }
        }
        lock.lock()
        let pending = journal.orderedMutations()
        journal.clear()
        journal.floorRevision = floor
        journal.epoch = epoch
        journal.writeScheduled = true
        for mutation in (persisted + pending).sorted(by: { $0.revision < $1.revision }) { journal.append(mutation) }
        journal.loaded = true
        lastRevision = max(lastRevision, journal.orderedMutations().last?.revision ?? 0)
        lock.unlock()
        // StoryFirstPageCache.swift persists the dirty-session marker before publishing a disk snapshot.
        persistJournal(request)
    }

    private func persistJournal(_ request: StoryFirstPageRequest, clean: Bool = false) {
        lock.lock()
        let journal = journalForRequest(request)
        guard journal.writeScheduled || clean else { lock.unlock(); return }
        let mutations = journal.ring
        let floor = journal.floorRevision
        let epoch = journal.epoch
        journal.writeScheduled = false
        lock.unlock()
        let capturedRevision = mutations.compactMap { $0?.revision }.max() ?? 0
        writeJournal(mutations.compactMap { $0 }, request: request, epoch: epoch, floor: floor, clean: clean)
        if clean {
            lock.lock()
            let changed = journal.writeScheduled || journal.latestRevision != capturedRevision
            lock.unlock()
            if changed { persistJournal(request, clean: true) }
        }
    }

    private func writeJournal(_ mutations: [Mutation], request: StoryFirstPageRequest, epoch: String, floor: UInt64, clean: Bool = false) {
        let rows = mutations.sorted { $0.revision < $1.revision }.map { mutation -> [String: Any] in
            ["hash": mutation.hash, "field": mutation.field, "value": mutation.value, "removed": mutation.removed,
             "revision": mutation.revision, "created": mutation.createdAt]
        }
        let envelope: [String: Any] = ["format": 1, "account": request.account, "host": request.host,
                                       "epoch": epoch, "floor": floor, "mutations": rows, "session": sessionID, "clean": clean]
        if let data = try? JSONSerialization.data(withJSONObject: envelope), data.count <= Self.maximumJournalCost {
            let saved = write(data, to: journalURL(request))
            lock.lock()
            if journals[request.scopeKey]?.epoch == epoch { journals[request.scopeKey]?.persistenceReady = saved }
            lock.unlock()
            trimDiskJournals()
        }
    }

    private func readSnapshot(_ request: StoryFirstPageRequest) -> StoryFirstPageSnapshot? {
        guard let data = readBounded(snapshotURL(request), maximumBytes: Self.maximumSnapshotBytes),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["format"] as? Int == 1, object["account"] as? String == request.account,
              object["host"] as? String == request.host, object["url"] as? String == request.url,
              let created = object["created"] as? TimeInterval, let revision = object["revision"] as? NSNumber,
              let epoch = object["journal_epoch"] as? String,
              let response = object["response"] as? NSDictionary, let (validated, cost) = Self.validatedResponse(response) else { return nil }
        let snapshot = StoryFirstPageSnapshot(request: request, response: validated, createdAt: created,
                                             revision: revision.uint64Value, memoryCost: cost, journalEpoch: epoch)
        guard isFresh(snapshot) else { return nil }
        snapshots.setObject(snapshot, forKey: request.cacheKey as NSString, cost: cost)
        return snapshot
    }

    private static func validatedResponse(_ response: NSDictionary) -> (NSDictionary, Int)? {
        guard let stories = response["stories"] as? [NSDictionary], stories.count <= 100 else { return nil }
        var objects = 0
        var bytes = 0
        func copyJSON(_ value: Any, depth: Int) -> Any? {
            objects += 1
            guard depth <= 16, objects <= 30_000 else { return nil }
            if let text = value as? String {
                bytes += text.utf8.count
                guard bytes <= maximumSnapshotBytes else { return nil }
                return String(text)
            }
            if value is NSNull { return NSNull() }
            if let number = value as? NSNumber {
                guard number.doubleValue.isFinite else { return nil }
                bytes += 16
                return number.copy()
            }
            if let dictionary = value as? NSDictionary {
                var copied: [String: Any] = [:]
                for (key, child) in dictionary {
                    guard let key = key as? String, key != provisionalReadKey,
                          let copiedChild = copyJSON(child, depth: depth + 1) else { return nil }
                    bytes += key.utf8.count + 8
                    copied[key] = copiedChild
                }
                return copied as NSDictionary
            }
            if let array = value as? [Any] {
                guard array.count <= 2_000 else { return nil }
                var copied: [Any] = []
                for child in array {
                    guard let copiedChild = copyJSON(child, depth: depth + 1) else { return nil }
                    copied.append(copiedChild)
                }
                return copied as NSArray
            }
            return nil
        }
        for story in stories {
            guard let hash = story["story_hash"] as? String, !hash.isEmpty, hash.utf8.count <= 256,
                  story["story_title"] is String, story["story_content"] is String,
                  let read = story["read_status"] as? NSNumber, read.doubleValue == 0 || read.doubleValue == 1 else { return nil }
        }
        guard let copied = copyJSON(response, depth: 0) as? NSDictionary, bytes <= maximumSnapshotBytes else { return nil }
        // StoryFirstPageCache.swift charges decoded containers and UTF-16 strings as well as serialized text.
        return (copied, bytes * 2 + objects * 64)
    }

    @objc(publicStory:) static func publicStory(_ story: NSDictionary) -> NSDictionary {
        guard story[provisionalReadKey] != nil else { return story }
        let clean = story.mutableCopy() as! NSMutableDictionary
        clean.removeObject(forKey: provisionalReadKey)
        if let children = story["cluster_stories"] as? [NSDictionary] { clean["cluster_stories"] = children.map(publicStory) }
        return clean.copy() as! NSDictionary
    }

    private static func validMutationValue(_ value: Any, field: String) -> Bool {
        switch field {
        case "read_status", "starred":
            guard let number = value as? NSNumber else { return false }
            return number.doubleValue == 0 || number.doubleValue == 1
        case "starred_date": return value is NSNull || (value as? String).map { $0.utf8.count <= 256 } == true
        case "user_tags":
            if value is NSNull { return true }
            guard let tags = value as? [String], tags.count <= 100 else { return false }
            return tags.allSatisfy { $0.utf8.count <= 256 }
        default: return false
        }
    }

    private func readBounded(_ url: URL, maximumBytes: Int) -> Data? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber, size.intValue <= maximumBytes else { return nil }
        guard let data = try? Data(contentsOf: url), data.count <= maximumBytes else { return nil }
        return data
    }

    @discardableResult private func write(_ data: Data, to url: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return true
        } catch { return false } // StoryFirstPageCache.swift treats disk failures as cache misses.
    }

    private func snapshotURL(_ request: StoryFirstPageRequest) -> URL { directory.appendingPathComponent(request.cacheKey + ".json") }
    private func journalURL(_ request: StoryFirstPageRequest) -> URL { directory.appendingPathComponent(request.scopeKey + ".journal") }

    private func trimDiskSnapshots() {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys))) ?? []
        let snapshots = files.filter { $0.pathExtension == "json" }.compactMap { url -> (URL, Date, Int)? in
            guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
            return (url, values.contentModificationDate ?? .distantPast, values.fileSize ?? 0)
        }.sorted { $0.1 > $1.1 }
        var bytes = 0
        for (index, item) in snapshots.enumerated() {
            bytes += item.2
            if index >= Self.maximumDiskEntries || bytes > Self.maximumDiskBytes || now().timeIntervalSince(item.1) > Self.snapshotTTL {
                try? FileManager.default.removeItem(at: item.0)
            }
        }
    }

    private func trimDiskJournals() {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys))) ?? []
        let ordered = files.filter { $0.pathExtension == "journal" }.map { url in
            (url, (try? url.resourceValues(forKeys: keys).contentModificationDate) ?? .distantPast)
        }.sorted { $0.1 > $1.1 }
        for (index, item) in ordered.enumerated() where index >= Self.maximumJournalScopes || now().timeIntervalSince(item.1) > Self.journalTTL {
            try? FileManager.default.removeItem(at: item.0)
        }
    }

    private struct Mutation {
        let hash: String
        let field: String
        let value: Any
        let removed: Bool
        let revision: UInt64
        let createdAt: TimeInterval
        var memoryCost: Int {
            let valueCost = (value as? String)?.utf8.count ?? (value as? [String])?.reduce(0) { $0 + $1.utf8.count + 32 } ?? 16
            return 256 + 2 * (hash.utf8.count + field.utf8.count + valueCost)
        }
    }

    private final class Journal {
        let request: StoryFirstPageRequest
        var latest: [String: [String: Mutation]] = [:]
        var ring = [Mutation?](repeating: nil, count: StoryFirstPageCache.maximumJournalEntries)
        var cursor = 0
        var count = 0
        var cost = 0
        var epoch = UUID().uuidString
        var lastAccess: TimeInterval = 0
        var floorRevision: UInt64 = 0
        var loaded = false
        var persistenceReady = false
        var writeScheduled = false
        var latestRevision: UInt64 = 0
        init(request: StoryFirstPageRequest) { self.request = request }
        func append(_ mutation: Mutation) {
            while count > 0 && (count == ring.count || cost + mutation.memoryCost > StoryFirstPageCache.maximumJournalCost) {
                let first = (cursor - count + ring.count) % ring.count
                if let evicted = ring[first] {
                    floorRevision = max(floorRevision, evicted.revision)
                    if latest[evicted.hash]?[evicted.field]?.revision == evicted.revision {
                        latest[evicted.hash]?[evicted.field] = nil
                        if latest[evicted.hash]?.isEmpty == true { latest[evicted.hash] = nil }
                    }
                    cost -= evicted.memoryCost
                    ring[first] = nil
                }
                count -= 1
            }
            ring[cursor] = mutation
            cursor = (cursor + 1) % ring.count
            count += 1
            cost += mutation.memoryCost
            latest[mutation.hash, default: [:]][mutation.field] = mutation
            latestRevision = max(latestRevision, mutation.revision)
        }
        func orderedMutations() -> [Mutation] { ring.compactMap { $0 }.sorted { $0.revision < $1.revision } }
        func clear() {
            latest.removeAll()
            ring = [Mutation?](repeating: nil, count: StoryFirstPageCache.maximumJournalEntries)
            cursor = 0
            count = 0
            cost = 0
            latestRevision = 0
        }
    }
}

@objcMembers final class StoryFirstPageLoad: NSObject {
    let request: StoryFirstPageRequest
    let revision: UInt64
    let generation: UInt
    var pending = true
    var authoritativeReceived = false
    var displayedSnapshot = false

    init(request: StoryFirstPageRequest, revision: UInt64, generation: UInt) {
        self.request = request
        self.revision = revision
        self.generation = generation
    }

    @objc static func continueOnMain(_ callback: @escaping () -> Void) {
        if Thread.isMainThread { callback() } else { DispatchQueue.main.async(execute: callback) }
    }

    func matches(account: String?, host: String?, url: String?, generation: UInt) -> Bool {
        self.generation == generation && request.account == account && request.host == host && request.url == url
    }
}
