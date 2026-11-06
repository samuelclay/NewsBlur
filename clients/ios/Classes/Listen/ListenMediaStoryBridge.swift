//
//  ListenMediaStoryBridge.swift
//  NewsBlur
//
//  Created by Claude on 2026-11-06.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import UIKit
import WebKit

/// ListenMediaStoryBridge.swift connects a story's audio to ListenMediaPlayer.swift. storyDetailView.js
/// (newsblurPrepareMedia) swaps each <audio> in the story for a card with Play, Play Next and Play Last, the
/// buttons media_player_view.js adds under the web's inline players. Videos and YouTube keep playing in the story.
@objcMembers final class ListenMediaStoryBridge: NSObject {
    /// The <script> StoryDetailObjCViewController.m puts before storyDetailView.js: the cards' labels in the
    /// interface language and their state when the story is drawn.
    static func configScript(forStory story: [AnyHashable: Any]?) -> String {
        let labels = ["play": NBLocalization.text("Play audio"),
                      "pause": NBLocalization.text("Pause"),
                      "resume": NBLocalization.text("Resume"),
                      "play_next": NBLocalization.text("Play Next"),
                      "play_last": NBLocalization.text("Play Last"),
                      "queued": NBLocalization.text("Queued"),
                      "remove_queued": NBLocalization.text("Remove from Up Next")]
        let config: [String: Any] = ["labels": labels, "state": cardState(forStoryHash: story?["story_hash"] as? String)]
        return "window.newsblurMediaConfig = \(json(config));"
    }

    /// Which card is playing or paused, which are queued, and whether anything is loaded (so Play Next and Play
    /// Last show).
    static func cardState(forStoryHash hash: String?) -> [String: Any] {
        let player = ListenMediaPlayer.shared
        var current = ""
        var status = ""
        if let hash, let item = player.item, item.storyHash == hash {
            current = item.mediaURL
            if player.wantsToPlay {
                status = player.status == .playing ? "playing" : "loading"
            } else {
                status = "paused"
            }
        }
        let queued = ListenQueue.shared.items.filter { $0.isAudio && $0.storyHash == hash }.map(\.mediaURL)
        return ["current": current, "status": status, "queued": queued,
                "loaded": player.isActive || ListenPlayer.shared.isActive]
    }

    /// JSON that is safe inside a <script> element.
    static func json(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return "{}" }
        return String(decoding: data, as: UTF8.self).replacingOccurrences(of: "</", with: "<\\/")
    }

    /// A card's button for the audio at `url` in `story`. Returns false when the app's player can't take it (no
    /// usable URL), so the story puts its own inline player back.
    @discardableResult
    static func perform(_ action: String, url: String, story: [AnyHashable: Any]) -> Bool {
        let media = ListenMediaItem(story: ListenPlayer.stringKeyed(story), mediaURL: url)
        guard media.url?.scheme != nil else { return false }
        let player = ListenMediaPlayer.shared
        let queue = ListenQueue.shared
        switch action {
        case "toggle":
            player.toggle(media)
        case "next", "last":
            // media_player_view.js add_to_queue: with nothing loaded the episode just plays.
            guard player.isActive || ListenPlayer.shared.isActive else {
                player.start(media)
                return true
            }
            guard !player.isLoaded(media) else { return true }
            let position = queue.add(media: media, position: action == "next" ? 0 : nil)
            ListenToast.show(String(format: NBLocalization.text("Added to Up Next · %@"), ListenFormat.ordinal(position)))
        case "unqueue":
            queue.remove(media: media)
            ListenToast.show(NBLocalization.text("Removed from Up Next"))
        default:
            break
        }
        return true
    }
}

/// ListenMediaStoryBridge.swift: each story page's audio cards.
extension StoryDetailViewController {
    /// storyDetailView.js posts {action, url} to newsblurStoryMedia (StoryDetailObjCViewController.m).
    func receiveMediaMessage(_ message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let action = body["action"] as? String,
              let url = body["url"] as? String, !url.isEmpty else { return }
        if let story = activeStory as? [AnyHashable: Any], ListenMediaStoryBridge.perform(action, url: url, story: story) {
            return
        }
        // ListenMediaStoryBridge.swift: the app's player can't take this audio, so it plays in the story instead.
        webView?.evaluateJavaScript("typeof newsblurMediaFallback === 'function' && newsblurMediaFallback(\(ListenMediaStoryBridge.json([url]))[0])")
    }

    /// Redraws the cards after the player or Up Next changed (ListenStoryBridge.swift listenStateChanged).
    func mediaUpdateCards() {
        guard hasStory, let webView else { return }
        let state = ListenMediaStoryBridge.cardState(forStoryHash: activeStory?["story_hash"] as? String)
        webView.evaluateJavaScript("typeof newsblurMediaSetState === 'function' && newsblurMediaSetState(\(ListenMediaStoryBridge.json(state)))")
    }
}
