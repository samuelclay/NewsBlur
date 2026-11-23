//
//  NewStoriesNewestPage.swift
//  NewsBlur
//
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import UIKit

/// NewStoriesNewestPage.swift: tapping the new stories pill when more stories wait than it keeps fetched
/// (`RealtimeNewStories.prefetchCap`) shows a newest-first list as if it had just opened. The newest-dated waiting
/// stories, already fetched (RealtimeNewStoryBuffer), top the list at once, the stories loaded before are dropped, and
/// the list's first page joins below them when it answers.
enum NewStoriesNewestPage {
    /// The list after the tap: the newest waiting stories, then the open list's first page without them. The list's
    /// own paging skips stories already listed from its second page on (FeedDetailObjCViewController.m).
    static func stories(newest: [[String: Any]], firstPage: [[String: Any]]?) -> [[String: Any]] {
        var listed = Set(newest.compactMap { $0["story_hash"] as? String })
        var stories = newest
        for story in firstPage ?? [] {
            guard let hash = story["story_hash"] as? String, listed.insert(hash).inserted else { continue }
            stories.append(story)
        }
        return stories
    }
}

/// NewStoriesNewestPage.swift's requests for one tap: the picked stories not fetched yet, and the list's first page.
@MainActor final class NewestStoriesLoad: NSObject {
    let fetched: [[String: Any]]
    let readOverrides: [String: Bool]
    let list: RealtimeStoryList
    var profiles: [Any]
    /// The picked stories that had to be fetched, once they have been (empty if none had to be).
    var details: [[String: Any]]?
    var firstPageDone = false
    var firstPage: [String: Any]?
    /// The newest stories already replaced the list while the first page was still on its way.
    var showedNewest = false

    init(fetched: [[String: Any]], needsDetails: Bool, readOverrides: [String: Bool] = [:], profiles: [Any],
         list: RealtimeStoryList) {
        self.fetched = fetched
        self.readOverrides = readOverrides
        self.list = list
        self.profiles = profiles
        details = needsDetails ? nil : []
    }

    var isComplete: Bool { details != nil && firstPageDone }
}

extension FeedDetailViewController {
    private static var newestStoriesLoadKey: UInt8 = 0
    private static var newestStoriesShownKey: UInt8 = 0

    /// The tap past the cap still loading. Another list opening, or the list loading again, drops it.
    var newestStoriesLoad: NewestStoriesLoad? {
        get { objc_getAssociatedObject(self, &Self.newestStoriesLoadKey) as? NewestStoriesLoad }
        set { objc_setAssociatedObject(self, &Self.newestStoriesLoadKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// The stories the last tap put at the top of the list, until the list loads its first page again.
    private var newestStoriesShown: Set<String> {
        get { objc_getAssociatedObject(self, &Self.newestStoriesShownKey) as? Set<String> ?? [] }
        set { objc_setAssociatedObject(self, &Self.newestStoriesShownKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// FeedDetailObjCViewController.m: the newest stories sit above the pages that also hold them, so a page holding
    /// only those is not the end of the list.
    @objc func pageRepeatsNewestStories(_ stories: [Any]) -> Bool {
        let hashes = stories.compactMap { ($0 as? [String: Any])?["story_hash"] as? String }
        let shown = newestStoriesShown
        return !hashes.isEmpty && hashes.allSatisfy { shown.contains($0) }
    }

    /// RealtimeUpdates.swift: more stories wait than the pill fetched. `fetched` and `unfetchedHashes` are the newest
    /// waiting stories, at most `RealtimeNewStories.prefetchCap` of them; they replace the list, which pages on from
    /// its first page.
    func showNewestStories(fetched: [[String: Any]], unfetchedHashes: [String], readOverrides: [String: Bool] = [:],
                           profiles: [Any], list: RealtimeStoryList) {
        cancelNewStoriesArrival()
        let load = NewestStoriesLoad(fetched: fetched, needsDetails: !unfetchedHashes.isEmpty,
                                     readOverrides: readOverrides, profiles: profiles, list: list)
        newestStoriesLoad = load
        // A folder's feed list was taken when it opened, so an unread river holds only the feeds that had unread
        // stories then. The pill takes stories from every feed in the folder, and the list's fresh paging asks for all
        // of them.
        if storiesCollection.isRiverView,
           let current = RealtimeUpdates.feedIds(of: storiesCollection, appDelegate: appDelegate) {
            let folderFeeds = storiesCollection.activeFolderFeeds ?? []
            let added = current.subtracting(folderFeeds.map { "\($0)" }).sorted()
            if !added.isEmpty { storiesCollection.activeFolderFeeds = folderFeeds + added }
        }
        // The page the list's own paging was loading belongs to the server's old snapshot; the list waits for these.
        abandonPageInFlight()
        pageFetching = true
        scrollNewestStoriesListToTop(animated: !ReaderMotion.reduceMotion)

        if !unfetchedHashes.isEmpty, let host = appDelegate.url {
            appDelegate.get("\(host)/reader/river_stories", parameters: ["h": unfetchedHashes, "include_hidden": "true"],
                            success: { [weak self, weak load] _, response in
                MainActor.assumeIsolated {
                    guard let self, let load else { return }
                    let results = response as? [String: Any]
                    load.details = RealtimeNewStories.applying(load.readOverrides,
                                                               to: results?["stories"] as? [[String: Any]] ?? [])
                    load.profiles += results?["user_profiles"] as? [Any] ?? []
                    self.completeNewestStories(load)
                }
            }, failure: { [weak self, weak load] _, _ in
                MainActor.assumeIsolated {
                    guard let self, let load else { return }
                    load.details = []
                    self.completeNewestStories(load)
                }
            })
        } else {
            load.details = []
        }

        if let url = newestStoriesRequestURL(forPage: 1) {
            appDelegate.get(url, parameters: nil, success: { [weak self, weak load] _, response in
                MainActor.assumeIsolated {
                    guard let self, let load else { return }
                    load.firstPage = response as? [String: Any]
                    load.firstPageDone = true
                    self.completeNewestStories(load)
                }
            }, failure: { [weak self, weak load] _, _ in
                MainActor.assumeIsolated {
                    guard let self, let load else { return }
                    load.firstPageDone = true
                    self.completeNewestStories(load)
                }
            })
        } else {
            load.firstPageDone = true
        }
        completeNewestStories(load)
    }

    /// Another list opened, or the list loaded again: a tap still loading must not land in it.
    @objc func cancelNewestStories() {
        newestStoriesShown = []
        guard newestStoriesLoad != nil else { return }
        newestStoriesLoad = nil
        pageFetching = false
    }

    /// Replaces the list with the newest stories as soon as all of them are here, and adds the first page below them
    /// once it answers, if the list is still the one the reader tapped in.
    func completeNewestStories(_ load: NewestStoriesLoad) {
        guard newestStoriesLoad === load, let details = load.details else { return }
        guard load.firstPageDone else {
            // NewStoriesNewestPage.swift: the stories the tap shows don't wait on the list's first page, and the list's
            // own paging waits for that page.
            guard !load.showedNewest else { return }
            load.showedNewest = true
            replaceWithNewestStories(RealtimeNewStories.insertable(load.fetched + details, list: load.list, knownHashes: []),
                                     firstPage: nil, profiles: load.profiles)
            pageFetching = true
            return
        }
        newestStoriesLoad = nil
        guard !load.showedNewest else {
            appendFirstPageBelowNewestStories(load.firstPage)
            return
        }
        let newest = RealtimeNewStories.insertable(load.fetched + details, list: load.list, knownHashes: [])
        replaceWithNewestStories(newest, firstPage: load.firstPage, profiles: load.profiles)
    }

    /// The first page answered after the newest stories showed: its stories not shown yet join below them, and the list
    /// pages on from its second page. Without it, the list's paging starts again at its first page.
    func appendFirstPageBelowNewestStories(_ firstPage: [String: Any]?) {
        pageFetching = false
        guard let firstPage else { return }
        let openStoryHash = appDelegate.storyPagesViewController?.currentPage?.activeStoryId
        absorbStoryPageFeedsAndClassifiers(firstPage, feedId: "\(firstPage["feed_id"] ?? "")")
        addNewestStoriesUserProfiles((firstPage["user_profiles"] as? [Any] ?? []).compactMap { $0 as? [String: Any] })
        let listed = storiesCollection.activeFeedStories as? [[String: Any]] ?? []
        let pageStories = firstPage["stories"] as? [[String: Any]] ?? []
        storiesCollection.replaceStoriesKeepingReadState(NewStoriesNewestPage.stories(newest: listed, firstPage: pageStories))
        storiesCollection.feedPage = 1
        pageFinished = pageStories.isEmpty
        reloadKeepingOpenStory(openStoryHash)
    }

    /// Shows `newest` as the whole list, then the first page of the list without them, and pages on from there.
    /// `firstPage` is nil when it couldn't load; the list's paging then starts again at its first page.
    func replaceWithNewestStories(_ newest: [[String: Any]], firstPage: [String: Any]?, profiles: [Any]) {
        let openStoryHash = appDelegate.storyPagesViewController?.currentPage?.activeStoryId
        var profiles = profiles
        if let firstPage {
            absorbStoryPageFeedsAndClassifiers(firstPage, feedId: "\(firstPage["feed_id"] ?? "")")
            profiles += firstPage["user_profiles"] as? [Any] ?? []
        }
        addNewestStoriesUserProfiles(profiles.compactMap { $0 as? [String: Any] })
        let pageStories = firstPage?["stories"] as? [[String: Any]]
        storiesCollection.replaceStoriesKeepingReadState(NewStoriesNewestPage.stories(newest: newest, firstPage: pageStories))
        newestStoriesShown = Set(newest.compactMap { $0["story_hash"] as? String })
        forgetFirstPageLoad()
        storiesCollection.feedPage = firstPage == nil ? 0 : 1
        pageFetching = false
        pageFinished = pageStories?.isEmpty ?? false
        // Every row enters as when the list opens.
        ReaderMotion.session(self).reset()
        storyCache.motionSession.reset()
        scrollNewestStoriesListToTop(animated: false)
        reloadKeepingOpenStory(openStoryHash)
    }

    private func scrollNewestStoriesListToTop(animated: Bool) {
        guard let scrollView = isLegacyTable ? storyTitlesTable : gridScrollView else { return }
        let top = -scrollView.adjustedContentInset.top
        guard scrollView.contentOffset.y > top + 1 else { return }
        newStoriesListScrollsItself()
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: top), animated: animated)
    }

    private func addNewestStoriesUserProfiles(_ profiles: [[String: Any]]) {
        guard !profiles.isEmpty else { return }
        let known = Set((storiesCollection.activeFeedUserProfiles ?? []).compactMap { ($0 as? [String: Any])?["id"].map { "\($0)" } })
        let added = profiles.filter { profile in profile["id"].map { !known.contains("\($0)") } ?? false }
        if !added.isEmpty { storiesCollection.addFeedUserProfiles(added) }
    }

    func reloadKeepingOpenStory(_ openStoryHash: String?) {
        reloadImmediately()
        if let openStoryHash {
            let location = storiesCollection.location(ofStoryId: openStoryHash)
            if location >= 0 { appDelegate.storyPagesViewController?.preserveCurrentPage(atLocation: location) }
        }
        appDelegate.storyPagesViewController?.setNextPreviousButtons()
    }
}
