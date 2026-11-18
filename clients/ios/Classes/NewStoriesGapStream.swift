//
//  NewStoriesGapStream.swift
//  NewsBlur
//
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import os
import SwiftUI
import UIKit

/// NewStoriesGapStream.swift merges a page of the list's stories, loaded afresh, into the stories already listed.
///
/// A cursor starts at the top of a newest-first list, or the end of an oldest-first one. A story already listed moves
/// the cursor to just after it; any other story goes in at the cursor, which moves past it. A listed story the page
/// should already have reached, being dated before the incoming one in the list's order, can't be in the server's
/// answer any more (read elsewhere, in an unread list), so the cursor moves past it too.
enum NewStoriesGapMerge {
    struct Result {
        var stories: [[String: Any]]
        /// Where the next page's first unlisted story goes.
        var cursor: Int
        /// The stories this page added, in page order.
        var inserted: [String]
        /// The page's last story is the list's last: the fresh pages have caught up with the stories already listed.
        var reachedEnd: Bool
    }

    static func merge(page: [[String: Any]], into listed: [[String: Any]], cursor start: Int,
                      oldestFirst: Bool) -> Result {
        var stories = listed
        var cursor = min(max(start, 0), stories.count)
        var inserted: [String] = []
        var lastPlaced: Int?
        for story in page {
            guard let hash = story["story_hash"] as? String else { continue }
            if let index = stories.firstIndex(where: { $0["story_hash"] as? String == hash }) {
                cursor = max(cursor, index + 1)
                lastPlaced = index
                continue
            }
            let timestamp = RealtimeNewStories.timestamp(of: story)
            while cursor < stories.count {
                let listedTimestamp = RealtimeNewStories.timestamp(of: stories[cursor])
                guard oldestFirst ? listedTimestamp < timestamp : listedTimestamp > timestamp else { break }
                cursor += 1
            }
            stories.insert(story, at: cursor)
            inserted.append(hash)
            lastPlaced = cursor
            cursor += 1
        }
        return Result(stories: stories, cursor: cursor, inserted: inserted,
                      reachedEnd: lastPlaced.map { $0 == stories.count - 1 } ?? false)
    }
}

/// The open list's pages, requested afresh from page 1 after the new stories pill held more stories than it fetches
/// ahead (`RealtimeNewStories.prefetchCap`). The server rebuilds its paging whenever page 1 is requested, so every later
/// page of this list comes from here until the pages catch up with the stories already listed, when the list's own
/// paging takes over at the same page.
@MainActor final class NewStoriesGapStream: NSObject {
    static let logger = Logger(subsystem: "com.newsblur.NewsBlur", category: "Realtime")

    let listKey: String
    let oldestFirst: Bool
    /// The last page loaded; 0 until the first arrives.
    var page = 0
    var isLoading = false
    /// The story just above the cursor, or nil while the cursor is at the top of the list.
    var cursorAfterHash: String?
    /// FeedDetailObjCViewController.m's fetchNextPage: callbacks waiting for the next page.
    var callbacks: [() -> Void] = []
    /// The SwiftUI grid's gap is on screen (FeedDetailGridView.swift).
    var isGapOnScreen = false

    init(listKey: String, oldestFirst: Bool, cursorAfterHash: String?) {
        self.listKey = listKey
        self.oldestFirst = oldestFirst
        self.cursorAfterHash = cursorAfterHash
    }

    func cursorIndex(in stories: [[String: Any]]) -> Int {
        guard let cursorAfterHash else { return 0 }
        guard let index = stories.firstIndex(where: { $0["story_hash"] as? String == cursorAfterHash }) else {
            return oldestFirst ? stories.count : 0
        }
        return index + 1
    }
}

extension FeedDetailViewController {
    private static var newStoriesStreamKey: UInt8 = 0

    var newStoriesStream: NewStoriesGapStream? {
        get { objc_getAssociatedObject(self, &Self.newStoriesStreamKey) as? NewStoriesGapStream }
        set { objc_setAssociatedObject(self, &Self.newStoriesStreamKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var listedStories: [[String: Any]] {
        (storiesCollection.activeFeedStories ?? []).compactMap { $0 as? [String: Any] }
    }

    /// Where FeedDetailObjCViewController.m and StoryCache.swift draw the gap: the index in StoriesCollection's stories
    /// the next page's stories go in at, or NSNotFound when there's no gap. An oldest-first list fills in at its end,
    /// so its bottom loader stands in for the gap.
    @objc var newStoriesGapStoryIndex: Int {
        guard let stream = newStoriesStream, !stream.oldestFirst else { return NSNotFound }
        let stories = listedStories
        let cursor = stream.cursorIndex(in: stories)
        return cursor < stories.count ? cursor : NSNotFound
    }

    /// RealtimeUpdates.swift: the pill held more than it fetched. Load the list's newest page and fill in below it.
    func startNewStoriesStream(listKey: String, oldestFirst: Bool) {
        cancelNewStoriesStream()
        cancelNewStoriesArrival()
        let stories = listedStories
        let stream = NewStoriesGapStream(listKey: listKey, oldestFirst: oldestFirst,
                                         cursorAfterHash: oldestFirst ? stories.last?["story_hash"] as? String : nil)
        newStoriesStream = stream
        // The page the list's own paging was loading belongs to the server's old snapshot.
        abandonPageInFlight()
        pageFinished = false
        if !oldestFirst {
            let reduceMotion = ReaderMotion.reduceMotion
            if let scrollView = isLegacyTable ? storyTitlesTable : gridScrollView {
                let top = -scrollView.adjustedContentInset.top
                if scrollView.contentOffset.y > top + 1 {
                    newStoriesListScrollsItself()
                    scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: top), animated: !reduceMotion)
                }
            }
        }
        reloadImmediately()
        loadNewStoriesStreamPage()
    }

    /// Another list opened, the list loaded again, or its filters changed.
    @objc func cancelNewStoriesStream() {
        newStoriesStream = nil
    }

    /// FeedDetailObjCViewController.m's later pages come from the stream while it runs.
    @objc func newStoriesStreamTakesNextPage(_ callback: (() -> Void)?) -> Bool {
        guard let stream = newStoriesStream else { return false }
        if let callback { stream.callbacks.append(callback) }
        loadNewStoriesStreamPage()
        return true
    }

    /// FeedDetailObjCViewController.m showed the table's gap row.
    @objc func newStoriesGapDidAppear() {
        loadNewStoriesStreamPage()
    }

    /// FeedDetailGridView.swift's gap came on screen or left it.
    func newStoriesGapVisibilityChanged(_ onScreen: Bool) {
        newStoriesStream?.isGapOnScreen = onScreen
        if onScreen { loadNewStoriesStreamPage() }
    }

    private var isNewStoriesStreamEdgeInReach: Bool {
        guard let stream = newStoriesStream else { return false }
        if isLegacyTable { return isNewStoriesGapNearViewport() }
        if stream.oldestFirst { return (lastShownStoryLocation ?? 0) >= Int(storiesCollection.storyLocationsCount) - 5 }
        return stream.isGapOnScreen
    }

    func loadNewStoriesStreamPage() {
        guard let stream = newStoriesStream, !stream.isLoading else { return }
        // NewStoriesPill.swift's arrival animates rows already on screen; the next page waits until it settles.
        if newStoriesTableArrival != nil || storyCache.newStoryArrivals.isSettling {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.loadNewStoriesStreamPage() }
            return
        }
        let page = stream.page + 1
        guard let url = newStoriesStreamRequestURL(forPage: page) else { return }
        stream.isLoading = true
        let feedId = storiesCollection.isRiverView ? nil : storiesCollection.activeFeed.map { "\($0["id"] ?? "")" }
        appDelegate.get(url, parameters: nil, success: { [weak self, weak stream] _, response in
            MainActor.assumeIsolated {
                guard let self, let stream, self.newStoriesStream === stream else { return }
                stream.isLoading = false
                guard let results = response as? [String: Any],
                      RealtimeUpdates.shared.openStoryList()?.key == stream.listKey,
                      feedId == nil || "\(results["feed_id"] ?? "")" == feedId else {
                    self.cancelNewStoriesStream()
                    return
                }
                self.applyNewStoriesStreamPage(results, page: page, stream: stream)
            }
        }, failure: { [weak stream] _, _ in
            MainActor.assumeIsolated {
                // The gap stays; showing it again, or reaching the bottom, asks again.
                stream?.isLoading = false
                stream?.callbacks = []
            }
        })
    }

    private func applyNewStoriesStreamPage(_ results: [String: Any], page: Int, stream: NewStoriesGapStream) {
        absorbStoryPageFeedsAndClassifiers(results, feedId: "\(results["feed_id"] ?? "")")
        addNewStoriesStreamUserProfiles(results["user_profiles"] as? [[String: Any]] ?? [])
        let pageStories = results["stories"] as? [[String: Any]] ?? []
        let finished = pageStories.isEmpty
        stream.page = page
        let callbacks = stream.callbacks
        stream.callbacks = []
        let openStoryHash = appDelegate.storyPagesViewController?.currentPage?.activeStoryId

        // Merges the page and, once it has caught up with the stories already listed, hands paging back to the list.
        // Returns the stories it added that the list shows, in list order.
        let merge: () -> [String] = { [weak self] in
            guard let self else { return [] }
            let listed = self.listedStories
            let result = NewStoriesGapMerge.merge(page: pageStories, into: listed, cursor: stream.cursorIndex(in: listed),
                                                  oldestFirst: stream.oldestFirst)
            stream.cursorAfterHash = result.cursor > 0 ? result.stories[result.cursor - 1]["story_hash"] as? String : nil
            let caughtUp = finished || result.reachedEnd
            NewStoriesGapStream.logger.debug("""
                newest page \(page, privacy: .public): \(pageStories.count, privacy: .public) stories, \
                \(result.inserted.count, privacy: .public) added, cursor \(result.cursor, privacy: .public) of \
                \(result.stories.count, privacy: .public)\(caughtUp ? ", caught up" : "", privacy: .public)
                """)
            if caughtUp {
                if self.newStoriesStream === stream { self.newStoriesStream = nil }
                self.storiesCollection.feedPage = Int32(page)
                self.pageFinished = finished
            }
            guard !result.inserted.isEmpty else { return [] }
            self.storiesCollection.replaceStoriesKeepingReadState(result.stories)
            return result.inserted.compactMap { hash -> (String, Int)? in
                let location = Int(self.storiesCollection.location(ofStoryId: hash))
                return location >= 0 ? (hash, location) : nil
            }.sorted { $0.1 < $1.1 }.map(\.0)
        }

        let reload: () -> Void = { [weak self] in self?.reloadKeepingOpenStory(openStoryHash) }
        let dryRun = NewStoriesGapMerge.merge(page: pageStories, into: listedStories,
                                              cursor: stream.cursorIndex(in: listedStories), oldestFirst: stream.oldestFirst)
        if page == 1 && !dryRun.inserted.isEmpty {
            // The newest stories slide in at the top, like the pill's own (NewStoriesPill.swift).
            presentNewStories(atBottom: stream.oldestFirst, insert: merge, reload: reload)
        } else {
            let anchor = gapIsAboveViewport(stream: stream) ? visibleStoryAnchor() : nil
            _ = merge()
            reload()
            if let anchor { restoreVisibleStoryAnchor(anchor) }
        }
        callbacks.forEach { $0() }

        if newStoriesStream === stream {
            if dryRun.inserted.isEmpty && isNewStoriesStreamEdgeInReach {
                DispatchQueue.main.async { [weak self] in self?.loadNewStoriesStreamPage() }
            }
        } else if !pageFinished, isLegacyTable, isNewStoriesGapNearViewport() {
            // The list's own paging carries on from here; its bottom is already in view.
            if storiesCollection.isRiverView { fetchRiverPage(storiesCollection.feedPage + 1, withCallback: nil) }
            else { fetchFeedDetail(storiesCollection.feedPage + 1, withCallback: nil) }
        }
    }

    private func addNewStoriesStreamUserProfiles(_ profiles: [[String: Any]]) {
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

    /// Whether the reader has scrolled past the gap, so stories filling it would push the rows on screen down.
    private func gapIsAboveViewport(stream: NewStoriesGapStream) -> Bool {
        guard isLegacyTable, let anchor = visibleStoryAnchor() else { return false }
        let stories = listedStories
        guard let index = stories.firstIndex(where: { $0["story_hash"] as? String == anchor.hash }) else { return false }
        return index >= stream.cursorIndex(in: stories)
    }

    /// The first story row on screen and how far below the table's top it sits.
    private func visibleStoryAnchor() -> (hash: String, screenY: CGFloat)? {
        guard isLegacyTable, let table = storyTitlesTable else { return nil }
        let visibleTop = table.contentOffset.y + table.adjustedContentInset.top
        for cell in table.visibleCells.sorted(by: { $0.frame.minY < $1.frame.minY }) where cell.frame.maxY > visibleTop {
            guard let hash = (cell as? FeedDetailTableCell)?.storyHash, !hash.isEmpty else { continue }
            return (hash, cell.frame.minY - table.contentOffset.y)
        }
        return nil
    }

    private func restoreVisibleStoryAnchor(_ anchor: (hash: String, screenY: CGFloat)) {
        guard let table = storyTitlesTable else { return }
        let location = storiesCollection.location(ofStoryId: anchor.hash)
        guard location >= 0, let path = indexPath(forStoryLocation: location) else { return }
        table.layoutIfNeeded()
        newStoriesListScrollsItself()
        table.contentOffset = CGPoint(x: table.contentOffset.x, y: table.rectForRow(at: path).minY - anchor.screenY)
    }
}

/// FeedDetailGridView.swift's gap between the newest page's cards and the cards already listed.
struct NewStoriesGapView: View {
    let isGrid: Bool
    @State private var animate = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: isGrid ? 10 : 0)
            .fill(animate ? Color.themed([0x5C89C9, 0x666666]) : Color.themed([0xE1EBFF, 0x222222]))
            .frame(height: isGrid ? 120 : 60)
            .padding(.vertical, isGrid ? 0 : 8)
            .onAppear {
                animate.toggle()
                NewsBlurAppDelegate.shared?.feedDetailViewController?.newStoriesGapVisibilityChanged(true)
            }
            .onDisappear {
                NewsBlurAppDelegate.shared?.feedDetailViewController?.newStoriesGapVisibilityChanged(false)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 1).repeatForever(autoreverses: true), value: animate)
            .accessibilityLabel(Text(NBLocalization.text("Loading...")))
    }
}
