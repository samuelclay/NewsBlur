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
/// pseudo URL /listen/story/<story_hash>, and podcast episodes and other story audio (media_type "audio") play in
/// ListenMediaPlayer.swift. Anything else, such as a video queued on the web, is carried along untouched so
/// reordering never drops it.
struct ListenQueueItem: Identifiable, Equatable {
    let storyHash: String
    let mediaURL: String
    let mediaType: String
    let title: String
    let feedId: String?
    let imageURL: String
    let duration: TimeInterval?

    var id: String { "\(storyHash)|\(mediaURL)" }
    var isListen: Bool { mediaType == ListenQueue.listenMediaType }

    /// The id a story read aloud has in Up Next.
    static func listenId(forStoryHash hash: String) -> String {
        "\(hash)|\(ListenQueue.mediaURL(forStoryHash: hash))"
    }
    var isAudio: Bool { mediaType == ListenMediaItem.audioType && !mediaURL.isEmpty }
    /// Whether iOS plays it: a story read aloud or audio. Videos stay in the web view, so they wait in the queue.
    var isPlayable: Bool { isListen || isAudio }

    init?(json: Any?) {
        guard let dictionary = ListenJSON.dictionary(json) else { return nil }
        storyHash = ListenJSON.string(dictionary["story_hash"]) ?? ""
        mediaURL = ListenJSON.string(dictionary["media_url"]) ?? ""
        mediaType = ListenJSON.string(dictionary["media_type"]) ?? ""
        title = ListenPlayer.decodedTitle(dictionary["media_title"])
        let feed = ListenJSON.string(dictionary["feed_id"]) ?? ""
        feedId = feed.isEmpty || feed == "0" ? nil : feed
        imageURL = ListenJSON.string(dictionary["image_url"]) ?? ""
        duration = ListenJSON.double(dictionary["duration"]).flatMap { $0 > 0 ? $0 : nil }
    }

    init(story: [String: Any]) {
        storyHash = story["story_hash"] as? String ?? ""
        mediaURL = ListenQueue.mediaURL(forStoryHash: storyHash)
        mediaType = ListenQueue.listenMediaType
        title = ListenPlayer.decodedTitle(story["story_title"])
        feedId = ListenJSON.string(story["story_feed_id"])
        imageURL = ""
        duration = nil
    }

    init(media: ListenMediaItem) {
        storyHash = media.storyHash
        mediaURL = media.mediaURL
        mediaType = media.mediaType
        title = media.title
        feedId = media.feedId
        imageURL = media.imageURL
        duration = media.duration
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

/// How ListenQueue.swift reaches apps/media_player/views.py. Paths are relative to the account's server.
/// Test_ListenQueue answers requests itself, in whatever order it likes.
protocol ListenQueueTransport: AnyObject {
    func get(_ path: String, success: @escaping (Any?) -> Void, failure: @escaping (Error?) -> Void)
    func post(_ path: String, parameters: [String: String], success: @escaping (Any?) -> Void,
              failure: @escaping (Error?) -> Void)
}

/// ListenQueue.swift's requests go through the app delegate's session, so they carry the session cookie like every
/// other API call. ListenMediaPlayer.swift saves its position through it too.
final class ListenQueueAppTransport: ListenQueueTransport {
    func get(_ path: String, success: @escaping (Any?) -> Void, failure: @escaping (Error?) -> Void) {
        guard let appDelegate = NewsBlurAppDelegate.shared() else { return failure(nil) }
        appDelegate.get(ListenAPI.shared.baseURL + path, parameters: [:], success: { _, response in
            success(response)
        }, failure: { _, error in
            failure(error)
        })
    }

    func post(_ path: String, parameters: [String: String], success: @escaping (Any?) -> Void,
              failure: @escaping (Error?) -> Void) {
        guard let appDelegate = NewsBlurAppDelegate.shared() else { return failure(nil) }
        appDelegate.post(ListenAPI.shared.baseURL + path, parameters: parameters, success: { _, response in
            success(response)
        }, failure: { _, error in
            failure(error)
        })
    }
}

/// ListenQueue.swift is Up Next: the account's media queue in apps/media_player, shared with the web and Android.
/// Edits show at once and are sent to the server one at a time, in the order they were made, because the server
/// reads and replaces the whole queue on every edit (as Android's ListenManager.kt queue mutex does). The server's
/// answer replaces the local copy once no other edit is waiting, so a slow reply can't undo a newer change.
final class ListenQueue: NSObject, ObservableObject {
    static let shared = ListenQueue(transport: ListenQueueAppTransport())
    static let didChange = Notification.Name("ListenQueueDidChange")
    static let listenMediaType = "listen"

    /// Every queued item in order, including ones mobile doesn't play.
    @Published private(set) var items: [ListenQueueItem] = []
    /// The rest of the server's playback state: player settings, the current item and History
    /// (ListenMediaPlayer.swift resumes from it).
    @Published private(set) var playbackState: ListenPlaybackState?
    private var hasLoaded = false

    /// An Up Next edit waiting for the ones before it to be answered.
    private struct Write {
        let path: String
        let parameters: [String: String]
    }

    /// Edits not sent yet, oldest first. Only one edit is on its way at a time.
    private var waitingWrites: [Write] = []
    private var isSendingWrite = false
    /// Counts local edits, so a queue read that left before one can't undo it when it lands after (refresh()).
    private var editCount = 0
    /// Bumped by reset(), so answers for the previous account are ignored.
    private var accountSession = 0

    private var hasPendingWrites: Bool { isSendingWrite || !waitingWrites.isEmpty }

    /// A playback state request (save, History, position sync) waiting for the one before it. They go out one at a
    /// time, in order, as Android's ListenMediaSync.kt sends them, so an item handed off is saved paused before the
    /// next one becomes the current item, and a read for a resume sees both.
    private struct StateRequest {
        let path: String
        let parameters: [String: String]
        /// The server's answer, or nil when the request failed.
        let completion: (Any?) -> Void
    }

    private var waitingStateRequests: [StateRequest] = []
    private var isSendingStateRequest = false
    /// Reads waiting for the state requests before them to land (fetchPlaybackState).
    private var stateRequestDrainWaiters: [() -> Void] = []

    private let transport: ListenQueueTransport

    /// The app uses `shared`; Test_ListenQueue makes its own queue in front of a fake server.
    init(transport: ListenQueueTransport) {
        self.transport = transport
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    static func mediaURL(forStoryHash hash: String) -> String {
        "/listen/story/\(hash)"
    }

    /// The Listen stories in Up Next, in order.
    var listenItems: [ListenQueueItem] { items.filter(\.isListen) }

    /// Up Next while a podcast plays: the audio and Listen stories this device can play, in order.
    var playableItems: [ListenQueueItem] { items.filter(\.isPlayable) }

    /// Skip intervals, auto-play and remember position, shared with the web's player settings.
    var settings: ListenPlaybackSettings { playbackState?.settings ?? .defaults }

    func contains(media: ListenMediaItem) -> Bool {
        items.contains { $0.storyHash == media.storyHash && $0.mediaURL == media.mediaURL }
    }

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
    /// Skipped while edits are on their way: the last one's answer brings the server's queue.
    func refresh() {
        guard !hasPendingWrites else { return }
        let edits = editCount
        let session = accountSession
        transport.get("/media_player/playback_state", success: { [weak self] response in
            guard let self, session == self.accountSession, edits == self.editCount, !self.hasPendingWrites else { return }
            self.apply(response)
        }, failure: { error in
            NSLog("Listen couldn't load Up Next: %@", (error as NSError?) ?? NSError())
        })
    }

    /// GET /media_player/playback_state for an episode about to start (ListenMediaPlayer.swift): the queue is
    /// applied as refresh() would, and `completion` gets the state, or nil when the request failed. It waits for
    /// any save or History request already on its way, so it reads the place an item handed off just now was left.
    func fetchPlaybackState(completion: @escaping (ListenPlaybackState?) -> Void) {
        let session = accountSession
        whenStateRequestsLand { [weak self] in
            guard let self, session == self.accountSession else { return }
            self.readPlaybackState(completion: completion)
        }
    }

    private func readPlaybackState(completion: @escaping (ListenPlaybackState?) -> Void) {
        let edits = editCount
        let session = accountSession
        transport.get("/media_player/playback_state", success: { [weak self] response in
            guard let self, session == self.accountSession else { return }
            if edits == self.editCount, !self.hasPendingWrites {
                self.apply(response)
            } else {
                self.applyState(response)
            }
            completion(Self.state(from: response))
        }, failure: { [weak self] error in
            guard let self, session == self.accountSession else { return }
            NSLog("Listen couldn't load the playback state: %@", (error as NSError?) ?? NSError())
            completion(nil)
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
        accountSession += 1
        waitingWrites = []
        isSendingWrite = false
        hasLoaded = false
        playbackState = nil
        // ListenQueue.swift drops what hasn't gone out rather than send it under whoever signs in next.
        waitingStateRequests = []
        isSendingStateRequest = false
        stateRequestDrainWaiters = []
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

    /// Now Playing's drag to reorder, with offsets into `listenItems`. Items other platforms queued keep their
    /// places, and the server gets the whole queue because /media_player/reorder_media_queue drops anything left out.
    func moveListenItems(fromOffsets source: IndexSet, toOffset destination: Int) {
        var listen = listenItems
        listen.move(fromOffsets: source, toOffset: destination)
        let updated = Self.merging(listenOrder: listen, into: items)
        guard updated.map(\.id) != items.map(\.id) else { return }
        replaceItems(updated)
        sendOrder(updated)
    }

    /// Puts `listenOrder` into the slots Listen stories hold in `items`, leaving everything else where it was.
    static func merging(listenOrder: [ListenQueueItem], into items: [ListenQueueItem]) -> [ListenQueueItem] {
        merging(order: listenOrder, into: items, where: \.isListen)
    }

    /// Puts `order` into the slots of `items` that `included` picks, leaving everything else where it was.
    static func merging(order: [ListenQueueItem], into items: [ListenQueueItem],
                        where included: (ListenQueueItem) -> Bool) -> [ListenQueueItem] {
        var reordered = order.makeIterator()
        return items.map { item in included(item) ? (reordered.next() ?? item) : item }
    }

    private func sendOrder(_ updated: [ListenQueueItem]) {
        let order = updated.map { ["story_hash": $0.storyHash, "media_url": $0.mediaURL] }
        guard let data = try? JSONSerialization.data(withJSONObject: order) else { return }
        write("/media_player/reorder_media_queue", parameters: ["queue_order": String(decoding: data, as: UTF8.self)])
    }

    // MARK: - Podcasts and other audio

    /// Play Next (`position` 0) or Play Last (nil) from a story's audio card, as media_player_view.js add_to_queue
    /// does: an episode already queued moves to its new place. Returns its place in Up Next counting from 1.
    @discardableResult
    func add(media: ListenMediaItem, position: Int? = nil) -> Int {
        let item = ListenQueueItem(media: media)
        guard !item.mediaURL.isEmpty else { return 0 }
        var updated = items.filter { $0.id != item.id }
        if let position, position >= 0, position <= updated.count {
            updated.insert(item, at: position)
        } else {
            updated.append(item)
        }
        replaceItems(updated)
        var parameters = media.queueParameters
        if let position {
            parameters["position"] = String(position)
        }
        write("/media_player/add_to_media_queue", parameters: parameters)
        return (items.firstIndex { $0.id == item.id } ?? items.count - 1) + 1
    }

    /// Takes any queued entry off Up Next: a story read aloud, an episode, or something queued on another platform.
    func remove(item: ListenQueueItem) {
        guard items.contains(where: { $0.id == item.id }) else { return }
        replaceItems(items.filter { $0.id != item.id })
        write("/media_player/remove_from_media_queue", parameters: ["story_hash": item.storyHash,
                                                                   "media_url": item.mediaURL])
    }

    func remove(media: ListenMediaItem) {
        remove(item: ListenQueueItem(media: media))
    }

    /// Now Playing's swipe to delete while a podcast plays, with offsets into `playableItems`.
    func removePlayableItems(atOffsets offsets: IndexSet) {
        let playable = playableItems
        for offset in offsets where offset < playable.count {
            remove(item: playable[offset])
        }
    }

    /// Now Playing's drag to reorder while a podcast plays, with offsets into `playableItems`. Videos queued on the
    /// web keep their places.
    func movePlayableItems(fromOffsets source: IndexSet, toOffset destination: Int) {
        var playable = playableItems
        playable.move(fromOffsets: source, toOffset: destination)
        let updated = Self.merging(order: playable, into: items, where: \.isPlayable)
        guard updated.map(\.id) != items.map(\.id) else { return }
        replaceItems(updated)
        sendOrder(updated)
    }

    /// What plays next from Up Next (media_player_view.js play_next): the first audio or Listen story that isn't the
    /// item playing (`excludingId`), taken off the queue. Videos are skipped and stay queued for the web.
    func takeFirstPlayableItem(excludingId playingId: String?) -> ListenQueueItem? {
        guard let first = playableItems.first(where: { $0.id != playingId }) else { return nil }
        remove(item: first)
        return first
    }

    /// POST /media_player/add_to_media_history with the episode's place, so the web can resume it from History.
    func addToHistory(media: ListenMediaItem, position: TimeInterval, duration: TimeInterval) {
        guard !media.mediaURL.isEmpty else { return }
        var parameters = media.queueParameters
        parameters["position"] = String(format: "%.1f", max(0, position))
        parameters["duration"] = String(format: "%.1f", max(0, duration))
        sendState("/media_player/add_to_media_history", parameters: parameters) { response in
            if response == nil {
                NSLog("Listen couldn't save media history")
            }
        }
    }

    /// POST /media_player/save_playback_state (ListenMediaPlayer.swift and ListenPlayer.swift), in order with the
    /// other state requests. The answer refreshes the player settings, so a skip interval changed on the web
    /// reaches iOS at the next pause or start. `completion` says whether the server took it.
    func savePlaybackState(_ parameters: [String: String], completion: ((Bool) -> Void)? = nil) {
        let session = accountSession
        sendState("/media_player/save_playback_state", parameters: parameters) { [weak self] response in
            guard let self, session == self.accountSession else { return }
            let saved = Self.state(from: response) != nil
            if saved {
                self.applyState(response)
            } else {
                NSLog("Listen couldn't save the playback state")
            }
            completion?(saved)
        }
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
        sendState("/media_player/add_to_media_history", parameters: parameters) { response in
            if response == nil {
                NSLog("Listen couldn't save history")
            }
        }
    }

    // MARK: - Transport

    /// Queues an edit behind any still on their way. A reorder carries the whole queue as it stood when the user
    /// made it, which is what the server holds once the edits before it have landed.
    private func write(_ path: String, parameters: [String: String]) {
        editCount += 1
        waitingWrites.append(Write(path: path, parameters: parameters))
        sendNextWrite()
    }

    private func sendNextWrite() {
        guard !isSendingWrite, !waitingWrites.isEmpty else { return }
        let write = waitingWrites.removeFirst()
        let session = accountSession
        isSendingWrite = true
        transport.post(write.path, parameters: write.parameters, success: { [weak self] response in
            guard let self, session == self.accountSession else { return }
            self.isSendingWrite = false
            if self.waitingWrites.isEmpty {
                self.apply(response)
            } else {
                self.sendNextWrite()
            }
        }, failure: { [weak self] error in
            guard let self, session == self.accountSession else { return }
            NSLog("Listen couldn't update Up Next: %@", (error as NSError?) ?? NSError())
            self.isSendingWrite = false
            if self.waitingWrites.isEmpty {
                // ListenQueue.swift puts the server's queue back when an edit didn't go through.
                self.refresh()
            } else {
                self.sendNextWrite()
            }
        })
    }

    private func apply(_ response: Any?) {
        guard let json = ListenJSON.dictionary(response) else { return }
        hasLoaded = true
        let state = ListenJSON.dictionary(json["playback_state"])
        applyState(response)
        replaceItems(ListenJSON.array(state?["queue"]).compactMap { ListenQueueItem(json: $0) })
    }

    /// What sync_playback_position said: taken, refused because another item is current now (code -1), or lost.
    enum PositionSync: Equatable {
        case accepted
        case rejected
        case failed
    }

    /// POST /media_player/sync_playback_position, ListenMediaPlayer.swift's position every 10 seconds while an
    /// episode plays. Like the web's media:sync websocket it writes only Redis, never MongoDB, and the server
    /// refuses it with code -1 once `mediaURL` stops being the current item, so a phone left playing can't move
    /// whatever another device started since. The duration goes only when it's known.
    func syncPlaybackPosition(mediaURL: String, position: TimeInterval, duration: TimeInterval, playbackRate: Double,
                              isPlaying: Bool, completion: @escaping (PositionSync) -> Void) {
        var parameters = ["media_url": mediaURL,
                          "position": String(format: "%.1f", max(0, position)),
                          "playback_rate": String(format: "%.2f", playbackRate),
                          "is_playing": isPlaying ? "true" : "false"]
        if duration > 0 {
            parameters["duration"] = String(format: "%.1f", duration)
        }
        let session = accountSession
        sendState("/media_player/sync_playback_position", parameters: parameters) { [weak self] response in
            guard let self, session == self.accountSession else { return }
            guard let json = ListenJSON.dictionary(response) else {
                NSLog("Listen couldn't sync the playback position")
                completion(.failed)
                return
            }
            completion(ListenJSON.int(json["code"]) == -1 ? .rejected : .accepted)
        }
    }

    // MARK: - Playback state line

    private func sendState(_ path: String, parameters: [String: String], completion: @escaping (Any?) -> Void) {
        waitingStateRequests.append(StateRequest(path: path, parameters: parameters, completion: completion))
        sendNextStateRequest()
    }

    private func sendNextStateRequest() {
        guard !isSendingStateRequest else { return }
        guard !waitingStateRequests.isEmpty else {
            let waiters = stateRequestDrainWaiters
            stateRequestDrainWaiters = []
            waiters.forEach { $0() }
            return
        }
        let request = waitingStateRequests.removeFirst()
        let session = accountSession
        isSendingStateRequest = true
        let finish: (Any?) -> Void = { [weak self] response in
            guard let self, session == self.accountSession else { return }
            self.isSendingStateRequest = false
            request.completion(response)
            self.sendNextStateRequest()
        }
        transport.post(request.path, parameters: request.parameters, success: { response in
            finish(response)
        }, failure: { error in
            NSLog("Listen's %@ failed: %@", request.path, (error as NSError?) ?? NSError())
            finish(nil)
        })
    }

    /// Runs `work` once every state request sent so far has been answered.
    private func whenStateRequestsLand(_ work: @escaping () -> Void) {
        if !isSendingStateRequest && waitingStateRequests.isEmpty {
            work()
        } else {
            stateRequestDrainWaiters.append(work)
        }
    }

    /// Takes the settings, current item and History from an answer without touching the queue. Only a change to
    /// the settings is announced: a save's answer moves the current position every 10 seconds, and nothing on
    /// screen shows that.
    private func applyState(_ response: Any?) {
        guard let state = Self.state(from: response), state != playbackState else { return }
        let settingsChanged = state.settings != settings
        playbackState = state
        if settingsChanged {
            NotificationCenter.default.post(name: Self.didChange, object: self)
        }
    }

    static func state(from response: Any?) -> ListenPlaybackState? {
        guard let json = ListenJSON.dictionary(response),
              let state = ListenJSON.dictionary(json["playback_state"]) else { return nil }
        return ListenPlaybackState(json: state)
    }

    private func replaceItems(_ updated: [ListenQueueItem]) {
        guard updated != items else { return }
        items = updated
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }
}
