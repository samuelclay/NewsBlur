//
//  StoryScoreRefresher.swift
//  NewsBlur
//
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import Foundation

/// StoryScoreRefresher.swift asks the server for loaded stories' scores once a classifier save answers, when the save
/// may have changed a score the app can't work out. NewsBlurAppDelegate.m's recalculateIntelligenceScores: shows the
/// change right away, but it can't run AI prompts, and StoryClassifierScorer.swift keeps the server's old score
/// wherever it can't tell. So an AI prompt save, a classifier moved to another scope, or a save that left any story's
/// score uncertain asks apps/reader/views.py for the uncertain stories and the ones near the screen, without their
/// content, one batch at a time. Any other save is settled by the recalculation alone.
@MainActor @objcMembers final class StoryScoreRefresher: NSObject {
    /// Saves that follow each other this closely, like tapping through a story's classifiers in the trainer, share
    /// one refresh.
    static let debounce: TimeInterval = 1
    /// apps/reader/views.py load_river_stories__redis reads at most 100 story hashes per request, so a refresh asks for
    /// that many stories at a time and sends the next batch once one lands.
    static let batchSize = 100
    /// How many stories past the ones on screen a refresh asks for, in each direction.
    static let nearbyStoryCount = 25
    /// The fields apps/reader/views.py scores a story with. Everything else on a loaded story stays as it is.
    private static let scoringKeys: Set<String> = ["intelligence", "score", "prompt_classifiers"]

    /// The story list a refresh was asked for. Opening another site or folder, or reloading this one, makes a new
    /// list, and a refresh for the old one is dropped rather than landing on it.
    private struct StoryList: Equatable {
        let collection: ObjectIdentifier
        let feedId: String?
        let folder: String?
        let fetchRequestId: UInt
    }

    /// Why a site's next refresh is needed. It's kept until a refresh's scores land, so a refresh that's dropped for a
    /// newer save is asked for again with that save's.
    private struct PendingRefresh {
        let list: StoryList
        /// An AI prompt or a scope move can change any story's score in ways only the server knows.
        var changesScoresOnlyTheServerKnows = false
        /// Stories whose score StoryClassifierScorer.swift couldn't settle.
        var uncertainStoryHashes: Set<String> = []

        var isNeeded: Bool { changesScoresOnlyTheServerKnows || !uncertainStoryHashes.isEmpty }
    }

    /// The stories one request asks for, and the ones it had no room for, which wait for the next batch.
    private struct Batch {
        let storyHashes: [String]
        let unsentStoryHashes: Set<String>
    }

    /// Waits out the debounce before refreshing. NewsBlurTests replace it to end the wait by hand.
    var afterDebounce: (TimeInterval, @escaping () -> Void) -> Void = { delay, work in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private weak var appDelegate: NewsBlurAppDelegate?
    /// Every save that starts and every refresh asked for moves its site to a new generation, so only the latest
    /// refresh is sent or lands.
    private var generations: [String: Int] = [:]
    /// Classifier saves for each site that haven't answered yet. The server may not have their change, so no refresh
    /// is sent or lands while one is out. Each one checks for a refresh when it answers.
    private var savesInFlight: [String: Int] = [:]
    private var pendingRefreshes: [String: PendingRefresh] = [:]

    init(appDelegate: NewsBlurAppDelegate) {
        self.appDelegate = appDelegate
    }

    /// NewsBlurAppDelegate.m calls this just before it sends a classifier save. A refresh asked for earlier knows
    /// nothing of this change, so it's dropped rather than landing over the save's local recalculation.
    func saveWillStart(forFeedId feedId: String) {
        saveWillStart(forFeedId: feedId, changesScoresOnlyTheServerKnows: false)
    }

    /// An AI prompt save or a scope move changes scores only the server can work out, so it asks for a refresh
    /// whatever the recalculation could settle.
    func saveWillStart(forFeedId feedId: String, changesScoresOnlyTheServerKnows: Bool) {
        savesInFlight[feedId, default: 0] += 1
        invalidateRefreshes(forFeedId: feedId)
        if changesScoresOnlyTheServerKnows {
            updatePendingRefresh(forFeedId: feedId) { $0.changesScoresOnlyTheServerKnows = true }
        }
    }

    /// NewsBlurAppDelegate.m's recalculateIntelligenceScores: passes the stories StoryClassifierScorer.swift left with
    /// the server's old score, so the next refresh asks for them.
    func noteUncertainStories(_ storyHashes: Set<String>, forFeedId feedId: String) {
        guard !storyHashes.isEmpty else { return }
        updatePendingRefresh(forFeedId: feedId) { $0.uncertainStoryHashes.formUnion(storyHashes) }
    }

    /// NewsBlurAppDelegate.m calls this once a classifier save answers. A save that changed nothing the app couldn't
    /// settle sends no refresh.
    func saveDidEnd(forFeedId feedId: String) {
        savesInFlight[feedId] = max((savesInFlight[feedId] ?? 0) - 1, 0)
        scheduleRefresh(forFeedId: feedId)
    }

    /// NewsBlurAppDelegate.m calls this when a classifier save fails. Its start dropped any refresh already out, and
    /// the server's scores are right whether or not the change reached it, so they replace the local guess for a
    /// change the server may never have saved.
    func saveDidFail(forFeedId feedId: String) {
        updatePendingRefresh(forFeedId: feedId) { $0.changesScoresOnlyTheServerKnows = true }
        saveDidEnd(forFeedId: feedId)
    }

    /// The refresh is only worked out once the debounce ends, since the recalculation that notes uncertain stories
    /// can run after a fast save has already answered.
    private func scheduleRefresh(forFeedId feedId: String) {
        let generation = invalidateRefreshes(forFeedId: feedId)
        guard let list = currentStoryList() else { return }
        afterDebounce(Self.debounce) { [weak self] in
            self?.refresh(feedId: feedId, generation: generation, list: list)
        }
    }

    @discardableResult
    private func invalidateRefreshes(forFeedId feedId: String) -> Int {
        let generation = (generations[feedId] ?? 0) + 1
        generations[feedId] = generation
        return generation
    }

    /// Needs for a list the reader has left are dropped: a list loaded again comes with the server's scores.
    private func updatePendingRefresh(forFeedId feedId: String, _ update: (inout PendingRefresh) -> Void) {
        guard let list = currentStoryList() else { return }
        var pending = pendingRefreshes[feedId].flatMap { $0.list == list ? $0 : nil } ?? PendingRefresh(list: list)
        update(&pending)
        pendingRefreshes[feedId] = pending
    }

    /// The refresh a save asks for takes in the stories near the screen as well as the uncertain ones. The batches
    /// that follow it ask only for the stories the earlier ones had no room for.
    private func refresh(feedId: String, generation: Int, list: StoryList, includesStoriesNearTheScreen: Bool = true) {
        guard let appDelegate, let host = appDelegate.url, isCurrent(feedId: feedId, generation: generation, list: list),
              let pending = pendingRefreshes[feedId] else {
            return
        }
        let batch = pending.list == list && pending.isNeeded
            ? nextBatch(forFeedId: feedId, pending: pending, includesStoriesNearTheScreen: includesStoriesNearTheScreen)
            : nil
        guard let batch, !batch.storyHashes.isEmpty else {
            pendingRefreshes[feedId] = nil
            return
        }
        let parameters: [String: Any] = ["h": batch.storyHashes, "include_hidden": "true",
                                         "include_story_content": "false", "page": "0"]
        appDelegate.get("\(host)/reader/river_stories", parameters: parameters, success: { [weak self] _, response in
            MainActor.assumeIsolated {
                self?.apply(response, batch: batch, feedId: feedId, generation: generation, list: list)
            }
        }, failure: { _, _ in
            // A failed refresh leaves the local recalculation in place and never shows an error. Its stories stay
            // pending, and the next save's refresh asks again.
        })
    }

    private func apply(_ response: Any?, batch: Batch, feedId: String, generation: Int, list: StoryList) {
        guard isCurrent(feedId: feedId, generation: generation, list: list),
              let stories = (response as? [String: Any])?["stories"] as? [[String: Any]] else { return }
        settle(batch, feedId: feedId)
        show(Self.scoring(of: stories, requestedHashes: Set(batch.storyHashes)), feedId: feedId)

        // One batch at a time. The next one goes through the same checks, so a save that starts while it's out drops
        // it, and the save's own refresh asks again for every story still waiting.
        if pendingRefreshes[feedId] != nil {
            refresh(feedId: feedId, generation: invalidateRefreshes(forFeedId: feedId), list: list,
                    includesStoriesNearTheScreen: false)
        }
    }

    /// The batch's stories have the server's scores, and the ones it had no room for wait for the next batch. Those
    /// are every story still pending that's loaded, since a story noted uncertain after the batch was sent came with
    /// a save, which drops the batch before it lands. A story no longer loaded is dropped.
    private func settle(_ batch: Batch, feedId: String) {
        guard var pending = pendingRefreshes[feedId] else { return }
        pending.changesScoresOnlyTheServerKnows = false
        pending.uncertainStoryHashes = batch.unsentStoryHashes
        pendingRefreshes[feedId] = pending.isNeeded ? pending : nil
    }

    private func show(_ scoring: [String: [String: Any]], feedId: String) {
        guard !scoring.isEmpty, let appDelegate, let collection = appDelegate.storiesCollection else { return }

        var changed = false
        let updatedStories: [Any] = (collection.activeFeedStories ?? []).map { item in
            guard let story = item as? NSDictionary, Self.feedId(of: story) == feedId,
                  let hash = story["story_hash"] as? String, let fields = scoring[hash],
                  let updatedStory = story.mutableCopy() as? NSMutableDictionary else { return item }
            updatedStory.addEntries(from: fields)
            // Every key the server sends wins, 0s included, and a key it leaves out keeps the score the app worked
            // out, like an author regex from a server that didn't score one yet.
            if let refreshed = fields["intelligence"] as? [String: Any] {
                let local = story["intelligence"] as? [String: Any] ?? [:]
                updatedStory["intelligence"] = local.merging(refreshed) { $1 }
            }
            guard !updatedStory.isEqual(story) else { return item }
            // Like recalculateIntelligenceScores:, a story the reader can see stays in the list if its score drops.
            let score = NewsBlurAppDelegate.computeStoryScore(story["intelligence"] as? [AnyHashable: Any])
            if score >= appDelegate.selectedIntelligence {
                updatedStory["sticky"] = true
            }
            changed = true
            return updatedStory
        }
        guard changed else { return }

        appDelegate.showRescoredStories(updatedStories)
        appDelegate.feedDetailViewController?.reload()
        appDelegate.storyPagesViewController?.refreshHeaders()
    }

    private func isCurrent(feedId: String, generation: Int, list: StoryList) -> Bool {
        generations[feedId] == generation && (savesInFlight[feedId] ?? 0) == 0 && currentStoryList() == list
    }

    private func currentStoryList() -> StoryList? {
        guard let collection = appDelegate?.storiesCollection else { return nil }
        return StoryList(collection: ObjectIdentifier(collection),
                         feedId: collection.activeFeedIdStr,
                         folder: collection.activeFolder,
                         fetchRequestId: appDelegate?.feedDetailViewController?.fetchRequestId ?? 0)
    }

    // MARK: Choosing stories

    /// The site's loaded stories the next request asks for: the pending ones, and for a save's refresh those within a
    /// page of the screen, nearest the screen first and at most one batch, sent in list order. The rest wait for the
    /// next batch.
    private func nextBatch(forFeedId feedId: String, pending: PendingRefresh, includesStoriesNearTheScreen: Bool) -> Batch {
        guard let collection = appDelegate?.storiesCollection else { return Batch(storyHashes: [], unsentStoryHashes: []) }
        let stories = collection.activeFeedStories ?? []
        let locations = (collection.activeFeedStoryLocations as? [NSNumber] ?? []).map(\.intValue)
            .filter { stories.indices.contains($0) }
        let windows = Self.nearbyWindows(around: storyLocationsOnScreen(), locations: locations, storyCount: stories.count)
        let anchors = windows.map(\.anchor)

        var candidates: [(index: Int, hash: String)] = []
        for (index, item) in stories.enumerated() {
            guard let story = item as? NSDictionary, Self.feedId(of: story) == feedId,
                  let hash = story["story_hash"] as? String else { continue }
            if pending.uncertainStoryHashes.contains(hash) ||
                (includesStoriesNearTheScreen && windows.contains(where: { $0.indexes.contains(index) })) {
                candidates.append((index, hash))
            }
        }
        func distance(_ index: Int) -> Int {
            anchors.map { abs($0 - index) }.min() ?? index
        }
        let nearestFirst = candidates.sorted { (distance($0.index), $0.index) < (distance($1.index), $1.index) }
        return Batch(storyHashes: nearestFirst.prefix(Self.batchSize).sorted { $0.index < $1.index }.map(\.hash),
                     unsentStoryHashes: Set(nearestFirst.dropFirst(Self.batchSize).map(\.hash)))
    }

    /// The stories within nearbyStoryCount of each story on screen, counted along the list the reader sees, with the
    /// hidden stories between them, which a new score may show. Each window is a range of activeFeedStories indexes
    /// around its anchor's index. With nothing on screen to go by, the top of the list.
    private static func nearbyWindows(around shownLocations: [Int], locations: [Int],
                                      storyCount: Int) -> [(anchor: Int, indexes: ClosedRange<Int>)] {
        guard storyCount > 0 else { return [] }
        guard !locations.isEmpty else {
            return [(0, 0...min(storyCount - 1, nearbyStoryCount * 2))]
        }
        let anchors = shownLocations.filter { locations.indices.contains($0) }
        return (anchors.isEmpty ? [0] : anchors).map { location in
            let first = max(location - nearbyStoryCount, 0)
            let last = min(location + nearbyStoryCount, locations.count - 1)
            // The ends of the list take the hidden stories before the first story shown and after the last.
            let firstIndex = first == 0 ? 0 : locations[first]
            let lastIndex = last == locations.count - 1 ? storyCount - 1 : locations[last]
            return (locations[location], firstIndex...lastIndex)
        }
    }

    /// Where the reader is in the list: the open story, and the story list row FeedDetailViewController.swift last
    /// showed, as locations in the list the reader sees.
    private func storyLocationsOnScreen() -> [Int] {
        guard let appDelegate, let collection = appDelegate.storiesCollection else { return [] }
        var shown: [Int] = []
        let open = collection.locationOfActiveStory()
        if open >= 0 {
            shown.append(open)
        }
        if let row = appDelegate.feedDetailViewController?.lastShownStoryLocation {
            shown.append(row)
        }
        return shown
    }

    /// The scoring fields of each requested story. apps/clustering/models.py can fold a requested story into another
    /// one's cluster_stories, which carry its intelligence, score and prompt_classifiers too, so an empty list clears
    /// a folded story's AI pills. A member from a server that doesn't send prompt_classifiers leaves them as they were.
    private static func scoring(of stories: [[String: Any]], requestedHashes: Set<String>) -> [String: [String: Any]] {
        var scoring: [String: [String: Any]] = [:]
        for story in stories {
            for member in [story] + (story["cluster_stories"] as? [[String: Any]] ?? []) {
                guard let hash = member["story_hash"] as? String, requestedHashes.contains(hash), scoring[hash] == nil,
                      member["intelligence"] is [String: Any] else { continue }
                scoring[hash] = member.filter { scoringKeys.contains($0.key) }
            }
        }
        return scoring
    }

    /// Stories carry their site's id as a number, and NewsBlurAppDelegate.m passes it to classifier saves as a string.
    private static func feedId(of story: NSDictionary) -> String {
        "\(story["story_feed_id"] ?? "")"
    }
}
