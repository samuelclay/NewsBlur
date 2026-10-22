//
//  ToolbarDelegate.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-01-05.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import UIKit

#if targetEnvironment(macCatalyst)
class ToolbarDelegate: NSObject {
    var fullScreenToolbarItem: NSToolbarItem?
    var listenToolbarItem: NSToolbarItem?
    private var listenObserver: NSObjectProtocol?

    deinit {
        if let listenObserver {
            NotificationCenter.default.removeObserver(listenObserver)
        }
    }
}

extension NSToolbarItem.Identifier {
    static let reloadFeeds = NSToolbarItem.Identifier("com.newsblur.reloadFeeds")
    static let toggleFullScreen = NSToolbarItem.Identifier("com.newsblur.toggleFullScreen")
    static let feedDetailUnread = NSToolbarItem.Identifier("com.newsblur.feedDetailUnread")
    static let feedDetailSettings = NSToolbarItem.Identifier("com.newsblur.feedDetailSettings")
    static let storyPagesSettings = NSToolbarItem.Identifier("com.newsblur.storyPagesSettings")
    static let storyPagesBrowser = NSToolbarItem.Identifier("com.newsblur.storyPagesBrowser")
    static let listenPlayPause = NSToolbarItem.Identifier("com.newsblur.listenPlayPause")
}

extension ToolbarDelegate: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        let identifiers: [NSToolbarItem.Identifier] = [
            .toggleSidebar,
            .toggleFullScreen,
            .space,
            .reloadFeeds,
            .space,
            .feedDetailUnread,
            .feedDetailSettings,
            .flexibleSpace,
            .listenPlayPause,
            .storyPagesSettings,
            .storyPagesBrowser
        ]
        return identifiers
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
            case .toggleFullScreen:
                let item = makeToolbarItem(itemIdentifier,
                                           image: UIImage(systemName: "arrow.up.left.and.arrow.down.right"),
                                           label: NBLocalization.text("Full Screen"),
                                           action: #selector(BaseViewController.toggleTemporaryFullScreen(_:)))
                fullScreenToolbarItem = item
                return item

            case .reloadFeeds:
                return makeToolbarItem(itemIdentifier,
                                       image: UIImage(systemName: "arrow.clockwise"),
                                       label: NBLocalization.text("Reload Sites"),
                                       action: #selector(BaseViewController.reloadFeeds(_:)))

            case .feedDetailUnread:
                return makeToolbarItem(itemIdentifier,
                                       image: Utilities.imageNamed("mark-read", sized: 24),
                                       label: NBLocalization.text("Mark as Read"),
                                       action: #selector(BaseViewController.openMarkReadMenu(_:)))

            case .feedDetailSettings:
                return makeToolbarItem(itemIdentifier,
                                       image: Utilities.imageNamed("settings", sized: 24),
                                       label: NBLocalization.text("Site Settings"),
                                       action: #selector(BaseViewController.openSettingsMenu(_:)))

            case .storyPagesSettings:
                return makeToolbarItem(itemIdentifier,
                                       image: Utilities.imageNamed("settings", sized: 24),
                                       label: NBLocalization.text("Story Settings"),
                                       action: #selector(StoryPagesViewController.toggleFontSize(_:)))

            case .listenPlayPause:
                // ToolbarDelegate.swift plays and pauses Listen (Listen/ListenPlayer.swift); media keys work too.
                let item = makeToolbarItem(itemIdentifier,
                                           image: UIImage(systemName: "headphones"),
                                           label: NBLocalization.text("Listen"),
                                           action: #selector(BaseViewController.toggleListenPlayback(_:)))
                listenToolbarItem = item
                if listenObserver == nil {
                    listenObserver = NotificationCenter.default.addObserver(forName: ListenPlayer.stateDidChange,
                                                                            object: nil, queue: .main) { [weak self] _ in
                        MainActor.assumeIsolated {
                            self?.updateListenItem()
                        }
                    }
                }
                updateListenItem()
                return item

            case .storyPagesBrowser:
                return makeToolbarItem(itemIdentifier,
                                       image: Utilities.imageNamed("original_button.png", sized: 24),
                                       label: NBLocalization.text("Show Original Story"),
                                       action: #selector(StoryPagesViewController.showOriginalSubview(_:)))

            default:
                return nil
        }
    }

    @MainActor func makeToolbarItem(_ identifier: NSToolbarItem.Identifier,
                         image: UIImage?,
                         label: String,
                         action: Selector,
                         target: AnyObject? = nil) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)

        item.image = image
        item.label = label
        item.action = action
        item.target = target

        return item
    }

    @MainActor func updateListenItem() {
        let player = ListenPlayer.shared
        if player.wantsToPlay {
            listenToolbarItem?.image = UIImage(systemName: "pause.fill")
            listenToolbarItem?.label = NBLocalization.text("Pause Listening")
        } else if player.isActive {
            listenToolbarItem?.image = UIImage(systemName: "play.fill")
            listenToolbarItem?.label = NBLocalization.text("Resume Listening")
        } else {
            listenToolbarItem?.image = UIImage(systemName: "headphones")
            listenToolbarItem?.label = NBLocalization.text("Listen")
        }
    }

    @MainActor func updateFullScreenIcon(isFullScreen: Bool) {
        let iconName = isFullScreen
            ? "arrow.down.right.and.arrow.up.left"
            : "arrow.up.left.and.arrow.down.right"
        fullScreenToolbarItem?.image = UIImage(systemName: iconName)
        fullScreenToolbarItem?.label = isFullScreen ? NBLocalization.text("Exit Full Screen") : NBLocalization.text("Full Screen")
    }
}
#endif
