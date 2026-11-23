//
//  RealtimeUpdates.swift
//  NewsBlur
//
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import OSLog
import UIKit

/// A message on the user's own channel, which apps/reader/models.py, apps/reader/views.py and apps/social/models.py
/// publish and node/unread_counts.coffee forwards as `user:update`. The web reads the same messages in
/// media/js/newsblur/reader/reader.js handle_realtime_update.
enum RealtimeUserMessage: Equatable {
    case storyRead(hash: String)
    case storyUnread(hash: String)
    /// `feed:<id>` names one feed whose counts changed, and apps/analyzer/views.py joins several with commas.
    case feedCounts(feedIds: [String])
    /// `social:<user_id>`, kept as the `social:<user_id>` id the app files blurblogs under.
    case socialCounts(feedId: String)
    /// `refresh:<id>,<id>` asks for those feeds' counts again.
    case refreshCounts(feedIds: [String])
    case starred(hash: String)
    case unstarred(hash: String)
    case interactionNew
    /// `reload:feeds` or `reload:<feed_id>`: subscriptions or folders changed on another device.
    case reloadFeeds
    case ignored

    init(_ message: String) {
        func remainder(after prefix: String) -> String? {
            message.hasPrefix(prefix) ? String(message.dropFirst(prefix.count)) : nil
        }
        func feedIds(in list: String) -> [String] {
            list.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }

        if let hash = remainder(after: "story:read:"), !hash.isEmpty {
            self = .storyRead(hash: hash)
        } else if let hash = remainder(after: "story:unread:"), !hash.isEmpty {
            self = .storyUnread(hash: hash)
        } else if let hash = remainder(after: "story:starred") {
            self = .starred(hash: String(hash.drop(while: { $0 == ":" })))
        } else if let hash = remainder(after: "story:unstarred") {
            self = .unstarred(hash: String(hash.drop(while: { $0 == ":" })))
        } else if let list = remainder(after: "feed:") {
            let ids = feedIds(in: list)
            self = ids.isEmpty ? .ignored : .feedCounts(feedIds: ids)
        } else if let userId = remainder(after: "social:"), !userId.isEmpty {
            self = .socialCounts(feedId: "social:\(userId)")
        } else if let list = remainder(after: "refresh:") {
            let ids = feedIds(in: list)
            self = ids.isEmpty ? .ignored : .refreshCounts(feedIds: ids)
        } else if message == "interaction:new" {
            self = .interactionNew
        } else if message.hasPrefix("reload:") {
            self = .reloadFeeds
        } else {
            self = .ignored
        }
    }
}

/// Collects feeds whose unread counts need refreshing and asks for them together, so a burst of reads on another
/// device, or a folder marked read, becomes one `/reader/feed_unread_count` request instead of one per feed.
@MainActor final class RealtimeCountRefreshQueue {
    /// Feeds due within this long of the earliest one go out in the same request.
    static let batchWindow: TimeInterval = 1
    /// Keeps each GET's query string well under the web servers' header limits.
    static let maximumFeedsPerRequest = 100

    private var dueDates: [String: Date] = [:]
    private var scheduledFireDate: Date?
    private var cancelScheduled: (() -> Void)?
    private let now: () -> Date
    private let schedule: (TimeInterval, @escaping () -> Void) -> () -> Void
    private let send: ([String]) -> Void

    /// `schedule` runs its work after the delay and returns a way to cancel it. NewsBlurTests pass a manual clock.
    init(now: @escaping () -> Date = Date.init,
         schedule: @escaping (TimeInterval, @escaping () -> Void) -> () -> Void = RealtimeCountRefreshQueue.mainQueueSchedule,
         send: @escaping ([String]) -> Void) {
        self.now = now
        self.schedule = schedule
        self.send = send
    }

    nonisolated static func mainQueueSchedule(_ delay: TimeInterval, _ work: @escaping () -> Void) -> () -> Void {
        let item = DispatchWorkItem(block: work)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        return { item.cancel() }
    }

    var pendingFeedIds: Set<String> { Set(dueDates.keys) }

    /// Ask for these feeds' counts after `delay`. A feed already waiting keeps the earlier of its two due dates.
    func enqueue(_ feedIds: [String], delay: TimeInterval) {
        guard !feedIds.isEmpty else { return }
        let dueDate = now().addingTimeInterval(max(0, delay))
        for feedId in feedIds {
            dueDates[feedId] = min(dueDates[feedId] ?? dueDate, dueDate)
        }
        reschedule()
    }

    func cancelAll() {
        dueDates = [:]
        cancelScheduled?()
        cancelScheduled = nil
        scheduledFireDate = nil
    }

    private func reschedule() {
        guard let earliest = dueDates.values.min() else { return }
        if let scheduledFireDate, scheduledFireDate <= earliest { return }
        cancelScheduled?()
        scheduledFireDate = earliest
        cancelScheduled = schedule(max(0, earliest.timeIntervalSince(now()))) { [weak self] in
            MainActor.assumeIsolated { self?.fire() }
        }
    }

    private func fire() {
        scheduledFireDate = nil
        cancelScheduled = nil
        let cutoff = now().addingTimeInterval(Self.batchWindow)
        let ready = dueDates.filter { $0.value <= cutoff }.map(\.key).sorted()
        for feedId in ready { dueDates[feedId] = nil }
        var remaining = ready[...]
        while !remaining.isEmpty {
            send(Array(remaining.prefix(Self.maximumFeedsPerRequest)))
            remaining = remaining.dropFirst(Self.maximumFeedsPerRequest)
        }
        reschedule()
    }
}

/// The open story list, as far as stories arriving over the socket are concerned.
struct RealtimeStoryList: Equatable {
    /// Changes whenever the list would load different stories: another site or folder, order, filter or focus.
    let key: String
    let feedIds: Set<String>
    let oldestFirst: Bool
    let unreadOnly: Bool
    /// `NewsBlurAppDelegate.selectedIntelligence`: 1 shows Focus stories, 0 unread, -1 everything.
    let intelligence: Int
    let showHiddenStories: Bool
    /// The oldest-first list has loaded its last page, so a new story belongs at its end rather than in a page
    /// that hasn't loaded yet.
    let loadedLastPage: Bool
}

/// Decides which stories that arrived over the socket join the open list.
enum RealtimeNewStories {
    /// The web ignores stories dated more than an hour ahead (media/js/newsblur/views/dashboard_river_view.js).
    static let futureTolerance: TimeInterval = 60 * 60

    /// How many announced stories the list keeps fetched for the pill, and the most a tap puts into the list: the
    /// newest-dated waiting stories, or the oldest-dated in an oldest-first list (RealtimeNewStoryBuffer). The rest are
    /// only counted with their dates, so a list left open overnight doesn't fetch every story announced since, and a
    /// tap shows the 20 at once (NewStoriesNewestPage.swift). The web and Android use the same number.
    static let prefetchCap = 20

    /// The per-device setting "Show new stories as they arrive" (PreferencesView.swift). Off, the open list gains new
    /// stories only when it loads again; read state, saved state and unread counts keep syncing.
    static let settingKey = "show_new_stories_as_they_arrive"

    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: settingKey) as? Bool ?? true
    }

    /// Whether a `feed:story:new` announcement is worth fetching for the open list.
    static func shouldFetch(storyHash: String, feedId: String, timestamp: TimeInterval, list: RealtimeStoryList,
                            knownHashes: Set<String>, listedTimestamps: [TimeInterval], now: Date) -> Bool {
        guard list.feedIds.contains(feedId), !knownHashes.contains(storyHash),
              timestamp <= now.timeIntervalSince1970 + futureTolerance else { return false }
        if list.oldestFirst {
            // Until the last page loads, pagination brings the story in at the right place.
            return list.loadedLastPage
        }
        // A newest-first list only grows at the top. A story older than every loaded one arrives with a later page.
        if let oldest = listedTimestamps.min(), timestamp < oldest { return false }
        return true
    }

    /// The fetched stories that belong in the list, in its order: exactly the ones the pill counts
    /// (`isOffered`). Read stories stay out of an unread list.
    static func insertable(_ stories: [[String: Any]], list: RealtimeStoryList, knownHashes: Set<String>) -> [[String: Any]] {
        var seen = knownHashes
        var accepted: [[String: Any]] = []
        for story in stories {
            guard let hash = story["story_hash"] as? String, !seen.contains(hash),
                  list.feedIds.contains(feedId(of: story)), isOffered(story, list: list) else { continue }
            if list.unreadOnly && intValue(story["read_status"]) != 0 { continue }
            seen.insert(hash)
            accepted.append(story)
        }
        return accepted.sorted { first, second in
            let firstTimestamp = timestamp(of: first), secondTimestamp = timestamp(of: second)
            return list.oldestFirst ? firstTimestamp < secondTimestamp : firstTimestamp > secondTimestamp
        }
    }

    /// /reader/river_stories?h= answers with a placeholder unread state; read state from other devices replaces it.
    static func applying(_ readOverrides: [String: Bool], to stories: [[String: Any]]) -> [[String: Any]] {
        guard !readOverrides.isEmpty else { return stories }
        return stories.map { story -> [String: Any] in
            guard let hash = story["story_hash"] as? String, let read = readOverrides[hash] else { return story }
            var corrected = story
            corrected["read_status"] = read ? 1 : 0
            return corrected
        }
    }

    /// How many of these stories the pill offers.
    static func visibleCount(_ stories: [[String: Any]], list: RealtimeStoryList) -> Int {
        stories.filter { isOffered($0, list: list) }.count
    }

    /// Whether the pill offers this story. Unlike a page of the list, the pill never brings in a story the reader's
    /// classifiers hide (score below 0), even in a list showing every story or hidden ones; in Focus it needs a
    /// Focus score. Hidden stories still appear when the list loads.
    static func isOffered(_ story: [String: Any], list: RealtimeStoryList) -> Bool {
        let intelligence = story["intelligence"] as? [AnyHashable: Any] ?? [:]
        let score = NewsBlurAppDelegate.computeStoryScore(intelligence)
        guard score >= 0 else { return false }
        return boolValue(story["sticky"]) || score >= max(list.intelligence, 0)
    }

    static func feedId(of story: [String: Any]) -> String {
        story["story_feed_id"].map { "\($0)" } ?? ""
    }

    static func timestamp(of story: [String: Any]) -> TimeInterval {
        if let number = story["story_timestamp"] as? NSNumber { return number.doubleValue }
        if let text = story["story_timestamp"] as? String { return TimeInterval(text) ?? 0 }
        return 0
    }

    private static func intValue(_ value: Any?) -> Int {
        if let number = value as? NSNumber { return number.intValue }
        if let text = value as? String { return Int(text) ?? 0 }
        return 0
    }

    private static func boolValue(_ value: Any?) -> Bool {
        if let number = value as? NSNumber { return number.boolValue }
        if let text = value as? String { return text == "1" || text.lowercased() == "true" }
        return false
    }
}

/// The open list's announced stories, waiting for the pill: those about to be fetched, those fetched, and those only
/// counted. The pill keeps the stories a tap would show fetched: the newest-dated waiting stories, or the oldest-dated
/// in an oldest-first list, at most `RealtimeNewStories.prefetchCap` of them, so a tap never waits on the network. A
/// story that ranks among them is fetched as soon as it's announced and, once it lands, pushes the last of them down to
/// a count; one that doesn't is only counted. The web (media/js/newsblur/reader/reader.js) and Android
/// (RealtimeUpdates.kt) keep the same 20.
struct RealtimeNewStoryBuffer {
    /// Announced stories waiting for the next batched fetch.
    private(set) var pendingHashes: [String] = []
    /// Fetched stories that belong in the list, in its order.
    private(set) var stories: [[String: Any]] = []
    /// Announced stories only counted: they rank below the stories a tap would show, or their fetch failed.
    private(set) var unfetchedHashes: [String] = []
    /// When each story not fetched yet was published, as its announcement said.
    private var announcedTimestamps: [String: TimeInterval] = [:]
    /// The order stories were announced in, so a story dated the same as one the pill holds doesn't push it out.
    private var arrivals: [String: Int] = [:]
    private var nextArrival = 0
    /// Announced stories being fetched now.
    private(set) var inFlightHashes: Set<String> = []
    /// Counted stories being fetched again to fill the pill's 20; the pill still counts them until they land.
    private var refillingHashes: Set<String> = []
    /// Read and unread from other devices for stories not fetched yet. /reader/river_stories?h= answers with a
    /// placeholder unread state, so these apply when the stories land.
    private var readOverrides: [String: Bool] = [:]
    /// The user profiles that came with the fetched stories.
    private(set) var userProfiles: [Any] = []
    /// Whether the list reads oldest first, where a tap shows the oldest-dated waiting stories.
    private var oldestFirst = false

    var isEmpty: Bool { pendingHashes.isEmpty && stories.isEmpty && unfetchedHashes.isEmpty }


    var knownHashes: Set<String> {
        Set(pendingHashes).union(unfetchedHashes).union(inFlightHashes)
            .union(stories.compactMap { $0["story_hash"] as? String })
    }

    /// Takes an announcement `RealtimeNewStories.shouldFetch` accepted. Returns whether it should be fetched: it ranks
    /// among the stories a tap would show. Otherwise it's only counted.
    mutating func announce(_ storyHash: String, timestamp: TimeInterval = 0, list: RealtimeStoryList) -> Bool {
        oldestFirst = list.oldestFirst
        announcedTimestamps[storyHash] = timestamp
        if arrivals[storyHash] == nil {
            arrivals[storyHash] = nextArrival
            nextArrival += 1
        }
        pendingHashes.append(storyHash)
        countPendingPastTheCap()
        return pendingHashes.contains(storyHash)
    }

    /// The pending announcements for one request, at most `limit` of them.
    mutating func takePending(limit: Int) -> [String] {
        let taken = Array(pendingHashes.prefix(limit))
        pendingHashes.removeFirst(taken.count)
        inFlightHashes.formUnion(taken)
        return taken
    }

    /// A fetch failed. Its stories wait as counts, and a tap past the cap fetches them again.
    mutating func fetchFailed(_ hashes: [String]) {
        for hash in hashes where inFlightHashes.contains(hash) {
            inFlightHashes.remove(hash)
            refillingHashes.remove(hash)
            unfetchedHashes.append(hash)
        }
    }

    /// The waiting stories a tap puts into the list: the newest-dated `limit` of them, or the oldest-dated for an
    /// oldest-first list, fetched or not. A newer arrival takes the place of the oldest one kept.
    func newestWaiting(limit: Int, oldestFirst: Bool) -> (fetched: [[String: Any]], unfetchedHashes: [String]) {
        var candidates: [(hash: String, timestamp: TimeInterval, story: [String: Any]?)] = stories.compactMap { story in
            guard let hash = story["story_hash"] as? String else { return nil }
            return (hash, RealtimeNewStories.timestamp(of: story), story)
        }
        let fetchedHashes = Set(candidates.map(\.hash))
        for hash in pendingHashes + Array(inFlightHashes) + unfetchedHashes where !fetchedHashes.contains(hash) {
            candidates.append((hash, announcedTimestamps[hash] ?? 0, nil))
        }
        let picked = candidates.sorted {
            ranksAhead(($0.hash, $0.timestamp), of: ($1.hash, $1.timestamp), oldestFirst: oldestFirst)
        }.prefix(limit)
        return (picked.compactMap(\.story), picked.filter { $0.story == nil }.map(\.hash))
    }

    /// Takes stories a tap put into the list out of the pill, and fills the pill's 20 again from what still waits.
    mutating func remove(_ hashes: Set<String>) {
        stories.removeAll { hashes.contains($0["story_hash"] as? String ?? "") }
        pendingHashes.removeAll { hashes.contains($0) }
        unfetchedHashes.removeAll { hashes.contains($0) }
        inFlightHashes.subtract(hashes)
        refillingHashes.subtract(hashes)
        for hash in hashes {
            announcedTimestamps[hash] = nil
            readOverrides[hash] = nil
        }
        refillFromCounted()
    }

    /// Fetched stories with any read state from other devices that arrived while they waited to be fetched.
    func applyingReadOverrides(_ fetched: [[String: Any]]) -> [[String: Any]] {
        RealtimeNewStories.applying(readOverrides, to: fetched)
    }

    /// Read state from other devices for these stories, for a fetch that outlives the buffer.
    func readOverrides(for hashes: [String]) -> [String: Bool] {
        readOverrides.filter { hashes.contains($0.key) }
    }

    /// Adds fetched stories, keeping only those that belong in the list, with any read state that arrived while they
    /// were on their way. Past the cap the last of the fetched stories drop to counts, and a story that turned out
    /// hidden or read leaves room the counted ones fill. Returns how many it kept.
    mutating func addFetched(_ fetched: [[String: Any]], userProfiles profiles: [Any], list: RealtimeStoryList,
                             listedHashes: Set<String>, requested: [String] = []) -> Int {
        oldestFirst = list.oldestFirst
        let fetched = applyingReadOverrides(fetched)
        for hash in requested + fetched.compactMap({ $0["story_hash"] as? String }) {
            inFlightHashes.remove(hash)
            refillingHashes.remove(hash)
            readOverrides[hash] = nil
            announcedTimestamps[hash] = nil
        }
        let accepted = RealtimeNewStories.insertable(fetched, list: list, knownHashes: listedHashes.union(
            stories.compactMap { $0["story_hash"] as? String }))
        if !accepted.isEmpty {
            stories = RealtimeNewStories.insertable(stories + accepted, list: list, knownHashes: [])
            userProfiles += profiles
            countFetchedPastTheCap()
        }
        refillFromCounted()
        return accepted.count
    }

    /// Another device read or unread a story. An unread list drops a waiting story once it's read, and fills the
    /// pill's 20 again from the counted stories.
    mutating func setReadState(storyHash: String, read: Bool, list: RealtimeStoryList?) {
        if pendingHashes.contains(storyHash) || inFlightHashes.contains(storyHash) || unfetchedHashes.contains(storyHash) {
            readOverrides[storyHash] = read
        }
        if let index = stories.firstIndex(where: { $0["story_hash"] as? String == storyHash }) {
            stories[index]["read_status"] = read ? 1 : 0
            if let list { stories = RealtimeNewStories.insertable(stories, list: list, knownHashes: []) }
        }
        if read, list?.unreadOnly ?? true {
            unfetchedHashes.removeAll { $0 == storyHash }
            announcedTimestamps[storyHash] = nil
        }
        if let list {
            oldestFirst = list.oldestFirst
            refillFromCounted()
        }
    }

    /// The number the pill shows: fetched stories the list would show, every counted announcement, and the counted
    /// ones being fetched again.
    func pillCount(list: RealtimeStoryList) -> Int {
        RealtimeNewStories.visibleCount(stories, list: list) + unfetchedHashes.count + refillingHashes.count
    }

    /// Announced stories waiting for their first fetch, which the pill doesn't count yet.
    var announcedPendingCount: Int { pendingHashes.filter { !refillingHashes.contains($0) }.count }

    /// Whether tapping the pill shows the newest-dated waiting stories instead of inserting the fetched ones.
    func needsNewestPage(list: RealtimeStoryList) -> Bool {
        !unfetchedHashes.isEmpty || !refillingHashes.isEmpty ||
            RealtimeNewStories.visibleCount(stories, list: list) > RealtimeNewStories.prefetchCap
    }

    /// Whether `first` comes before `second` among the stories a tap shows: the newer one, or the older one in an
    /// oldest-first list, and between stories of one date, the one announced first.
    private func ranksAhead(_ first: (hash: String, timestamp: TimeInterval),
                            of second: (hash: String, timestamp: TimeInterval), oldestFirst: Bool) -> Bool {
        if first.timestamp != second.timestamp {
            return oldestFirst ? first.timestamp < second.timestamp : first.timestamp > second.timestamp
        }
        let firstArrival = arrivals[first.hash] ?? Int.max, secondArrival = arrivals[second.hash] ?? Int.max
        if firstArrival != secondArrival { return firstArrival < secondArrival }
        return first.hash < second.hash
    }

    /// Pending announcements that rank past the cap among everything the pill holds, fetched or on its way, are only
    /// counted instead of fetched.
    private mutating func countPendingPastTheCap() {
        let cap = RealtimeNewStories.prefetchCap
        let pending = Set(pendingHashes)
        var held: [(hash: String, timestamp: TimeInterval)] = stories.compactMap { story in
            guard let hash = story["story_hash"] as? String else { return nil }
            return (hash, RealtimeNewStories.timestamp(of: story))
        }
        held += (Array(inFlightHashes) + pendingHashes).map { ($0, announcedTimestamps[$0] ?? 0) }
        guard held.count > cap else { return }
        let oldestFirst = self.oldestFirst
        let pastCap = held.sorted { ranksAhead($0, of: $1, oldestFirst: oldestFirst) }.dropFirst(cap)
            .map(\.hash).filter { pending.contains($0) && !refillingHashes.contains($0) }
        guard !pastCap.isEmpty else { return }
        pendingHashes.removeAll { pastCap.contains($0) }
        unfetchedHashes += pastCap
    }

    /// Once more than the cap is fetched, the last of them drop to counts, keeping their dates.
    private mutating func countFetchedPastTheCap() {
        let cap = RealtimeNewStories.prefetchCap
        guard stories.count > cap else { return }
        let oldestFirst = self.oldestFirst
        let dropped = stories.compactMap { story -> (hash: String, timestamp: TimeInterval)? in
            guard let hash = story["story_hash"] as? String else { return nil }
            return (hash, RealtimeNewStories.timestamp(of: story))
        }.sorted { ranksAhead($0, of: $1, oldestFirst: oldestFirst) }.dropFirst(cap)
        let droppedHashes = Set(dropped.map(\.hash))
        stories.removeAll { droppedHashes.contains($0["story_hash"] as? String ?? "") }
        for story in dropped {
            announcedTimestamps[story.hash] = story.timestamp
            unfetchedHashes.append(story.hash)
        }
    }

    /// With fewer than the cap fetched or on their way, the best-ranked counted stories are fetched to fill the 20.
    private mutating func refillFromCounted() {
        let room = RealtimeNewStories.prefetchCap - (stories.count + pendingHashes.count + inFlightHashes.count)
        guard room > 0, !unfetchedHashes.isEmpty else { return }
        let oldestFirst = self.oldestFirst
        let refill = unfetchedHashes.map { ($0, announcedTimestamps[$0] ?? 0) }
            .sorted { ranksAhead($0, of: $1, oldestFirst: oldestFirst) }.prefix(room).map(\.0)
        unfetchedHashes.removeAll { refill.contains($0) }
        pendingHashes += refill
        refillingHashes.formUnion(refill)
    }
}

/// Live updates over node/unread_counts.coffee's socket, the way a web tab gets them: stories read or unread on
/// another device, feeds whose counts changed or that fetched new stories, new stories for the open list, saved
/// story counts, interactions and feed list reloads.
///
/// FeedsObjCViewController.m calls `feedListDidLoad` once the feed list loads, and NewsBlurAppDelegate.m calls `stop`
/// on logout. The socket closes in the background on iPhone and iPad and reconnects on return, catching up with one
/// full count refresh. The Mac app keeps it open for as long as it runs, so the dock badge stays current.
@MainActor @objcMembers final class RealtimeUpdates: NSObject {
    static let shared = RealtimeUpdates()

    /// Our own reads echo back as `feed:<id>`, and other devices' reads arrive in bursts, so count refreshes they
    /// ask for wait this long to share a request.
    static let userUpdateDebounce: TimeInterval = 1
    /// A feed that fetched new stories is announced to every subscriber at once. Like the web's
    /// feed_unread_count, each client waits a random part of 10ms per subscriber before asking for its counts.
    static let secondsPerSubscriber: TimeInterval = 0.01
    static let maximumFeedUpdateDelay: TimeInterval = 60
    /// New story announcements are gathered this long before fetching them, plus 2ms per subscriber, as the web
    /// dashboard does in media/js/newsblur/common/assetmodel.js add_dashboard_story.
    static let newStoryBatchDelay: TimeInterval = 1
    static let secondsPerSubscriberForNewStories: TimeInterval = 0.002
    static let maximumNewStoryDelay: TimeInterval = 10
    /// A catch-up after a reconnect is skipped when a full count refresh started this recently.
    static let catchUpGrace: TimeInterval = 30
    /// Saved counts and feed list reloads asked for this close together share one request.
    static let starredCountsDebounce: TimeInterval = 2
    static let feedListReloadDebounce: TimeInterval = 5

    private let socket: NewsBlurSocketClient
    private var registeredHandlers = false
    private var wantsConnection = false
    private var username: String?
    private var subscribedFeeds: [String] = []
    private var isConnected = false
    private var connectedSince: Date?
    private var needsCatchUp = false
    private var lastFullCountRefresh: Date?
    private var feedListLoadedAt: Date?
    private var isInBackground = false

    private lazy var countRefreshQueue = RealtimeCountRefreshQueue { [weak self] feedIds in
        self?.fetchUnreadCounts(feedIds)
    }
    private var starredCountsWork: DispatchWorkItem?
    private var feedListReloadWork: DispatchWorkItem?

    // New stories for the open list: announced hashes waiting to be fetched, then fetched stories waiting for a tap.
    private var newStoryListKey: String?
    private var newStoryFetchWork: DispatchWorkItem?
    private var newStoryFetchDate: Date?
    private var newStoryFetchGeneration = 0
    private var newStories = RealtimeNewStoryBuffer()

    init(socket: NewsBlurSocketClient = .shared) {
        self.socket = socket
        super.init()
    }


    private var appDelegate: NewsBlurAppDelegate? { NewsBlurAppDelegate.shared() }

    /// Every event is logged at debug level, which costs nothing unless someone streams it:
    /// `log stream --level debug --predicate 'subsystem == "com.newsblur.NewsBlur" AND category == "Realtime"'`.
    private static let logger = Logger(subsystem: "com.newsblur.NewsBlur", category: "Realtime")

    private static func log(_ message: @autoclosure () -> String) {
        let text = message()
        logger.debug("\(text, privacy: .public)")
    }

    private static var keepsConnectionInBackground: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Lifecycle

    /// The feed list loaded: connect, or resubscribe if the feeds changed.
    func feedListDidLoad() {
        guard let appDelegate, let username = appDelegate.activeUsername, !username.isEmpty else { return }
        registerHandlersIfNeeded()
        if self.username != username {
            clearNewStories()
            countRefreshQueue.cancelAll()
        }
        self.username = username
        subscribedFeeds = Self.subscriptionFeedIds(appDelegate)
        feedListLoadedAt = Date()
        wantsConnection = true
        // FeedsObjCViewController.m refreshes every count after a feed list load, so this connection starts current.
        needsCatchUp = false
        connectIfWanted()
    }

    /// Logout or an account change: close the socket and forget everything waiting.
    func stop() {
        wantsConnection = false
        username = nil
        subscribedFeeds = []
        needsCatchUp = false
        connectedSince = nil
        countRefreshQueue.cancelAll()
        starredCountsWork?.cancel()
        feedListReloadWork?.cancel()
        clearNewStories()
        socket.disconnect()
    }

    /// FeedsObjCViewController.m notes every full count refresh, which a catch-up then doesn't repeat.
    func noteFullCountRefresh() {
        lastFullCountRefresh = Date()
    }

    /// Whether the socket has been connected without a break since `date`, so nothing was missed.
    func hasStayedConnected(since date: Date?) -> Bool {
        guard let date, let connectedSince else { return false }
        return connectedSince <= date
    }

    var connected: Bool { isConnected }

    private func registerHandlersIfNeeded() {
        guard !registeredHandlers else { return }
        registeredHandlers = true

        socket.subscribeArguments(event: "user:update") { [weak self] arguments in
            MainActor.assumeIsolated { self?.handleUserUpdate(arguments) }
        }
        socket.subscribeArguments(event: "feed:update") { [weak self] arguments in
            MainActor.assumeIsolated { self?.handleFeedUpdate(arguments) }
        }
        socket.subscribeArguments(event: "feed:story:new") { [weak self] arguments in
            MainActor.assumeIsolated { self?.handleNewStory(arguments) }
        }
        socket.onConnectionChange = { [weak self] connected in
            MainActor.assumeIsolated { self?.connectionChanged(connected) }
        }

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(applicationDidEnterBackground),
                           name: UIApplication.didEnterBackgroundNotification, object: nil)
        center.addObserver(self, selector: #selector(applicationWillEnterForeground),
                           name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    private func connectIfWanted() {
        guard wantsConnection, let username, !isInBackground || Self.keepsConnectionInBackground else { return }
        socket.connect(username: username, feeds: subscribedFeeds)
        // Ask AI may have opened the connection first with its own feed list.
        socket.updateFeeds(subscribedFeeds)
    }

    func applicationDidEnterBackground() {
        isInBackground = true
        guard !Self.keepsConnectionInBackground, wantsConnection else { return }
        socket.disconnect()
        clearNewStories()
    }

    func applicationWillEnterForeground() {
        isInBackground = false
        connectIfWanted()
    }

    private func connectionChanged(_ connected: Bool) {
        isConnected = connected
        guard connected else {
            connectedSince = nil
            if wantsConnection { needsCatchUp = true }
            return
        }
        connectedSince = Date()
        guard needsCatchUp, wantsConnection else { return }
        needsCatchUp = false
        if let lastFullCountRefresh, Date().timeIntervalSince(lastFullCountRefresh) < Self.catchUpGrace {
            Self.log("reconnected; a full count refresh already started \(Int(Date().timeIntervalSince(lastFullCountRefresh)))s ago")
            return
        }
        // RealtimeUpdates.swift missed whatever happened while the socket was closed, so it counts everything once.
        Self.log("reconnected; catching up with a full count refresh")
        appDelegate?.feedsViewController.refreshFeedList()
    }

    /// Active subscriptions plus blurblogs, the list the web subscribes with (reader.js send_socket_active_feeds).
    static func subscriptionFeedIds(_ appDelegate: NewsBlurAppDelegate) -> [String] {
        let inactive = Set((appDelegate.dictInactiveFeeds as? [AnyHashable: Any] ?? [:]).keys.map { "\($0)" })
        var feedIds: [String] = []
        for (key, value) in appDelegate.dictFeeds as? [AnyHashable: Any] ?? [:] {
            let feedId = "\(key)"
            guard !inactive.contains(feedId) else { continue }
            if let feed = value as? [AnyHashable: Any], let active = feed["active"] as? NSNumber, !active.boolValue { continue }
            feedIds.append(feedId)
        }
        let socialIds = (appDelegate.dictSocialFeeds ?? [:]).keys.map { "\($0)" }
        return feedIds.sorted() + socialIds.filter { $0.hasPrefix("social:") }.sorted()
    }

    // MARK: - Events

    private func handleUserUpdate(_ arguments: [Any]) {
        guard arguments.count >= 2, let channel = arguments[0] as? String, channel == username,
              let message = arguments[1] as? String else { return }
        Self.log("user:update \(message)")
        switch RealtimeUserMessage(message) {
        case .storyRead(let hash):
            applyRemoteReadState(storyHash: hash, read: true)
        case .storyUnread(let hash):
            applyRemoteReadState(storyHash: hash, read: false)
        case .feedCounts(let feedIds):
            // Like the web, the open list's feeds are left to story:read and story:unread, which keeps our own
            // reads' echoes from racing the reads still on their way to the server.
            let openFeeds = openStoryList()?.feedIds ?? []
            countRefreshQueue.enqueue(feedIds.filter { !openFeeds.contains($0) }, delay: Self.userUpdateDebounce)
        case .socialCounts(let feedId):
            guard appDelegate?.storiesCollection.activeFeedIdStr != feedId else { return }
            countRefreshQueue.enqueue([feedId], delay: Self.userUpdateDebounce)
        case .refreshCounts(let feedIds):
            countRefreshQueue.enqueue(feedIds, delay: Self.userUpdateDebounce)
        case .starred(let hash):
            applyRemoteSavedState(storyHash: hash, saved: true)
            scheduleStarredCountsRefresh()
        case .unstarred(let hash):
            applyRemoteSavedState(storyHash: hash, saved: false)
            scheduleStarredCountsRefresh()
        case .interactionNew:
            refreshInteractionsIfVisible()
        case .reloadFeeds:
            scheduleFeedListReload()
        case .ignored:
            break
        }
    }

    private func handleFeedUpdate(_ arguments: [Any]) {
        guard let feedId = arguments.first.map({ "\($0)" }), !feedId.isEmpty else { return }
        let subscribers = Self.subscriberCount(feedId: feedId, appDelegate: appDelegate)
        let spread = min(Self.maximumFeedUpdateDelay, Double(subscribers) * Self.secondsPerSubscriber)
        let delay = Double.random(in: 0...max(spread, 0))
        Self.log("feed:update \(feedId) \(arguments.dropFirst().first ?? "") (\(subscribers) subscribers, counting in \(String(format: "%.1f", delay))s)")
        countRefreshQueue.enqueue([feedId], delay: delay)
    }

    private static func subscriberCount(feedId: String, appDelegate: NewsBlurAppDelegate?) -> Int {
        guard let feed = appDelegate?.dictFeeds?[feedId] as? [AnyHashable: Any] else { return 0 }
        return (feed["num_subscribers"] as? NSNumber)?.intValue ?? 0
    }

    // MARK: - Unread counts

    private func fetchUnreadCounts(_ feedIds: [String]) {
        guard let appDelegate, let host = appDelegate.url, !feedIds.isEmpty else { return }
        let account = username
        Self.log("counting \(feedIds.count) feeds: \(feedIds.prefix(10).joined(separator: ","))")
        appDelegate.get("\(host)/reader/feed_unread_count", parameters: ["feed_id": feedIds], success: { [weak self] _, response in
            MainActor.assumeIsolated {
                guard let self, self.username == account, let results = response as? [AnyHashable: Any] else { return }
                self.appDelegate?.feedsViewController.applyRealtimeUnreadCounts(results)
            }
        }, failure: { _, _ in
            // A failed count refresh leaves the counts as they were. The next update or catch-up asks again.
        })
    }

    // MARK: - Read state from other devices

    /// Apply a read or unread from another device to this one without telling the server, which already knows.
    private func applyRemoteReadState(storyHash: String, read: Bool) {
        guard let appDelegate, let collection = appDelegate.storiesCollection else { return }
        updateBufferedReadState(storyHash: storyHash, read: read)

        if let story = loadedStory(hash: storyHash, appDelegate: appDelegate) {
            guard collection.isStoryUnread(story) == read else { return }
            if read {
                collection.markStoryRead(story)
            } else {
                collection.markStoryUnread(story)
            }
            appDelegate.feedDetailViewController.reload()
            appDelegate.storyPagesViewController.refreshHeaders()
            return
        }

        // A story that isn't loaded only needs its offline copy updated, and its feed counted again. The server's
        // feed:<id> message would do that too, but not for a feed in the open list, which a river like All Site
        // Stories covers entirely. The recount waits out the debounce, long enough for a read made here a moment
        // ago to reach the server first.
        if read {
            appDelegate.unreadStoryHashes?.removeObject(forKey: storyHash)
            appDelegate.recentlyReadStories?[storyHash] = true
        } else {
            appDelegate.unreadStoryHashes?[storyHash] = true
            appDelegate.recentlyReadStories?.removeObject(forKey: storyHash)
        }
        if let feedId = storyHash.split(separator: ":").first.map(String.init), !feedId.isEmpty {
            countRefreshQueue.enqueue([feedId], delay: Self.userUpdateDebounce)
        }
        if let account = appDelegate.activeUsername, !account.isEmpty {
            StoryFirstPageCache.shared.record(story: ["story_hash": storyHash, "read_status": read ? 1 : 0],
                                              fields: ["read_status"], account: account, host: appDelegate.url)
        }
        if read {
            appDelegate.database?.inDatabase { database in
                database?.executeUpdate("DELETE FROM unread_hashes WHERE story_hash = ?", withArgumentsIn: [storyHash])
            }
        }
    }

    private func loadedStory(hash: String, appDelegate: NewsBlurAppDelegate) -> [AnyHashable: Any]? {
        for item in appDelegate.storiesCollection?.activeFeedStories ?? [] {
            if let story = item as? [AnyHashable: Any], story["story_hash"] as? String == hash { return story }
        }
        if let active = appDelegate.activeStory, active["story_hash"] as? String == hash {
            return active
        }
        return nil
    }

    // MARK: - Saved stories

    private func applyRemoteSavedState(storyHash: String, saved: Bool) {
        guard !storyHash.isEmpty, let appDelegate, let collection = appDelegate.storiesCollection,
              let story = loadedStory(hash: storyHash, appDelegate: appDelegate),
              (story["starred"] as? NSNumber)?.boolValue ?? false != saved else { return }
        collection.markStory(story, asSaved: saved)
        appDelegate.feedDetailViewController.redrawUnreadStory()
        appDelegate.storyPagesViewController.refreshHeaders()
    }

    private func scheduleStarredCountsRefresh() {
        starredCountsWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.fetchStarredCounts() }
        }
        starredCountsWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.starredCountsDebounce, execute: work)
    }

    private func fetchStarredCounts() {
        guard let appDelegate, let host = appDelegate.url else { return }
        let account = username
        appDelegate.get("\(host)/reader/starred_counts", parameters: nil as Any?, success: { [weak self] _, response in
            MainActor.assumeIsolated {
                guard let self, self.username == account, let appDelegate = self.appDelegate,
                      let results = response as? [AnyHashable: Any] else { return }
                let savedStories = appDelegate.updateStarredStoryCounts(results)
                var folders = appDelegate.dictFolders ?? [:]
                folders["saved_stories"] = savedStories
                appDelegate.dictFolders = folders
                appDelegate.feedsViewController.reloadFeedTitlesTable()
            }
        }, failure: { _, _ in
            // The saved counts stay as they were until the next save or feed list load.
        })
    }

    // MARK: - Interactions and the feed list

    private func refreshInteractionsIfVisible() {
        appDelegate?.refreshVisibleInteractions()
    }

    private func scheduleFeedListReload() {
        feedListReloadWork?.cancel()
        let requestedAt = Date()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.wantsConnection else { return }
                // A change made on this device echoes back too, and the app reloads the feed list after it on its
                // own. A list loaded since the message already shows the change.
                if let loadedAt = self.feedListLoadedAt, loadedAt > requestedAt { return }
                self.appDelegate?.feedsViewController.fetchFeedList(false)
            }
        }
        feedListReloadWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.feedListReloadDebounce, execute: work)
    }

    // MARK: - New stories for the open list

    /// The list the user is looking at, or reading from, if new stories can join it.
    func openStoryList() -> RealtimeStoryList? {
        guard let appDelegate, let collection = appDelegate.storiesCollection,
              let feedDetail = appDelegate.feedDetailViewController else { return nil }
        let listIsOnScreen = feedDetail.viewIfLoaded?.window != nil ||
            appDelegate.storyPagesViewController?.viewIfLoaded?.window != nil
        guard listIsOnScreen, !collection.isDashboard, !collection.isSavedView, !collection.isReadView,
              !collection.isSocialView, !collection.isSocialRiverView, !collection.isDailyBriefing,
              !collection.isWidgetView, !collection.inSearch, !collection.isTrending,
              !appDelegate.isSavedStoriesIntelligenceMode() else { return nil }
        // A free account's river shows only its first few stories (FeedDetailObjCViewController.m renderStories:).
        if collection.isRiverView && !appDelegate.isPremium { return nil }
        guard let feedIds = Self.feedIds(of: collection, appDelegate: appDelegate), !feedIds.isEmpty else { return nil }

        let order = collection.activeOrder ?? "newest"
        let readFilter = collection.activeReadFilter ?? "unread"
        let feedKey = collection.isRiverView ? "folder:\(collection.activeFolder ?? "")" : "feed:\(collection.activeFeedIdStr ?? "")"
        return RealtimeStoryList(key: "\(feedKey)|\(order)|\(readFilter)|\(appDelegate.selectedIntelligence)|\(collection.showHiddenStories)",
                                 feedIds: feedIds,
                                 oldestFirst: order == "oldest",
                                 unreadOnly: readFilter == "unread",
                                 intelligence: appDelegate.selectedIntelligence,
                                 showHiddenStories: collection.showHiddenStories,
                                 loadedLastPage: feedDetail.pageFinished)
    }

    /// Every feed whose stories the list loads. A river's `activeFolderFeeds` only holds the feeds that had unread
    /// stories when it opened, so the folder's full membership comes from the feed list instead.
    static func feedIds(of collection: StoriesCollection, appDelegate: NewsBlurAppDelegate) -> Set<String>? {
        guard collection.isRiverView else {
            return collection.activeFeedIdStr.map { [$0] }
        }
        let activeFeeds = Set(subscriptionFeedIds(appDelegate).filter { !$0.hasPrefix("social:") })
        switch collection.activeFolder {
        case "everything":
            return activeFeeds
        case "infrequent":
            let threshold = UserDefaults.standard.integer(forKey: "infrequent_stories_per_month")
            return activeFeeds.filter { feedId in
                guard let feed = appDelegate.dictFeeds?[feedId] as? [AnyHashable: Any] else { return false }
                return (feed["average_stories_per_month"] as? NSNumber)?.intValue ?? 0 <= threshold
            }
        case let folder?:
            guard let members = appDelegate.dictFolders?[folder] as? [Any] else { return nil }
            return Set(members.map { "\($0)" }).intersection(activeFeeds)
        case nil:
            return nil
        }
    }

    private func handleNewStory(_ arguments: [Any]) {
        guard RealtimeNewStories.isEnabled(),
              arguments.count >= 2, let channel = arguments[0] as? String, channel.hasSuffix(":story"),
              let message = arguments[1] as? String, let list = openStoryList(),
              let collection = appDelegate?.storiesCollection else { return }
        let feedId = String(channel.dropLast(":story".count))
        let parts = message.split(separator: ",", maxSplits: 1).map(String.init)
        guard parts.count == 2, let timestamp = TimeInterval(parts[1]) else { return }
        receiveNewStory(storyHash: parts[0], feedId: feedId, timestamp: timestamp, list: list,
                        listedStories: (collection.activeFeedStories ?? []).compactMap { $0 as? [String: Any] })
    }

    /// A `feed:story:new` announcement for the open list: hold it for the pill and fetch it in the next batch. With
    /// "Show new stories as they arrive" off, it's ignored.
    func receiveNewStory(storyHash: String, feedId: String, timestamp: TimeInterval, list: RealtimeStoryList,
                         listedStories: [[String: Any]]) {
        guard RealtimeNewStories.isEnabled() else { return }
        if newStoryListKey != list.key { clearNewStories(keepingKey: list.key) }
        let knownHashes = Set(listedStories.compactMap { $0["story_hash"] as? String }).union(newStories.knownHashes)
        guard RealtimeNewStories.shouldFetch(storyHash: storyHash, feedId: feedId, timestamp: timestamp, list: list,
                                             knownHashes: knownHashes,
                                             listedTimestamps: listedStories.map(RealtimeNewStories.timestamp(of:)),
                                             now: Date()) else { return }
        guard newStories.announce(storyHash, timestamp: timestamp, list: list) else {
            Self.log("feed:story:new \(storyHash) counted without fetching, the pill holds enough")
            showNewStoriesPill(list: list)
            return
        }
        Self.log("feed:story:new \(storyHash) joins the open list")

        let subscribers = appDelegate.map { Self.subscriberCount(feedId: feedId, appDelegate: $0) } ?? 0
        let spread = min(Self.maximumNewStoryDelay, Double(subscribers) * Self.secondsPerSubscriberForNewStories)
        scheduleNewStoryFetch(after: Self.newStoryBatchDelay + Double.random(in: 0...max(spread, 0)))
    }

    /// Fetches the pending announcements in one batch after `delay`, unless a batch is due sooner.
    private func scheduleNewStoryFetch(after delay: TimeInterval) {
        let fetchDate = Date().addingTimeInterval(delay)
        if let newStoryFetchDate, newStoryFetchDate <= fetchDate { return }
        newStoryFetchWork?.cancel()
        newStoryFetchDate = fetchDate
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.fetchNewStories() }
        }
        newStoryFetchWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay), execute: work)
    }

    /// RealtimeUpdates.swift: the pill took counted stories back to keep the 20 a tap shows fetched (a story it held was
    /// read elsewhere, turned out hidden, or joined the list); they go with the next batch.
    private func fetchRefilledStories() {
        guard !newStories.pendingHashes.isEmpty else { return }
        scheduleNewStoryFetch(after: Self.newStoryBatchDelay)
    }

    private func fetchNewStories() {
        newStoryFetchWork = nil
        newStoryFetchDate = nil
        guard let appDelegate, let host = appDelegate.url, let list = openStoryList(), list.key == newStoryListKey,
              !newStories.pendingHashes.isEmpty else { return }
        // apps/reader/views.py load_river_stories__redis reads at most 100 hashes.
        let hashes = newStories.takePending(limit: StoryScoreRefresher.batchSize)
        let generation = newStoryFetchGeneration
        let parameters: [String: Any] = ["h": hashes, "include_hidden": "true"]
        appDelegate.get("\(host)/reader/river_stories", parameters: parameters, success: { [weak self] _, response in
            MainActor.assumeIsolated {
                guard let self, generation == self.newStoryFetchGeneration,
                      let results = response as? [String: Any] else { return }
                self.bufferFetchedStories(results, requested: hashes)
            }
        }, failure: { [weak self] _, _ in
            // A failed fetch leaves these stories counted; a tap past the cap fetches them again.
            MainActor.assumeIsolated {
                guard let self, generation == self.newStoryFetchGeneration else { return }
                self.newStories.fetchFailed(hashes)
                if let list = self.openStoryList(), list.key == self.newStoryListKey { self.showNewStoriesPill(list: list) }
            }
        })
    }

    private func bufferFetchedStories(_ results: [String: Any], requested: [String]) {
        guard let list = openStoryList(), list.key == newStoryListKey, let collection = appDelegate?.storiesCollection else {
            clearNewStories()
            return
        }
        let listedHashes = Set((collection.activeFeedStories ?? []).compactMap { ($0 as? [String: Any])?["story_hash"] as? String })
        let kept = newStories.addFetched(results["stories"] as? [[String: Any]] ?? [],
                                         userProfiles: results["user_profiles"] as? [Any] ?? [], list: list,
                                         listedHashes: listedHashes, requested: requested)
        Self.log("fetched \((results["stories"] as? [Any])?.count ?? 0) new stories, \(kept) belong in the list")
        fetchRefilledStories()
        showNewStoriesPill(list: list)
    }

    private func updateBufferedReadState(storyHash: String, read: Bool) {
        let list = openStoryList()
        guard newStories.knownHashes.contains(storyHash) else { return }
        newStories.setReadState(storyHash: storyHash, read: read, list: list?.key == newStoryListKey ? list : nil)
        if let list, list.key == newStoryListKey {
            fetchRefilledStories()
            showNewStoriesPill(list: list)
        }
    }

    private func showNewStoriesPill(list: RealtimeStoryList) {
        let count = newStories.pillCount(list: list)
        Self.log("\(newStories.stories.count) new stories fetched, \(newStories.unfetchedHashes.count) more announced, " +
                 "\(count) shown by the list's filter")
        guard let feedDetail = appDelegate?.feedDetailViewController else { return }
        if count > 0 {
            feedDetail.showNewStoriesPill(count: count, atBottom: list.oldestFirst)
        } else {
            feedDetail.hideNewStoriesPill()
        }
    }

    /// FeedDetailViewController.swift's pill was tapped: put the waiting stories into the list, which
    /// NewStoriesPill.swift slides into place. Past the cap (`RealtimeNewStories.prefetchCap`) a newest-first list
    /// shows the newest-dated waiting stories in place of everything loaded (NewStoriesNewestPage.swift), and an
    /// oldest-first list gains the oldest-dated ones at its end while the rest keep waiting.
    func insertBufferedStories() {
        guard let appDelegate, appDelegate.storiesCollection != nil,
              let feedDetail = appDelegate.feedDetailViewController, let list = openStoryList(),
              list.key == newStoryListKey, !newStories.isEmpty else {
            clearNewStories()
            return
        }
        guard newStories.needsNewestPage(list: list) else {
            let stories = newStories.stories
            let profiles = newStories.userProfiles
            clearNewStories(keepingKey: list.key)
            insertPinned(stories, profiles: profiles, list: list, into: feedDetail)
            return
        }
        let pick = newStories.newestWaiting(limit: RealtimeNewStories.prefetchCap, oldestFirst: list.oldestFirst)
        let fetched = newStories.applyingReadOverrides(pick.fetched)
        let overrides = newStories.readOverrides(for: pick.unfetchedHashes)
        let profiles = newStories.userProfiles
        guard list.oldestFirst else {
            Self.log("showing the \(pick.fetched.count + pick.unfetchedHashes.count) newest stories for \(list.key)")
            clearNewStories(keepingKey: list.key)
            feedDetail.showNewestStories(fetched: fetched, unfetchedHashes: pick.unfetchedHashes, readOverrides: overrides,
                                         profiles: profiles, list: list)
            return
        }
        // An oldest-first list isn't reloaded: the oldest waiting stories join its end, the rest wait for the next tap,
        // the next of them fetched.
        newStories.remove(Set(pick.fetched.compactMap { $0["story_hash"] as? String } + pick.unfetchedHashes))
        fetchRefilledStories()
        showNewStoriesPill(list: list)
        guard !pick.unfetchedHashes.isEmpty, let host = appDelegate.url else {
            insertPinned(RealtimeNewStories.insertable(fetched, list: list, knownHashes: []), profiles: profiles,
                         list: list, into: feedDetail)
            return
        }
        let generation = newStoryFetchGeneration
        appDelegate.get("\(host)/reader/river_stories", parameters: ["h": pick.unfetchedHashes, "include_hidden": "true"],
                        success: { [weak self] _, response in
            MainActor.assumeIsolated {
                guard let self, generation == self.newStoryFetchGeneration, self.openStoryList()?.key == list.key,
                      let feedDetail = self.appDelegate?.feedDetailViewController else { return }
                let results = response as? [String: Any]
                let details = RealtimeNewStories.applying(overrides, to: results?["stories"] as? [[String: Any]] ?? [])
                let stories = RealtimeNewStories.insertable(fetched + details, list: list, knownHashes: [])
                self.insertPinned(stories, profiles: profiles + (results?["user_profiles"] as? [Any] ?? []), list: list,
                                  into: feedDetail)
            }
        }, failure: { _, _ in
            // The stories still load as the list reaches its end.
        })
    }

    /// Pins stories at the top of a newest-first list, or the end of an oldest-first one, sliding them in.
    private func insertPinned(_ stories: [[String: Any]], profiles: [Any], list: RealtimeStoryList,
                              into feedDetail: FeedDetailViewController) {
        guard !stories.isEmpty else { return }
        var openStoryHash: String?
        feedDetail.presentNewStories(atBottom: list.oldestFirst, insert: { [weak self] in
            // RealtimeUpdates.swift: a newest-first list scrolls to its top first, and may have changed meanwhile.
            guard let self, let appDelegate = self.appDelegate, let collection = appDelegate.storiesCollection,
                  self.openStoryList()?.key == list.key else { return nil }
            openStoryHash = appDelegate.storyPagesViewController?.currentPage?.activeStoryId
            guard collection.insertRealtimeStories(stories) > 0 else { return nil }
            if !profiles.isEmpty { collection.addFeedUserProfiles(profiles) }
            let locations = stories.compactMap { story -> (String, Int)? in
                guard let hash = story["story_hash"] as? String else { return nil }
                let location = collection.location(ofStoryId: hash)
                return location >= 0 ? (hash, Int(location)) : nil
            }
            return locations.sorted { $0.1 < $1.1 }.map(\.0)
        }, reload: { [weak self] in
            guard let appDelegate = self?.appDelegate, let collection = appDelegate.storiesCollection,
                  let feedDetail = appDelegate.feedDetailViewController else { return }
            feedDetail.reloadImmediately()
            if let openStoryHash {
                let location = collection.location(ofStoryId: openStoryHash)
                if location >= 0 { appDelegate.storyPagesViewController.preserveCurrentPage(atLocation: location) }
            }
            appDelegate.storyPagesViewController.setNextPreviousButtons()
        })
    }

    /// Stories held for the pill, fetched, waiting to be fetched or only counted.
    func newStoriesWaiting(for list: RealtimeStoryList) -> Int {
        newStories.pillCount(list: list) + newStories.announcedPendingCount
    }

    /// Whether a batch of announced stories is waiting to be fetched.
    var isNewStoryFetchScheduled: Bool { newStoryFetchWork != nil }

    /// PreferencesView.swift turned "Show new stories as they arrive" on or off. Off hides the pill and drops what
    /// it held; on, the next stories to arrive raise it again.
    func newStoriesSettingDidChange() {
        guard !RealtimeNewStories.isEnabled() else { return }
        clearNewStories()
    }

    /// The open list loaded its first page again, or another list opened.
    func storyListDidReload() {
        appDelegate?.feedDetailViewController?.cancelNewStoriesArrival()
        appDelegate?.feedDetailViewController?.cancelNewestStories()
        clearNewStories()
    }

    private func clearNewStories(keepingKey key: String? = nil) {
        newStoryListKey = key
        newStoryFetchWork?.cancel()
        newStoryFetchWork = nil
        newStoryFetchDate = nil
        newStoryFetchGeneration += 1
        newStories = RealtimeNewStoryBuffer()
        appDelegate?.feedDetailViewController?.hideNewStoriesPill()
    }
}
