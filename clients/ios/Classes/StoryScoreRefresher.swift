//
//  StoryScoreRefresher.swift
//  NewsBlur
//
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import Foundation

/// StoryScoreRefresher.swift asks the server for the loaded stories' scores once a classifier save succeeds.
/// NewsBlurAppDelegate.m's recalculateIntelligenceScores: shows the change right away, but it can't run AI prompts,
/// and StoryClassifierScorer.swift keeps the server's old score wherever it can't tell. The refresh replaces those
/// guesses with what apps/reader/views.py scores now, prompt scores included.
@MainActor @objcMembers final class StoryScoreRefresher: NSObject {
    /// Saves that follow each other this closely, like tapping through a story's classifiers in the trainer, share
    /// one refresh.
    static let debounce: TimeInterval = 1
    /// apps/reader/views.py load_river_stories__redis reads at most 100 story hashes per request.
    static let batchSize = 100
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

    /// Waits out the debounce before refreshing. NewsBlurTests replace it to end the wait by hand.
    var afterDebounce: (TimeInterval, @escaping () -> Void) -> Void = { delay, work in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private weak var appDelegate: NewsBlurAppDelegate?
    /// Every save moves its site to a new generation, so only the latest save's refresh is sent or lands.
    private var generations: [String: Int] = [:]

    init(appDelegate: NewsBlurAppDelegate) {
        self.appDelegate = appDelegate
    }

    func scheduleRefresh(forFeedId feedId: String) {
        let generation = (generations[feedId] ?? 0) + 1
        generations[feedId] = generation
        guard let list = currentStoryList() else { return }
        afterDebounce(Self.debounce) { [weak self] in
            self?.refresh(feedId: feedId, generation: generation, list: list)
        }
    }

    private func refresh(feedId: String, generation: Int, list: StoryList) {
        guard let appDelegate, let host = appDelegate.url, isCurrent(feedId: feedId, generation: generation, list: list) else {
            return
        }
        let hashes = storyHashes(forFeedId: feedId)
        for start in stride(from: 0, to: hashes.count, by: Self.batchSize) {
            let batch = Array(hashes[start..<min(start + Self.batchSize, hashes.count)])
            let parameters: [String: Any] = ["h": batch, "include_hidden": "true", "page": "0"]
            appDelegate.get("\(host)/reader/river_stories", parameters: parameters, success: { [weak self] _, response in
                MainActor.assumeIsolated {
                    self?.apply(response, requestedHashes: Set(batch), feedId: feedId, generation: generation, list: list)
                }
            }, failure: { _, _ in
                // A failed refresh leaves the local recalculation in place and never shows an error.
            })
        }
    }

    private func apply(_ response: Any?, requestedHashes: Set<String>, feedId: String, generation: Int, list: StoryList) {
        guard let appDelegate, let collection = appDelegate.storiesCollection,
              isCurrent(feedId: feedId, generation: generation, list: list),
              let stories = (response as? [String: Any])?["stories"] as? [[String: Any]] else { return }
        let scoring = Self.scoring(of: stories, requestedHashes: requestedHashes)
        guard !scoring.isEmpty else { return }

        var changed = false
        let updatedStories: [Any] = (collection.activeFeedStories ?? []).map { item in
            guard let story = item as? NSDictionary, Self.feedId(of: story) == feedId,
                  let hash = story["story_hash"] as? String, let fields = scoring[hash],
                  let updatedStory = story.mutableCopy() as? NSMutableDictionary else { return item }
            updatedStory.addEntries(from: fields)
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
        generations[feedId] == generation && currentStoryList() == list
    }

    private func currentStoryList() -> StoryList? {
        guard let collection = appDelegate?.storiesCollection else { return nil }
        return StoryList(collection: ObjectIdentifier(collection),
                         feedId: collection.activeFeedIdStr,
                         folder: collection.activeFolder,
                         fetchRequestId: appDelegate?.feedDetailViewController?.fetchRequestId ?? 0)
    }

    private func storyHashes(forFeedId feedId: String) -> [String] {
        (appDelegate?.storiesCollection?.activeFeedStories ?? []).compactMap { item in
            guard let story = item as? NSDictionary, Self.feedId(of: story) == feedId else { return nil }
            return story["story_hash"] as? String
        }
    }

    /// The scoring fields of each requested story. apps/clustering/models.py can fold a requested story into another
    /// one's cluster_stories, which carry its intelligence and score too.
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
