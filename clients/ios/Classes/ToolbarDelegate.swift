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
}

extension NSToolbarItem.Identifier {
    static let reloadFeeds = NSToolbarItem.Identifier("com.newsblur.reloadFeeds")
    static let feedDetailUnread = NSToolbarItem.Identifier("com.newsblur.feedDetailUnread")
    static let feedDetailSettings = NSToolbarItem.Identifier("com.newsblur.feedDetailSettings")
    static let storyPagesSettings = NSToolbarItem.Identifier("com.newsblur.storyPagesSettings")
    static let storyPagesBrowser = NSToolbarItem.Identifier("com.newsblur.storyPagesBrowser")
}

extension ToolbarDelegate: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        let identifiers: [NSToolbarItem.Identifier] = [
            .toggleSidebar,
            .space,
            .reloadFeeds,
            .space,
            .feedDetailUnread,
            .feedDetailSettings,
            .flexibleSpace,
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
            case .reloadFeeds:
                return makeToolbarItem(itemIdentifier,
                                       image: UIImage(systemName: "arrow.clockwise"),
                                       label: "Reload Sites",
                                       action: #selector(BaseViewController.reloadFeeds(_:)))
                
            case .feedDetailUnread:
                return makeToolbarItem(itemIdentifier,
                                       image: Utilities.imageNamed("mark-read", sized: 24),
                                       label: "Mark as Read",
                                       action: #selector(BaseViewController.openMarkReadMenu(_:)))
                
            case .feedDetailSettings:
                return makeToolbarItem(itemIdentifier,
                                       image: Utilities.imageNamed("settings", sized: 24),
                                       label: "Site Settings",
                                       action: #selector(BaseViewController.openSettingsMenu(_:)))
                
            case .storyPagesSettings:
                return makeToolbarItem(itemIdentifier,
                                       image: Utilities.imageNamed("settings", sized: 24),
                                       label: "Story Settings",
                                       action: #selector(StoryPagesViewController.toggleFontSize(_:)))
                
            case .storyPagesBrowser:
                return makeToolbarItem(itemIdentifier,
                                       image: Utilities.imageNamed("original_button.png", sized: 24),
                                       label: "Show Original Story",
                                       action: #selector(StoryPagesViewController.showOriginalSubview(_:)))
                
            default:
                return nil
        }
    }
    
    func makeToolbarItem(_ identifier: NSToolbarItem.Identifier,
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
}
#endif
