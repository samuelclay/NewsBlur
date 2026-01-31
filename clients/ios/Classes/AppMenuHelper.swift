//
//  AppMenuHelper.swift
//  NewsBlur
//
//  Created by David Sinclair on 2025-08-26.
//  Copyright © 2025 NewsBlur. All rights reserved.
//

import Foundation
import UIKit

/// Singleton class to build the app menus.
class AppMenuHelper: NSObject {
    /// Singleton shared instance.
    @MainActor @objc static let shared = AppMenuHelper()
    
    /// Whether or not the menus have been prepared yet.
    @objc var prepared = false
    
    /// Private init to prevent others constructing a new instance.
    private override init() {
    }
    
    /// Prepare the menus if needed.
    @objc func prepareIfNeeded() {
        if !prepared {
            UIMenuSystem.main.setNeedsRebuild()
            
            prepared = true
        }
    }
    
    // MARK: - Build Menus
    
    @objc(buildMenuWithBuilder:)
    func buildMenu(with builder: UIMenuBuilder) {
        // Remove/adjust system menus first
        if #available(iOS 16.0, *) {
            builder.remove(menu: .format)
        }
        
        // ===== FILE =====
        builder.replaceChildren(ofMenu: .file) { _ in [
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: "New Site",
                             action: #selector(BaseViewController.newSite(_:)),
                             input: "n",
                             modifierFlags: [.command, .alternate]),
                UIKeyCommand(title: "Reload Sites",
                             action: #selector(BaseViewController.reloadFeeds(_:)),
                             input: "r",
                             modifierFlags: [.command])
            ]),

            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: "Mute Sites",
                             action: #selector(BaseViewController.showMuteSites(_:)),
                             input: "m",
                             modifierFlags: [.command, .shift]),
                UIKeyCommand(title: "Organize Sites",
                             action: #selector(BaseViewController.showOrganizeSites(_:)),
                             input: "o",
                             modifierFlags: [.command, .shift]),
                UIKeyCommand(title: "Widget Sites",
                             action: #selector(BaseViewController.showWidgetSites(_:)),
                             input: "w",
                             modifierFlags: [.command, .shift])
            ]),
            
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: "Notifications",
                             action: #selector(BaseViewController.showNotifications(_:)),
                             input: "n",
                             modifierFlags: [.command, .shift]),
                UIKeyCommand(title: "Find Friends",
                             action: #selector(BaseViewController.showFindFriends(_:)),
                             input: "f",
                             modifierFlags: [.command, .shift])
            ]),
            
            UIMenu(title: "", options: .displayInline, children: [
                UICommand(title: "Premium",
                          action: #selector(BaseViewController.showPremium(_:))),
            ]),
            
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: "Log Out",
                             action: #selector(BaseViewController.showLogout(_:)),
                             input: "l",
                             modifierFlags: [.command, .shift])
            ])
        ]}
        
        // ===== EDIT =====
        builder.insertChild(
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: "Find in Sites",
                             action: #selector(BaseViewController.findInFeeds(_:)),
                             input: "f",
                             modifierFlags: [.command, .alternate]),
                UIKeyCommand(title: "Find in Feed",
                             action: #selector(BaseViewController.findInFeedDetail(_:)),
                             input: "f",
                             modifierFlags: [.command])
            ]), atEndOfMenu: .edit)
        
        // ===== VIEW =====
        builder.replaceChildren(ofMenu: .view) { _ in [
            UIMenu(title: "", options: .displayInline, children: [
                
            UIMenu(title: "Sites", children: [
                UIKeyCommand(title: "Show Beside Stories", action: #selector(BaseViewController.chooseColumns(_:)),
                             input: "2", modifierFlags: [.command, .alternate],
                             propertyList: "tile", state: .off),
                UIKeyCommand(title: "Show On Top of Stories", action: #selector(BaseViewController.chooseColumns(_:)),
                             input: "1", modifierFlags: [.command, .alternate],
                             propertyList: "overlay", state: .off)
            ]),
            // Submenu: Layout
            UIMenu(title: "Layout", children: [
                UICommand(title: "Left",
                          action: #selector(BaseViewController.chooseLayout(_:)),
                          propertyList: "titles_on_left"),
                UICommand(title: "Top",
                          action: #selector(BaseViewController.chooseLayout(_:)),
                          propertyList: "titles_on_top"),
                UICommand(title: "Bottom",
                          action: #selector(BaseViewController.chooseLayout(_:)),
                          propertyList: "titles_on_bottom"),
                UICommand(title: "List",
                          action: #selector(BaseViewController.chooseLayout(_:)),
                          propertyList: "titles_in_list"),
                UICommand(title: "Magazine",
                          action: #selector(BaseViewController.chooseLayout(_:)),
                          propertyList: "titles_in_magazine"),
                UICommand(title: "Grid",
                          action: #selector(BaseViewController.chooseLayout(_:)),
                          propertyList: "titles_in_grid"),
            ]),
            // Submenu: Intelligence
            UIMenu(title: "Show", children: [
                UIKeyCommand(title: "All Stories",
                             action: #selector(BaseViewController.chooseIntelligence(_:)),
                             input: "0", modifierFlags: [.command],
                             propertyList: "0"),
                UIKeyCommand(title: "Unread Stories",
                             action: #selector(BaseViewController.chooseIntelligence(_:)),
                             input: "1", modifierFlags: [.command],
                             propertyList: "1"),
                UIKeyCommand(title: "Focus Stories",
                             action: #selector(BaseViewController.chooseIntelligence(_:)),
                             input: "2", modifierFlags: [.command],
                             propertyList: "2"),
                UIKeyCommand(title: "Saved Stories",
                             action: #selector(BaseViewController.chooseIntelligence(_:)),
                             input: "3", modifierFlags: [.command],
                             propertyList: "3")
            ]),
            // Submenu: Dashboard
            UIMenu(title: "Dashboard", children: [
                UICommand(title: "Hidden",
                          action: #selector(BaseViewController.chooseDashboard(_:)),
                          propertyList: "none"),
                UICommand(title: "Single Column",
                          action: #selector(BaseViewController.chooseDashboard(_:)),
                          propertyList: "single"),
                UICommand(title: "Two Columns",
                          action: #selector(BaseViewController.chooseDashboard(_:)),
                          propertyList: "vertical"),
                UICommand(title: "Two Rows",
                          action: #selector(BaseViewController.chooseDashboard(_:)),
                          propertyList: "horizontal")
            ]),
            ]),
            UIMenu(title: "", options: .displayInline, children: [
                // Submenu: Title
                UIMenu(title: "Story Preview", children: [
                    UICommand(title: "Only Title",
                              action: #selector(BaseViewController.chooseTitle(_:)),
                              propertyList: "title"),
                    UICommand(title: "Short",
                              action: #selector(BaseViewController.chooseTitle(_:)),
                              propertyList: "short"),
                    UICommand(title: "Medium",
                              action: #selector(BaseViewController.chooseTitle(_:)),
                              propertyList: "medium"),
                    UICommand(title: "Long",
                              action: #selector(BaseViewController.chooseTitle(_:)),
                              propertyList: "long")
                ]),
                // Submenu: Preview
                UIMenu(title: "Image Preview", children: [
                    UICommand(title: "None",
                              action: #selector(BaseViewController.choosePreview(_:)),
                              propertyList: "none"),
                    UICommand(title: "Small Left",
                              action: #selector(BaseViewController.choosePreview(_:)),
                              propertyList: "small_left"),
                    UICommand(title: "Large Left",
                              action: #selector(BaseViewController.choosePreview(_:)),
                              propertyList: "large_left"),
                    UICommand(title: "Small Right",
                              action: #selector(BaseViewController.choosePreview(_:)),
                              propertyList: "small_right"),
                    UICommand(title: "Large Right",
                              action: #selector(BaseViewController.choosePreview(_:)),
                              propertyList: "large_right"),
                ]),
            ]),
            UIMenu(title: "", options: .displayInline, children: [
                // Submenu: Grid
                UIMenu(title: "Grid Columns", children: [
                    UICommand(title: "Auto",
                              action: #selector(BaseViewController.chooseGridColumns(_:)),
                              propertyList: "auto"),
                    UICommand(title: "1",
                              action: #selector(BaseViewController.chooseGridColumns(_:)),
                              propertyList: "1"),
                    UICommand(title: "2",
                              action: #selector(BaseViewController.chooseGridColumns(_:)),
                              propertyList: "2"),
                    UICommand(title: "3",
                              action: #selector(BaseViewController.chooseGridColumns(_:)),
                              propertyList: "3"),
                    UICommand(title: "4",
                              action: #selector(BaseViewController.chooseGridColumns(_:)),
                              propertyList: "4")
                ]),
                UIMenu(title: "Grid Height", children: [
                    UICommand(title: "Extra Short",
                              action: #selector(BaseViewController.chooseGridHeight(_:)),
                              propertyList: "xs"),
                    UICommand(title: "Short",
                              action: #selector(BaseViewController.chooseGridHeight(_:)),
                              propertyList: "short"),
                    UICommand(title: "Medium",
                              action: #selector(BaseViewController.chooseGridHeight(_:)),
                              propertyList: "medium"),
                    UICommand(title: "Tall",
                              action: #selector(BaseViewController.chooseGridHeight(_:)),
                              propertyList: "tall"),
                    UICommand(title: "Extra Tall",
                              action: #selector(BaseViewController.chooseGridHeight(_:)),
                              propertyList: "xl")
                ]),
            ]),
            UIMenu(title: "", options: .displayInline, children: [
                // Submenu: Typography / Spacing / Theme
                UIMenu(title: "Font Size", children: [
                    UIKeyCommand(title: "Extra Small",
                                 action: #selector(BaseViewController.chooseFontSize(_:)),
                                 input: "5", modifierFlags: [.command, .alternate],
                                 propertyList: "xs"),
                    UIKeyCommand(title: "Small",
                                 action: #selector(BaseViewController.chooseFontSize(_:)),
                                 input: "6", modifierFlags: [.command, .alternate],
                                 propertyList: "small"),
                    UIKeyCommand(title: "Medium",
                                 action: #selector(BaseViewController.chooseFontSize(_:)),
                                 input: "7", modifierFlags: [.command, .alternate],
                                 propertyList: "medium"),
                    UIKeyCommand(title: "Large",
                                 action: #selector(BaseViewController.chooseFontSize(_:)),
                                 input: "8", modifierFlags: [.command, .alternate],
                                 propertyList: "large"),
                    UIKeyCommand(title: "Extra Large",
                                 action: #selector(BaseViewController.chooseFontSize(_:)),
                                 input: "9", modifierFlags: [.command, .alternate],
                                 propertyList: "xl"),
                ]),
                UIMenu(title: "Spacing", children: [
                    UICommand(title: "Compact",
                              action: #selector(BaseViewController.chooseSpacing(_:)),
                              propertyList: "compact"),
                    UICommand(title: "Comfortable",
                              action: #selector(BaseViewController.chooseSpacing(_:)),
                              propertyList: "comfortable")
                ]),
                UIMenu(title: "Theme", children: [
                    UICommand(title: "Auto",
                              action: #selector(BaseViewController.chooseTheme(_:)),
                              propertyList: "auto"),
                    UICommand(title: "Light",
                              action: #selector(BaseViewController.chooseTheme(_:)),
                              propertyList: "light"),
                    UICommand(title: "Sepia",
                              action: #selector(BaseViewController.chooseTheme(_:)),
                              propertyList: "sepia"),
                    UICommand(title: "Medium",
                              action: #selector(BaseViewController.chooseTheme(_:)),
                              propertyList: "medium"),
                    UICommand(title: "Dark",
                              action: #selector(BaseViewController.chooseTheme(_:)),
                              propertyList: "dark")
                ]),
            ]),
            // Plain item: Toggle Sidebar
            UIKeyCommand(title: "Show Sidebar",
                         action: #selector(BaseViewController.toggleFeeds(_:)),
                         input: "s", modifierFlags: [.command, .control]
                        )
        ]}
        
        // ===== SITE (custom) =====
        let site = UIMenu(title: "Site",identifier: UIMenu.Identifier("com.newsblur.site"), children: [
            UIMenu(title: "Manage", children: [
                UICommand(title: "Rename Site…",
                          action: #selector(BaseViewController.openRenameSite(_:))),
                UICommand(title: "Mute Site…",
                          action: #selector(BaseViewController.muteSite(_:))),
                UICommand(title: "Delete Site…",
                          action: #selector(BaseViewController.deleteSite(_:)))
            ]),
            UIMenu(title: "Mark Story Read", children: [
                UICommand(title: "On Scroll or Selection",
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "scroll"),
                UICommand(title: "Only on Selection",
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "selection"),
                UICommand(title: "After 1 Second",
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "after1"),
                UICommand(title: "After 2 Seconds",
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "after2"),
                UICommand(title: "After 3 Seconds",
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "after3"),
                UICommand(title: "After 4 Seconds",
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "after4"),
                UICommand(title: "After 5 Seconds",
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "after5"),
                UICommand(title: "After 10 Seconds",
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "after10"),
                UICommand(title: "After 15 Seconds",
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "after15"),
                UICommand(title: "After 30 Seconds",
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "after30"),
                UICommand(title: "After 45 Seconds",
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "after45"),
                UICommand(title: "After 60 Seconds",
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "after60"),
                UICommand(title: "Manually",
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "manually"),
            ]),
            UIMenu(title: "", options: .displayInline, children: [
                UICommand(title: "Train…",
                          action: #selector(BaseViewController.openTrainSite(_:))),
                UICommand(title: "Notifications…",
                          action: #selector(BaseViewController.openNotifications(_:))),
                UICommand(title: "Statistics…",
                          action: #selector(BaseViewController.openStatistics(_:))),
            ]),
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: "Insta-Fetch Stories",
                             action: #selector(BaseViewController.instaFetchFeed(_:)),
                             input: "r", modifierFlags: [.command, .alternate])
            ]),
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: "Mark All as Read",
                             action: #selector(BaseViewController.doMarkAllRead(_:)),
                             input: "a", modifierFlags: [.command, .alternate]
                            )
            ]),
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: "Next Site",
                             action: #selector(BaseViewController.nextSite(_:)),
                             input: "j", modifierFlags: [.command, .alternate]),
                UIKeyCommand(title: "Previous Site",
                             action: #selector(BaseViewController.previousSite(_:)),
                             input: "k", modifierFlags: [.command, .alternate]),
                UIKeyCommand(title: "Next Folder",
                             action: #selector(BaseViewController.nextFolder(_:)),
                             input: "j", modifierFlags: [.command, .shift]),
                UIKeyCommand(title: "Previous Folder",
                             action: #selector(BaseViewController.previousFolder(_:)),
                             input: "k", modifierFlags: [.command, .shift])
            ]),
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: "Open Dashboard",
                             action: #selector(BaseViewController.openDashboard(_:)),
                             input: "d", modifierFlags: [.command, .shift]),
                UIKeyCommand(title: "Open All Stories",
                             action: #selector(BaseViewController.openAllStories(_:)),
                             input: "e", modifierFlags: [.command, .shift])
            ])
        ])
        if #available(iOS 16.0, *) {
            builder.insertSibling(site, beforeMenu: .window)
        } else {
            builder.insertSibling(site, beforeMenu: .help)
        }
        
        // ===== STORY (custom) =====
        let story = UIMenu(title: "Story", identifier: UIMenu.Identifier("com.newsblur.story"), children: [
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: "Save This Story",
                             action: #selector(StoriesCollection.toggleStorySaved(_:)),
                             input: "s", modifierFlags: [.command]),
                UIKeyCommand(title: "Mark as Read",
                             action: #selector(StoriesCollection.toggleStoryUnread(_:)),
                             input: "m", modifierFlags: [.command, .alternate]),
                UICommand(title: "Send To…",
                          action: #selector(BaseViewController.showSendTo(_:))),
                UICommand(title: "Train This Story…",
                          action: #selector(BaseViewController.showTrain(_:))),
                UICommand(title: "Share This Story…",
                          action: #selector(BaseViewController.showShare(_:)))
            ]),
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: "Next Unread Story",
                             action: #selector(BaseViewController.nextUnreadStory(_:)),
                             input: "u", modifierFlags: [.command]),
                UIKeyCommand(title: "Next Story",
                             action: #selector(BaseViewController.nextStory(_:)),
                             input: "j", modifierFlags: [.command]),
                UIKeyCommand(title: "Previous Story", action: #selector(BaseViewController.previousStory(_:)),
                             input: "k", modifierFlags: [.command])
            ]),
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: "Text View",
                             action: #selector(BaseViewController.toggleTextStory(_:)),
                             input: "t", modifierFlags: [.command, .alternate]),
                UIKeyCommand(title: "Open in Browser",
                             action: #selector(BaseViewController.openInBrowser(_:)),
                             input: "o", modifierFlags: [.command])
            ])
        ])
        
        if #available(iOS 16.0, *) {
            builder.insertSibling(story, beforeMenu: .window)
        } else {
            builder.insertSibling(story, beforeMenu: .help)
        }
        
        // ===== HELP =====
        builder.insertChild(
            UIMenu(title: "", options: .displayInline, children: [
                UICommand(title: "Support Forum",
                          action: #selector(BaseViewController.showSupportForum(_:))),
                UIMenu(title: "", options: .displayInline, children: [
                    UICommand(title: "Manage Account on the Web",
                              action: #selector(BaseViewController.showManageAccount(_:)))
                ])
            ]), atEndOfMenu: .help)
    }
}
