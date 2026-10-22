//
//  ListenStoryBridge.swift
//  NewsBlur
//
//  Created by Claude on 2026-10-21.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import UIKit
import WebKit

/// ListenStoryBridge.swift is what the Objective-C reader, menus and preferences call into for Listen.
@objcMembers final class ListenStoryBridge: NSObject {
    /// Whether the story button named train, share, save, ask_ai or listen is shown (StoryDetailObjCViewController.m).
    static func showsStoryButton(_ name: String) -> Bool {
        ListenPreferences.showsStoryButton(name)
    }

    /// The Listen story button for StoryDetailObjCViewController.m getSideOptions. Labels are HTML-escaped.
    static func listenButtonHTML(forStory story: [AnyHashable: Any]?) -> String {
        let hash = story?["story_hash"] as? String
        let player = ListenPlayer.shared
        let label: String
        var classes = "NB-share-button NB-listen-button NB-button"
        if player.isPlaying(storyHash: hash) {
            label = NBLocalization.text("Pause")
            classes += " NB-button-active NB-listen-playing"
        } else if player.isLoaded(storyHash: hash), player.status == .paused {
            label = NBLocalization.text("Resume")
            classes += " NB-button-active NB-listen-paused"
        } else {
            label = NBLocalization.text("Listen")
        }
        let appDelegate = NewsBlurAppDelegate.shared()
        let isArchiveTier = (appDelegate?.isPremiumArchive ?? false) || (appDelegate?.isPremiumPro ?? false)
        let pill = isArchiveTier ? "" :
            "<span class=\"NB-listen-pill\">\(escape(NBLocalization.text("30s preview")))</span>"
        if !isArchiveTier {
            classes += " NB-listen-has-pill"
        }
        let queueButton = queueButtonHTML(forStoryHash: hash)
        if !queueButton.isEmpty {
            classes += " NB-listen-has-queue"
        }
        return """
          <div class='\(classes)'>\
            <a class="NB-listen-main" href="http://ios.newsblur.com/listen"><div>\
              <span class="NB-sideoption-text">\(escape(label))</span>\
              \(pill)\
              <span class="NB-icon"></span>\
            </div></a>\
            \(queueButton)\
          </div>
        """
    }

    /// The small + beside Listen: shown only while another story is loaded in the player, it adds this story to Up
    /// Next, and shows a checkmark once the story is queued (tapping it again takes the story back off).
    private static func queueButtonHTML(forStoryHash hash: String?) -> String {
        let player = ListenPlayer.shared
        guard let hash, player.isActive, !player.isLoaded(storyHash: hash) else { return "" }
        let isQueued = ListenQueue.shared.contains(storyHash: hash)
        let label = isQueued ? NBLocalization.text("Queued") : NBLocalization.text("Add to Up Next")
        let classes = isQueued ? "NB-listen-queue NB-listen-queued" : "NB-listen-queue"
        return "<a class=\"\(classes)\" href=\"http://ios.newsblur.com/listen-queue\" title=\"\(escape(label))\" "
            + "aria-label=\"\(escape(label))\" role=\"button\"><div><span class=\"NB-icon\"></span></div></a>"
    }

    /// The + beside Listen, "Add to Up Next" in the story menus and the Mac Story menu: adds the story to Up Next
    /// with a toast naming its place, or takes it back off.
    static func toggleQueue(forStory story: [AnyHashable: Any]?) {
        guard let story, let hash = story["story_hash"] as? String else { return }
        let queue = ListenQueue.shared
        if queue.contains(storyHash: hash) {
            queue.remove(storyHash: hash)
            ListenToast.show(NBLocalization.text("Removed from Up Next"))
        } else {
            let position = queue.add(story: ListenPlayer.stringKeyed(story))
            ListenToast.show(String(format: NBLocalization.text("Added to Up Next · %@"), ListenFormat.ordinal(position)))
        }
    }

    /// Whether the story is in Up Next, for the menus' Add/Remove titles.
    static func isQueued(_ story: [AnyHashable: Any]?) -> Bool {
        ListenQueue.shared.contains(storyHash: story?["story_hash"] as? String)
    }

    /// The story menus' title for adding the story to Up Next or taking it off.
    static func queueMenuTitle(forStory story: [AnyHashable: Any]?) -> String {
        isQueued(story) ? NBLocalization.text("Remove from Up Next") : NBLocalization.text("Add to Up Next")
    }

    /// Whether the story menus offer Up Next: Listen is shown and the story isn't the one in the player.
    static func offersQueue(forStory story: [AnyHashable: Any]?) -> Bool {
        guard let hash = story?["story_hash"] as? String else { return false }
        return ListenPreferences.showsStoryButton("listen") && !ListenPlayer.shared.isLoaded(storyHash: hash)
    }

    /// Whether a story is loaded in the player (BaseViewController.m toolbar validation).
    static var isPlayerActive: Bool {
        ListenPlayer.shared.isActive
    }

    /// Bottom inset a list needs while the mini player covers its column (FeedsObjCViewController.m).
    @objc(miniPlayerInsetForView:)
    static func miniPlayerInset(for view: UIView) -> CGFloat {
        ListenMiniPlayerController.shared.bottomInset(for: view)
    }

    /// Logout, an expired session or a new server: nothing from the old account keeps playing or stays on the
    /// lock screen (NewsBlurAppDelegate.m).
    static func stopForAccountChange() {
        if ListenPlayer.shared.isActive {
            ListenPlayer.shared.stop()
        }
        ListenQueue.shared.reset()
    }

    /// The Mac toolbar's play/pause and media keys for whatever is loaded.
    static func togglePlayback() {
        ListenPlayer.shared.togglePlayPause()
    }

    static func isPlayingStory(_ story: [AnyHashable: Any]?) -> Bool {
        ListenPlayer.shared.isPlaying(storyHash: story?["story_hash"] as? String)
    }

    /// The story button, the Story menu item and the Y shortcut.
    static func toggleListen(forStory story: [AnyHashable: Any]?) {
        guard let story, story["story_hash"] is String else { return }
        ListenPlayer.shared.toggle(story: story)
    }

    /// The Story menu's title for the story on screen (BaseViewController.m validateCommand:).
    static func menuTitle(forStory story: [AnyHashable: Any]?) -> String {
        isPlayingStory(story) ? NBLocalization.text("Pause Listening") : NBLocalization.text("Listen")
    }

    /// FeedsObjCViewController.m hands over the profile from /reader/feeds, which is also when Up Next loads.
    static func syncFromUserProfile(_ userProfile: [AnyHashable: Any]?) {
        ListenPreferences.syncFromUserProfile(userProfile)
        ListenQueue.shared.refresh()
    }

    /// PreferencesView.swift changed a value. Returns whether it was a Listen or story button preference.
    static func preferenceDidChange(_ key: String?) -> Bool {
        guard let key, ListenPreferences.isSyncedKey(key) else { return false }
        ListenPreferences.pushLocalValue(forKey: key)
        if key == ListenPreferences.speedKey, ListenPlayer.shared.isActive {
            ListenPlayer.shared.setSpeed(ListenPreferences.speed)
        }
        if ListenPreferences.isStoryButtonKey(key) {
            refreshStoryButtons()
        }
        return true
    }

    static func presentVoiceSettings(from presenter: UIViewController?) {
        ListenPresenter.presentVoiceSettings(from: presenter)
    }

    static func presentNowPlaying() {
        ListenPresenter.presentNowPlaying()
    }

    /// ThemeManager.m changed the theme (via SplitViewController.swift updateTheme).
    static func themeDidChange() {
        ListenMiniPlayerController.shared.updateTheme()
    }

    /// Redraws the story buttons on the loaded story pages after a show/hide toggle changes.
    static func refreshStoryButtons() {
        guard let pages = NewsBlurAppDelegate.shared()?.storyPagesViewController else { return }
        for page in [pages.previousPage, pages.currentPage, pages.nextPage] {
            page?.refreshSideOptions()
        }
    }

    /// Switches the loaded pages showing this story to Text view, just for this story: the feed's own Story/Text
    /// choice (NewsBlurAppDelegate.m toggleFeedTextView:) is left alone.
    static func showFullText(forStoryHash hash: String?) {
        guard let hash, let pages = NewsBlurAppDelegate.shared()?.storyPagesViewController else { return }
        for page in [pages.currentPage, pages.previousPage, pages.nextPage] {
            guard let page, (page.activeStory?["story_hash"] as? String) == hash, !page.inTextView else { continue }
            page.fetchTextView()
        }
    }

    static func escape(_ text: String) -> String {
        (text as NSString).encodingHTMLEntities() ?? text
    }
}

/// ListenStoryBridge.swift: follow-along highlighting and paragraph taps for each story page.
extension StoryDetailViewController {
    /// Called once from StoryDetailViewController.swift viewDidLoad.
    func listenObservePlayer() {
        let center = NotificationCenter.default
        listenObservers = [
            center.addObserver(forName: ListenPlayer.stateDidChange, object: nil, queue: .main) { [weak self] _ in
                self?.listenStateChanged()
            },
            center.addObserver(forName: ListenPlayer.segmentDidChange, object: nil, queue: .main) { [weak self] _ in
                self?.listenUpdateHighlight(scroll: true)
            },
            center.addObserver(forName: ListenPreferences.didChange, object: nil, queue: .main) { [weak self] _ in
                self?.listenUpdateHighlight(scroll: false)
            },
            center.addObserver(forName: ListenQueue.didChange, object: nil, queue: .main) { [weak self] _ in
                self?.listenStateChanged()
            }
        ]
    }

    /// StoryDetailObjCViewController.m drew a new document: map the manifest's paragraphs again.
    @objc func listenStoryDidLoad() {
        listenMappedManifestId = nil
        listenButtonState = listenCurrentButtonState
        listenUpdateHighlight(scroll: false)
    }

    private var listenCurrentButtonState: String {
        let hash = activeStory?["story_hash"] as? String
        let player = ListenPlayer.shared
        guard player.isLoaded(storyHash: hash) else {
            // ListenStoryBridge.swift: the + beside Listen depends on another story playing and on Up Next.
            guard player.isActive else { return "none" }
            return ListenQueue.shared.contains(storyHash: hash) ? "queued" : "can-queue"
        }
        return player.wantsToPlay ? "playing" : (player.status == .paused ? "paused" : "loaded")
    }

    private func listenStateChanged() {
        let state = listenCurrentButtonState
        if state != listenButtonState {
            listenButtonState = state
            refreshSideOptions()
        }
        listenUpdateHighlight(scroll: false)
    }

    func listenUpdateHighlight(scroll: Bool) {
        guard hasStory, let webView, let hash = activeStory?["story_hash"] as? String else { return }
        let player = ListenPlayer.shared
        let miniPlayerShown = ListenMiniPlayerController.shared.isShown
        webView.evaluateJavaScript("typeof newsblurListenSetMiniPlayer === 'function' && newsblurListenSetMiniPlayer(\(miniPlayerShown))")
        if player.isLoaded(storyHash: hash), ListenPreferences.highlight, let manifest = player.manifest {
            if listenMappedManifestId != manifest.manifestId {
                let paragraphs = manifest.paragraphs.map { ["index": $0.index, "kind": $0.kind, "text": $0.text] }
                guard let data = try? JSONSerialization.data(withJSONObject: paragraphs) else { return }
                let json = String(decoding: data, as: UTF8.self)
                webView.evaluateJavaScript("typeof newsblurListenPrepare === 'function' && newsblurListenPrepare(\(json))")
                listenMappedManifestId = manifest.manifestId
            }
            let isCurrentPage = appDelegate?.storyPagesViewController?.currentPage === self
            let indices = player.currentParagraphs.map(String.init).joined(separator: ",")
            webView.evaluateJavaScript("typeof newsblurListenHighlight === 'function' && newsblurListenHighlight([\(indices)], \(scroll && isCurrentPage && player.wantsToPlay))")
        } else if listenMappedManifestId != nil {
            webView.evaluateJavaScript("typeof newsblurListenClear === 'function' && newsblurListenClear()")
            listenMappedManifestId = nil
        }
    }

    /// StoryDetailObjCViewController.m tap: a tap on a paragraph of the story being read jumps playback there.
    @objc(listenHandleTapAt:completion:)
    func listenHandleTap(at point: CGPoint, completion: @escaping (Bool) -> Void) {
        let hash = activeStory?["story_hash"] as? String
        guard ListenPlayer.shared.isPlaying(storyHash: hash), listenMappedManifestId != nil, let webView else {
            completion(false)
            return
        }
        let offset = webView.scrollView.contentOffset
        let script = String(format: "typeof newsblurListenIndexAt === 'function' ? newsblurListenIndexAt(%f, %f, %f, %f, %f) : -1",
                            point.x, point.y, offset.x, offset.y, webView.bounds.width)
        webView.evaluateJavaScript(script) { result, _ in
            guard let index = (result as? NSNumber)?.intValue, index >= 0,
                  ListenPlayer.shared.isLoaded(storyHash: hash) else {
                completion(false)
                return
            }
            ListenPlayer.shared.jump(toParagraph: index)
            completion(true)
        }
    }
}
