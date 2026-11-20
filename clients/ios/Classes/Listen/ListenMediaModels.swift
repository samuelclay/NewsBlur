//
//  ListenMediaModels.swift
//  NewsBlur
//
//  Created by Claude on 2026-11-06.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import Foundation

/// A podcast episode or other audio from a story (ListenMediaModels.swift), in the shape apps/media_player keeps for
/// the current item, Up Next and History, so the web, Android and iOS all name it the same way. media_url is the
/// story's own <audio> or <source> src attribute, exactly as media_player_view.js detect_media_in_story reads it.
struct ListenMediaItem: Equatable {
    static let audioType = "audio"

    let storyHash: String
    let mediaURL: String
    let mediaType: String
    let title: String
    let feedId: String?
    let imageURL: String
    let duration: TimeInterval?

    init(storyHash: String, mediaURL: String, mediaType: String = ListenMediaItem.audioType, title: String,
         feedId: String?, imageURL: String = "", duration: TimeInterval? = nil) {
        self.storyHash = storyHash
        self.mediaURL = mediaURL
        self.mediaType = mediaType
        self.title = title
        self.feedId = feedId.flatMap { $0.isEmpty || $0 == "0" ? nil : $0 }
        self.imageURL = imageURL
        self.duration = duration.flatMap { $0 > 0 ? $0 : nil }
    }

    /// The audio at `mediaURL` in a story dictionary from the story list (StoryDetailViewController.swift).
    init(story: [String: Any], mediaURL: String) {
        let images = story["image_urls"] as? [Any]
        self.init(storyHash: story["story_hash"] as? String ?? "", mediaURL: mediaURL,
                  title: ListenPlayer.decodedTitle(story["story_title"]),
                  feedId: ListenJSON.string(story["story_feed_id"]),
                  imageURL: ListenJSON.string(images?.first) ?? "")
    }

    /// An Up Next entry this device can play as audio.
    init?(queueItem: ListenQueueItem) {
        guard queueItem.isAudio else { return nil }
        self.init(storyHash: queueItem.storyHash, mediaURL: queueItem.mediaURL, mediaType: queueItem.mediaType,
                  title: queueItem.title, feedId: queueItem.feedId, imageURL: queueItem.imageURL,
                  duration: queueItem.duration)
    }

    var url: URL? {
        URL(string: mediaURL.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Whether `other` names the same episode, the way apps/media_player/models.py dedupes the queue.
    func isSame(as other: ListenMediaItem?) -> Bool {
        guard let other else { return false }
        return storyHash == other.storyHash && mediaURL == other.mediaURL
    }

    /// The fields add_to_media_queue and add_to_media_history read (apps/media_player/views.py).
    var queueParameters: [String: String] {
        var parameters = ["story_hash": storyHash, "media_url": mediaURL, "media_type": mediaType,
                          "media_title": title, "feed_id": feedId ?? "0", "image_url": imageURL]
        if let duration {
            parameters["duration"] = String(format: "%.1f", duration)
        }
        return parameters
    }

    /// POST /media_player/save_playback_state for this episode. Like media_player_view.js save_durable_state it
    /// names the whole current item, so a position never lands on whatever another device played last. The
    /// player settings (skips, auto-play, remember position) and volume are left out: iOS doesn't change them, and
    /// sending a stale copy would undo a change made on the web. The duration goes only when it's known, and the
    /// rate only when the caller passes one.
    func stateParameters(position: TimeInterval, duration: TimeInterval, isPlaying: Bool,
                         playbackRate: Double?) -> [String: String] {
        var parameters = ["current_story_hash": storyHash, "current_media_url": mediaURL,
                          "current_media_type": mediaType, "current_media_title": title,
                          "current_feed_id": feedId ?? "0", "current_image_url": imageURL,
                          "current_position": String(format: "%.1f", max(0, position)),
                          "is_playing": isPlaying ? "true" : "false"]
        if duration > 0 {
            parameters["current_duration"] = String(format: "%.1f", duration)
        }
        if let playbackRate {
            parameters["current_playback_rate"] = String(format: "%.2f", playbackRate)
        }
        return parameters
    }
}

/// The player settings from /media_player/playback_state, with the web's defaults (media_player_view.js initialize).
struct ListenPlaybackSettings: Equatable {
    static let defaults = ListenPlaybackSettings(skipBackSeconds: 15, skipForwardSeconds: 30, autoPlayNext: true,
                                                 rememberPosition: true)

    var skipBackSeconds: Int
    var skipForwardSeconds: Int
    var autoPlayNext: Bool
    var rememberPosition: Bool

    init(skipBackSeconds: Int, skipForwardSeconds: Int, autoPlayNext: Bool, rememberPosition: Bool) {
        self.skipBackSeconds = skipBackSeconds
        self.skipForwardSeconds = skipForwardSeconds
        self.autoPlayNext = autoPlayNext
        self.rememberPosition = rememberPosition
    }

    /// media_player_view.js restore_state treats a missing or zero skip as the default.
    init(json: [String: Any]) {
        let back = ListenJSON.int(json["skip_back_seconds"]) ?? 0
        let forward = ListenJSON.int(json["skip_forward_seconds"]) ?? 0
        skipBackSeconds = back > 0 ? back : Self.defaults.skipBackSeconds
        skipForwardSeconds = forward > 0 ? forward : Self.defaults.skipForwardSeconds
        autoPlayNext = ListenJSON.bool(json["auto_play_next"]) ?? Self.defaults.autoPlayNext
        rememberPosition = ListenJSON.bool(json["remember_position"]) ?? Self.defaults.rememberPosition
    }
}

/// A place in an episode some device saved: the current item or a History entry (ListenMediaModels.swift).
struct ListenSavedPosition: Equatable {
    let storyHash: String
    let mediaURL: String
    let mediaType: String
    let position: TimeInterval
    let duration: TimeInterval
    var title = ""
    var feedId: String?
    var imageURL = ""

    /// The saved item, to put in History when an episode started here replaces it.
    var mediaItem: ListenMediaItem {
        ListenMediaItem(storyHash: storyHash, mediaURL: mediaURL, mediaType: mediaType, title: title, feedId: feedId,
                        imageURL: imageURL, duration: duration)
    }
}

/// GET /media_player/playback_state, as the media player needs it (ListenMediaModels.swift).
struct ListenPlaybackState: Equatable {
    /// An episode saved this close to its end counts as finished and plays from the start again.
    static let finishedMargin: TimeInterval = 5

    let settings: ListenPlaybackSettings
    let current: ListenSavedPosition?
    let currentPlaybackRate: Double?
    let history: [ListenSavedPosition]

    init(settings: ListenPlaybackSettings = .defaults, current: ListenSavedPosition? = nil,
         currentPlaybackRate: Double? = nil, history: [ListenSavedPosition] = []) {
        self.settings = settings
        self.current = current
        self.currentPlaybackRate = currentPlaybackRate
        self.history = history
    }

    /// `json` is the playback_state object from any apps/media_player/views.py answer.
    init(json: [String: Any]) {
        settings = ListenPlaybackSettings(json: json)
        let url = ListenJSON.string(json["current_media_url"]) ?? ""
        if url.isEmpty {
            current = nil
        } else {
            current = ListenSavedPosition(storyHash: ListenJSON.string(json["current_story_hash"]) ?? "",
                                          mediaURL: url,
                                          mediaType: ListenJSON.string(json["current_media_type"]) ?? "",
                                          position: ListenJSON.double(json["current_position"]) ?? 0,
                                          duration: ListenJSON.double(json["current_duration"]) ?? 0,
                                          title: ListenPlayer.decodedTitle(json["current_media_title"]),
                                          feedId: ListenJSON.string(json["current_feed_id"]),
                                          imageURL: ListenJSON.string(json["current_image_url"]) ?? "")
        }
        let rate = ListenJSON.double(json["current_playback_rate"]) ?? 0
        currentPlaybackRate = rate > 0 ? ListenSpeed.clamped(rate) : nil
        history = ListenJSON.array(json["history"]).compactMap { entry in
            guard let entry = ListenJSON.dictionary(entry), let url = ListenJSON.string(entry["media_url"]),
                  !url.isEmpty else { return nil }
            return ListenSavedPosition(storyHash: ListenJSON.string(entry["story_hash"]) ?? "", mediaURL: url,
                                       mediaType: ListenJSON.string(entry["media_type"]) ?? "",
                                       position: ListenJSON.double(entry["position"]) ?? 0,
                                       duration: ListenJSON.double(entry["duration"]) ?? 0)
        }
    }

    /// Where `item` starts: the place the web, Android or another iOS device left it, or nil to start from the
    /// beginning. The current item matches on media_url, else on story_hash for an item of the same type (a
    /// podcast whose enclosure URL changed, never a story read aloud by Listen); History, where the web and
    /// Listen put an episode when something else starts, is checked the same way. Nothing resumes while
    /// remember_position is off.
    func resumePosition(for item: ListenMediaItem) -> TimeInterval? {
        guard settings.rememberPosition, let saved = savedPosition(for: item), saved.position >= 1 else { return nil }
        if saved.duration > 0, saved.position >= saved.duration - Self.finishedMargin {
            return nil
        }
        return saved.position
    }

    /// The current item or History entry that is `item`, by the rules resumePosition(for:) describes.
    func savedPosition(for item: ListenMediaItem) -> ListenSavedPosition? {
        Self.match(item, in: [current].compactMap { $0 }) ?? Self.match(item, in: history)
    }

    /// The current item another device left part way through, when `item` is about to replace it: the place it
    /// had goes to History first, as media_player_view.js add_to_history_from_current and Android's
    /// keepReplacedInHistory do. Stories read aloud and items saved by this app (`savedHere`, which went to History
    /// when they stopped here) are left alone.
    func replacedItem(by item: ListenMediaItem, savedHere: String?) -> ListenSavedPosition? {
        guard let current, current.position > 0, current.mediaType != ListenQueue.listenMediaType,
              current.mediaURL != savedHere, Self.match(item, in: [current]) == nil else { return nil }
        return current
    }

    private static func match(_ item: ListenMediaItem, in positions: [ListenSavedPosition]) -> ListenSavedPosition? {
        if let byURL = positions.first(where: { $0.mediaURL == item.mediaURL }) {
            return byURL
        }
        guard !item.storyHash.isEmpty else { return nil }
        return positions.first { $0.storyHash == item.storyHash && $0.mediaType == item.mediaType }
    }
}
