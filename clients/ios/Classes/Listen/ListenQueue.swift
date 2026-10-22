//
//  ListenQueue.swift
//  NewsBlur
//
//  Created by Claude on 2026-10-21.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import Foundation
import UIKit

/// One entry in the media queue apps/media_player keeps for the account (ListenQueue.swift). Listen stories use the
/// pseudo URL /listen/story/<story_hash>. Anything else, such as a podcast episode queued on the web, is carried
/// along untouched so reordering never drops it.
struct ListenQueueItem: Identifiable, Equatable {
    let storyHash: String
    let mediaURL: String
    let mediaType: String
    let title: String
    let feedId: String?

    var id: String { "\(storyHash)|\(mediaURL)" }
    var isListen: Bool { mediaType == ListenQueue.listenMediaType }

    init?(json: Any?) {
        guard let dictionary = ListenJSON.dictionary(json) else { return nil }
        storyHash = ListenJSON.string(dictionary["story_hash"]) ?? ""
        mediaURL = ListenJSON.string(dictionary["media_url"]) ?? ""
        mediaType = ListenJSON.string(dictionary["media_type"]) ?? ""
        title = ListenPlayer.decodedTitle(dictionary["media_title"])
        let feed = ListenJSON.string(dictionary["feed_id"]) ?? ""
        feedId = feed.isEmpty || feed == "0" ? nil : feed
    }

    init(story: [String: Any]) {
        storyHash = story["story_hash"] as? String ?? ""
        mediaURL = ListenQueue.mediaURL(forStoryHash: storyHash)
        mediaType = ListenQueue.listenMediaType
        title = ListenPlayer.decodedTitle(story["story_title"])
        feedId = ListenJSON.string(story["story_feed_id"])
    }

    /// The story ListenPlayer.swift starts: the full story when this device has it, else what the queue knows,
    /// which is enough to ask /listen/manifest for it.
    var story: [String: Any] {
        let appDelegate = NewsBlurAppDelegate.shared()
        let loaded = (appDelegate?.storiesCollection?.activeFeedStories ?? []).compactMap { $0 as? [AnyHashable: Any] }
        if let match = loaded.first(where: { ($0["story_hash"] as? String) == storyHash }) {
            return ListenPlayer.stringKeyed(match)
        }
        if let stored = appDelegate?.getStory(storyHash) as? [AnyHashable: Any], !stored.isEmpty {
            return ListenPlayer.stringKeyed(stored)
        }
        var story: [String: Any] = ["story_hash": storyHash, "story_title": title]
        if let feedId {
            story["story_feed_id"] = feedId
        }
        return story
    }

    static func == (lhs: ListenQueueItem, rhs: ListenQueueItem) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.mediaType == rhs.mediaType
    }
}

/// ListenQueue.swift is Up Next: the account's media queue in apps/media_player, shared with the web and Android.
/// Edits show at once and are sent to the server; the server's answer replaces the local copy once no other edit
/// is still on its way, so a slow reply can't undo a newer change.
final class ListenQueue: NSObject, ObservableObject {
    static let shared = ListenQueue()
    static let didChange = Notification.Name("ListenQueueDidChange")
    static let listenMediaType = "listen"

    /// Every queued item in order, including ones mobile doesn't play.
    @Published private(set) var items: [ListenQueueItem] = []
    private var pendingWrites = 0
    private var hasLoaded = false

    private var appDelegate: NewsBlurAppDelegate? { NewsBlurAppDelegate.shared() }

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    static func mediaURL(forStoryHash hash: String) -> String {
        "/listen/story/\(hash)"
    }

    /// The Listen stories in Up Next, in order.
    var listenItems: [ListenQueueItem] { items.filter(\.isListen) }

    func contains(storyHash: String?) -> Bool {
        guard let storyHash else { return false }
        return listenItems.contains { $0.storyHash == storyHash }
    }

    /// The story's place in Up Next counting from 1, for the "Added to Up Next · 2nd" toast.
    func position(ofStoryHash storyHash: String) -> Int? {
        listenItems.firstIndex { $0.storyHash == storyHash }.map { $0 + 1 }
    }

    // MARK: - Reading

    /// GET /media_player/playback_state, when Now Playing opens, the app returns to the foreground and the feed
    /// list loads (FeedsObjCViewController.m through ListenStoryBridge.swift).
    func refresh() {
        guard let appDelegate else { return }
        appDelegate.get(ListenAPI.shared.baseURL + "/media_player/playback_state", parameters: [:], success: { [weak self] _, response in
            guard let self, self.pendingWrites == 0 else { return }
            self.apply(response)
        }, failure: { _, error in
            NSLog("Listen couldn't load Up Next: %@", (error as NSError?) ?? NSError())
        })
    }

    /// Loads Up Next the first time something needs it.
    func refreshIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        refresh()
    }

    @objc private func appWillEnterForeground() {
        refresh()
    }

    /// Logout or a new server: the old account's queue is forgotten (ListenStoryBridge.swift).
    func reset() {
        pendingWrites = 0
        hasLoaded = false
        replaceItems([])
    }

    // MARK: - Editing

    /// Adds the story to the end of Up Next and returns its place there.
    @discardableResult
    func add(story: [String: Any]) -> Int {
        let item = ListenQueueItem(story: story)
        guard !item.storyHash.isEmpty else { return 0 }
        var updated = items.filter { $0.id != item.id }
        updated.append(item)
        replaceItems(updated)
        var parameters = ["story_hash": item.storyHash, "media_url": item.mediaURL, "media_type": item.mediaType,
                          "media_title": item.title, "feed_id": item.feedId ?? "0"]
        if let feedId = item.feedId {
            parameters["image_url"] = ListenAPI.shared.baseURL + "/rss_feeds/icon/" + feedId
        }
        write("/media_player/add_to_media_queue", parameters: parameters)
        return position(ofStoryHash: item.storyHash) ?? listenItems.count
    }

    func remove(storyHash: String) {
        let mediaURL = Self.mediaURL(forStoryHash: storyHash)
        guard items.contains(where: { $0.storyHash == storyHash && $0.mediaURL == mediaURL }) else { return }
        replaceItems(items.filter { !($0.storyHash == storyHash && $0.mediaURL == mediaURL) })
        write("/media_player/remove_from_media_queue", parameters: ["story_hash": storyHash, "media_url": mediaURL])
    }

    /// Now Playing's swipe to delete, with offsets into `listenItems`.
    func removeListenItems(atOffsets offsets: IndexSet) {
        let listen = listenItems
        for offset in offsets where offset < listen.count {
            remove(storyHash: listen[offset].storyHash)
        }
    }

    /// Now Playing's drag to reorder, with offsets into `listenItems`. Items other platforms queued keep their
    /// places, and the server gets the whole queue because /media_player/reorder_media_queue drops anything left out.
    func moveListenItems(fromOffsets source: IndexSet, toOffset destination: Int) {
        var listen = listenItems
        listen.move(fromOffsets: source, toOffset: destination)
        let updated = Self.merging(listenOrder: listen, into: items)
        guard updated.map(\.id) != items.map(\.id) else { return }
        replaceItems(updated)
        let order = updated.map { ["story_hash": $0.storyHash, "media_url": $0.mediaURL] }
        guard let data = try? JSONSerialization.data(withJSONObject: order) else { return }
        write("/media_player/reorder_media_queue", parameters: ["queue_order": String(decoding: data, as: UTF8.self)])
    }

    /// Puts `listenOrder` into the slots Listen stories hold in `items`, leaving everything else where it was.
    static func merging(listenOrder: [ListenQueueItem], into items: [ListenQueueItem]) -> [ListenQueueItem] {
        var reordered = listenOrder.makeIterator()
        return items.map { item in item.isListen ? (reordered.next() ?? item) : item }
    }

    /// The first Listen story in Up Next, taken off the queue as it starts playing (ListenPlayer.swift).
    func takeFirstListenItem() -> ListenQueueItem? {
        guard let first = listenItems.first else { return nil }
        remove(storyHash: first.storyHash)
        return first
    }

    /// POST /media_player/add_to_media_history for the story that was playing when another one started, so the
    /// web's History can resume it.
    func addToHistory(story: [String: Any], position: TimeInterval, duration: TimeInterval) {
        let item = ListenQueueItem(story: story)
        guard !item.storyHash.isEmpty else { return }
        var parameters = ["story_hash": item.storyHash, "media_url": item.mediaURL, "media_type": item.mediaType,
                          "media_title": item.title, "feed_id": item.feedId ?? "0",
                          "position": String(format: "%.1f", max(0, position)),
                          "duration": String(format: "%.1f", max(0, duration))]
        if let feedId = item.feedId {
            parameters["image_url"] = ListenAPI.shared.baseURL + "/rss_feeds/icon/" + feedId
        }
        appDelegate?.post(ListenAPI.shared.baseURL + "/media_player/add_to_media_history", parameters: parameters,
                          success: nil, failure: { _, error in
            NSLog("Listen couldn't save history: %@", (error as NSError?) ?? NSError())
        })
    }

    // MARK: - Transport

    private func write(_ path: String, parameters: [String: String]) {
        guard let appDelegate else { return }
        pendingWrites += 1
        appDelegate.post(ListenAPI.shared.baseURL + path, parameters: parameters, success: { [weak self] _, response in
            guard let self else { return }
            self.pendingWrites = max(0, self.pendingWrites - 1)
            if self.pendingWrites == 0 {
                self.apply(response)
            }
        }, failure: { [weak self] _, error in
            guard let self else { return }
            NSLog("Listen couldn't update Up Next: %@", (error as NSError?) ?? NSError())
            self.pendingWrites = max(0, self.pendingWrites - 1)
            if self.pendingWrites == 0 {
                // ListenQueue.swift puts the server's queue back when an edit didn't go through.
                self.refresh()
            }
        })
    }

    private func apply(_ response: Any?) {
        guard let json = ListenJSON.dictionary(response) else { return }
        hasLoaded = true
        let state = ListenJSON.dictionary(json["playback_state"])
        replaceItems(ListenJSON.array(state?["queue"]).compactMap { ListenQueueItem(json: $0) })
    }

    private func replaceItems(_ updated: [ListenQueueItem]) {
        guard updated != items else { return }
        items = updated
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }
}
