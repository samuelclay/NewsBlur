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
    static let feedDetailSettings = NSToolbarItem.Identifier("com.newsblur.feedDetailSettings")
}

extension ToolbarDelegate: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        let identifiers: [NSToolbarItem.Identifier] = [
            .toggleSidebar,
            .reloadFeeds,
            .flexibleSpace,
            .feedDetailSettings
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
                
            case .feedDetailSettings:
                return makeToolbarItem(itemIdentifier,
                                       image: Utilities.imageNamed("settings", sized: 24),
                                       label: "Site Settings",
                                       action: #selector(FeedDetailViewController.doOpenSettingsMenu(_:)))
                
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
