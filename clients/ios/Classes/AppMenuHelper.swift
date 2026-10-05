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
    
    private static let siteMenuIdentifier = UIMenu.Identifier("com.newsblur.site")
    private static let storyMenuIdentifier = UIMenu.Identifier("com.newsblur.story")

    @objc(buildMenuWithBuilder:)
    func buildMenu(with builder: UIMenuBuilder) {
        guard builder.system == .main else { return }

        // Remove existing custom menus to prevent duplicates on rebuild
        builder.remove(menu: Self.siteMenuIdentifier)
        builder.remove(menu: Self.storyMenuIdentifier)

        // Remove/adjust system menus first
        if #available(iOS 16.0, *) {
            builder.remove(menu: .format)
            builder.remove(menu: .find)
        }
        
        // ===== FILE =====
        builder.replaceChildren(ofMenu: .file) { _ in [
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: NBLocalization.text("New Site"),
                             image: UIImage(systemName: "plus"),
                             action: #selector(BaseViewController.newSite(_:)),
                             input: "n",
                             modifierFlags: [.command, .alternate]),
                UIKeyCommand(title: NBLocalization.text("Reload Sites"),
                             image: UIImage(systemName: "arrow.clockwise"),
                             action: #selector(BaseViewController.reloadFeeds(_:)),
                             input: "r",
                             modifierFlags: [.command])
            ]),
            
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: NBLocalization.text("Mute Sites"),
                             image: UIImage(systemName: "square.grid.3x3.middleleft.filled"),
                             action: #selector(BaseViewController.showMuteSites(_:)),
                             input: "m",
                             modifierFlags: [.command, .shift]),
                UIKeyCommand(title: NBLocalization.text("Organize Sites"),
                             image: UIImage(systemName: "folder"),
                             action: #selector(BaseViewController.showOrganizeSites(_:)),
                             input: "o",
                             modifierFlags: [.command, .shift]),
                UIKeyCommand(title: NBLocalization.text("Widget Sites"),
                             image: UIImage(systemName: "square.grid.2x2"),
                             action: #selector(BaseViewController.showWidgetSites(_:)),
                             input: "w",
                             modifierFlags: [.command, .shift])
            ]),
            
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: NBLocalization.text("Notifications"),
                             image: UIImage(systemName: "bell"),
                             action: #selector(BaseViewController.showNotifications(_:)),
                             input: "n",
                             modifierFlags: [.command, .shift]),
                UIKeyCommand(title: NBLocalization.text("Find Friends"),
                             image: UIImage(systemName: "person.2"),
                             action: #selector(BaseViewController.showFindFriends(_:)),
                             input: "f",
                             modifierFlags: [.command, .shift])
            ]),
            
            UIMenu(title: "", options: .displayInline, children: [
                UICommand(title: NBLocalization.text("Premium"),
                          image: UIImage(systemName: "crown"),
                          action: #selector(BaseViewController.showPremium(_:))),
            ]),
            
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: NBLocalization.text("Log Out"),
                             image: UIImage(systemName: "rectangle.portrait.and.arrow.right"),
                             action: #selector(BaseViewController.showLogout(_:)),
                             input: "l",
                             modifierFlags: [.command, .shift])
            ])
        ]}
        
        // ===== EDIT =====
        builder.insertChild(
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: NBLocalization.text("Find in Sites"),
                             image: UIImage(systemName: "magnifyingglass"),
                             action: #selector(BaseViewController.findInFeeds(_:)),
                             input: "f",
                             modifierFlags: [.command, .alternate]),
                UIKeyCommand(title: NBLocalization.text("Find in Feed"),
                             image: UIImage(systemName: "magnifyingglass"),
                             action: #selector(BaseViewController.findInFeedDetail(_:)),
                             input: "f",
                             modifierFlags: [.command])
            ]), atEndOfMenu: .edit)
        
        // ===== VIEW =====
        builder.replaceChildren(ofMenu: .view) { _ in [
            UIMenu(title: "", options: .displayInline, children: [
                UIMenu(title: NBLocalization.text("Columns"), image: UIImage(systemName: "rectangle.split.3x1"), children: [
                    UIKeyCommand(title: NBLocalization.text("Automatic"), image: UIImage(systemName: "wand.and.stars"), action: #selector(BaseViewController.chooseColumns(_:)),
                                 input: "4", modifierFlags: [.command, .alternate],
                                 propertyList: "auto", state: .off),
                    UIKeyCommand(title: NBLocalization.text("Three"), image: UIImage(systemName: "rectangle.split.3x1"), action: #selector(BaseViewController.chooseColumns(_:)),
                                 input: "3", modifierFlags: [.command, .alternate],
                                 propertyList: "tile", state: .off),
                    UIKeyCommand(title: NBLocalization.text("Two"), image: UIImage(systemName: "rectangle.split.2x1"), action: #selector(BaseViewController.chooseColumns(_:)),
                                 input: "2", modifierFlags: [.command, .alternate],
                                 propertyList: "displace", state: .off),
                    UIKeyCommand(title: NBLocalization.text("One"), image: UIImage(systemName: "rectangle"), action: #selector(BaseViewController.chooseColumns(_:)),
                                 input: "1", modifierFlags: [.command, .alternate],
                                 propertyList: "overlay", state: .off)
                ]),
                // Submenu: Layout
                UIMenu(title: NBLocalization.text("Layout"), image: UIImage(systemName: "square.grid.3x3"), children: [
                    UICommand(title: NBLocalization.text("Left"),
                              image: UIImage(systemName: "sidebar.left"),
                              action: #selector(BaseViewController.chooseLayout(_:)),
                              propertyList: "titles_on_left"),
                    UICommand(title: NBLocalization.text("Top"),
                              image: UIImage(systemName: "rectangle.tophalf.inset.filled"),
                              action: #selector(BaseViewController.chooseLayout(_:)),
                              propertyList: "titles_on_top"),
                    UICommand(title: NBLocalization.text("Bottom"),
                              image: UIImage(systemName: "rectangle.bottomhalf.inset.filled"),
                              action: #selector(BaseViewController.chooseLayout(_:)),
                              propertyList: "titles_on_bottom"),
                    UICommand(title: NBLocalization.text("List"),
                              image: UIImage(systemName: "list.bullet"),
                              action: #selector(BaseViewController.chooseLayout(_:)),
                              propertyList: "titles_in_list"),
                    UICommand(title: NBLocalization.text("Magazine"),
                              image: UIImage(systemName: "newspaper"),
                              action: #selector(BaseViewController.chooseLayout(_:)),
                              propertyList: "titles_in_magazine"),
                    UICommand(title: NBLocalization.text("Grid"),
                              image: UIImage(systemName: "square.grid.2x2"),
                              action: #selector(BaseViewController.chooseLayout(_:)),
                              propertyList: "titles_in_grid"),
                ]),
                // Submenu: Intelligence
                UIMenu(title: NBLocalization.text("Show"), image: UIImage(systemName: "tray.full"), children: [
                    UIKeyCommand(title: NBLocalization.text("All Stories"),
                                 image: UIImage(systemName: "tray.full"),
                                 action: #selector(BaseViewController.chooseIntelligence(_:)),
                                 input: "0", modifierFlags: [.command],
                                 propertyList: "0"),
                    UIKeyCommand(title: NBLocalization.text("Unread Stories"),
                                 image: UIImage(systemName: "circle"),
                                 action: #selector(BaseViewController.chooseIntelligence(_:)),
                                 input: "1", modifierFlags: [.command],
                                 propertyList: "1"),
                    UIKeyCommand(title: NBLocalization.text("Focus Stories"),
                                 image: UIImage(systemName: "scope"),
                                 action: #selector(BaseViewController.chooseIntelligence(_:)),
                                 input: "2", modifierFlags: [.command],
                                 propertyList: "2"),
                    UIKeyCommand(title: NBLocalization.text("Saved Stories"),
                                 image: UIImage(systemName: "bookmark"),
                                 action: #selector(BaseViewController.chooseIntelligence(_:)),
                                 input: "3", modifierFlags: [.command],
                                 propertyList: "3")
                ]),
                // Submenu: Dashboard
                UIMenu(title: NBLocalization.text("Dashboard"), image: UIImage(systemName: "speedometer"), children: [
                    UICommand(title: NBLocalization.text("Hidden"),
                              image: UIImage(systemName: "eye.slash"),
                              action: #selector(BaseViewController.chooseDashboard(_:)),
                              propertyList: "none"),
                    UICommand(title: NBLocalization.text("Single Column"),
                              image: UIImage(systemName: "rectangle"),
                              action: #selector(BaseViewController.chooseDashboard(_:)),
                              propertyList: "single"),
                    UICommand(title: NBLocalization.text("Two Columns"),
                              image: UIImage(systemName: "rectangle.split.2x1"),
                              action: #selector(BaseViewController.chooseDashboard(_:)),
                              propertyList: "vertical"),
                    UICommand(title: NBLocalization.text("Two Rows"),
                              image: UIImage(systemName: "rectangle.split.1x2"),
                              action: #selector(BaseViewController.chooseDashboard(_:)),
                              propertyList: "horizontal")
                ]),
            ]),
            UIMenu(title: "", options: .displayInline, children: [
                // Submenu: Title
                UIMenu(title: NBLocalization.text("Story Preview"), image: UIImage(systemName: "text.alignleft"), children: [
                    UICommand(title: NBLocalization.text("Only Title"),
                              image: UIImage(systemName: "textformat"),
                              action: #selector(BaseViewController.chooseTitle(_:)),
                              propertyList: "title"),
                    UICommand(title: NBLocalization.text("Short"),
                              image: UIImage(systemName: "text.alignleft"),
                              action: #selector(BaseViewController.chooseTitle(_:)),
                              propertyList: "short"),
                    UICommand(title: NBLocalization.text("Medium"),
                              image: UIImage(systemName: "text.alignleft"),
                              action: #selector(BaseViewController.chooseTitle(_:)),
                              propertyList: "medium"),
                    UICommand(title: NBLocalization.text("Long"),
                              image: UIImage(systemName: "text.alignleft"),
                              action: #selector(BaseViewController.chooseTitle(_:)),
                              propertyList: "long")
                ]),
                // Submenu: Preview
                UIMenu(title: NBLocalization.text("Image Preview"), image: UIImage(systemName: "photo"), children: [
                    UICommand(title: NBLocalization.text("None"),
                              image: UIImage(systemName: "nosign"),
                              action: #selector(BaseViewController.choosePreview(_:)),
                              propertyList: "none"),
                    UICommand(title: NBLocalization.text("Small Left"),
                              image: UIImage(systemName: "rectangle.leadingthird.inset.filled"),
                              action: #selector(BaseViewController.choosePreview(_:)),
                              propertyList: "small_left"),
                    UICommand(title: NBLocalization.text("Large Left"),
                              image: UIImage(systemName: "rectangle.leadinghalf.inset.filled"),
                              action: #selector(BaseViewController.choosePreview(_:)),
                              propertyList: "large_left"),
                    UICommand(title: NBLocalization.text("Small Right"),
                              image: UIImage(systemName: "rectangle.trailingthird.inset.filled"),
                              action: #selector(BaseViewController.choosePreview(_:)),
                              propertyList: "small_right"),
                    UICommand(title: NBLocalization.text("Large Right"),
                              image: UIImage(systemName: "rectangle.trailinghalf.inset.filled"),
                              action: #selector(BaseViewController.choosePreview(_:)),
                              propertyList: "large_right"),
                ]),
            ]),
            UIMenu(title: "", options: .displayInline, children: [
                // Submenu: Grid
                UIMenu(title: NBLocalization.text("Grid Columns"), image: UIImage(systemName: "rectangle.grid.2x2"), children: [
                    UICommand(title: NBLocalization.text("Auto"),
                              image: UIImage(systemName: "wand.and.stars"),
                              action: #selector(BaseViewController.chooseGridColumns(_:)),
                              propertyList: "auto"),
                    UICommand(title: "1",
                              image: UIImage(systemName: "rectangle.grid.1x2"),
                              action: #selector(BaseViewController.chooseGridColumns(_:)),
                              propertyList: "1"),
                    UICommand(title: "2",
                              image: UIImage(systemName: "rectangle.grid.2x2"),
                              action: #selector(BaseViewController.chooseGridColumns(_:)),
                              propertyList: "2"),
                    UICommand(title: "3",
                              image: UIImage(systemName: "rectangle.grid.3x2"),
                              action: #selector(BaseViewController.chooseGridColumns(_:)),
                              propertyList: "3"),
                    UICommand(title: "4",
                              image: UIImage(systemName: "rectangle.grid.3x3"),
                              action: #selector(BaseViewController.chooseGridColumns(_:)),
                              propertyList: "4")
                ]),
                UIMenu(title: NBLocalization.text("Grid Height"), image: UIImage(systemName: "rectangle.expand.vertical"), children: [
                    UICommand(title: NBLocalization.text("Extra Short"),
                              image: UIImage(systemName: "rectangle.compress.vertical"),
                              action: #selector(BaseViewController.chooseGridHeight(_:)),
                              propertyList: "xs"),
                    UICommand(title: NBLocalization.text("Short"),
                              image: UIImage(systemName: "text.alignleft"),
                              action: #selector(BaseViewController.chooseGridHeight(_:)),
                              propertyList: "short"),
                    UICommand(title: NBLocalization.text("Medium"),
                              image: UIImage(systemName: "text.alignleft"),
                              action: #selector(BaseViewController.chooseGridHeight(_:)),
                              propertyList: "medium"),
                    UICommand(title: NBLocalization.text("Tall"),
                              image: UIImage(systemName: "rectangle.expand.vertical"),
                              action: #selector(BaseViewController.chooseGridHeight(_:)),
                              propertyList: "tall"),
                    UICommand(title: NBLocalization.text("Extra Tall"),
                              image: UIImage(systemName: "rectangle.expand.vertical"),
                              action: #selector(BaseViewController.chooseGridHeight(_:)),
                              propertyList: "xl")
                ]),
            ]),
            UIMenu(title: "", options: .displayInline, children: [
                // Submenu: Typography / Spacing / Theme
                UIMenu(title: NBLocalization.text("Font Size"), image: UIImage(systemName: "textformat.size"), children: [
                    UIKeyCommand(title: NBLocalization.text("Extra Small"),
                                 image: UIImage(systemName: "textformat.size.smaller"),
                                 action: #selector(BaseViewController.chooseFontSize(_:)),
                                 input: "5", modifierFlags: [.command, .alternate],
                                 propertyList: "xs"),
                    UIKeyCommand(title: NBLocalization.text("Small"),
                                 image: UIImage(systemName: "textformat.size.smaller"),
                                 action: #selector(BaseViewController.chooseFontSize(_:)),
                                 input: "6", modifierFlags: [.command, .alternate],
                                 propertyList: "small"),
                    UIKeyCommand(title: NBLocalization.text("Medium"),
                                 image: UIImage(systemName: "text.alignleft"),
                                 action: #selector(BaseViewController.chooseFontSize(_:)),
                                 input: "7", modifierFlags: [.command, .alternate],
                                 propertyList: "medium"),
                    UIKeyCommand(title: NBLocalization.text("Large"),
                                 image: UIImage(systemName: "textformat.size.larger"),
                                 action: #selector(BaseViewController.chooseFontSize(_:)),
                                 input: "8", modifierFlags: [.command, .alternate],
                                 propertyList: "large"),
                    UIKeyCommand(title: NBLocalization.text("Extra Large"),
                                 image: UIImage(systemName: "textformat.size.larger"),
                                 action: #selector(BaseViewController.chooseFontSize(_:)),
                                 input: "9", modifierFlags: [.command, .alternate],
                                 propertyList: "xl"),
                ]),
                UIMenu(title: NBLocalization.text("Spacing"), image: UIImage(systemName: "line.3.horizontal.decrease"), children: [
                    UICommand(title: NBLocalization.text("Compact"),
                              image: UIImage(systemName: "line.3.horizontal.decrease"),
                              action: #selector(BaseViewController.chooseSpacing(_:)),
                              propertyList: "compact"),
                    UICommand(title: NBLocalization.text("Comfortable"),
                              image: UIImage(systemName: "line.3.horizontal"),
                              action: #selector(BaseViewController.chooseSpacing(_:)),
                              propertyList: "comfortable")
                ]),
                UIMenu(title: NBLocalization.text("Theme"), image: UIImage(systemName: "paintpalette"), children: [
                    UICommand(title: NBLocalization.text("Auto"),
                              image: UIImage(systemName: "wand.and.stars"),
                              action: #selector(BaseViewController.chooseTheme(_:)),
                              propertyList: "auto"),
                    UICommand(title: NBLocalization.text("Light"),
                              image: UIImage(systemName: "sun.max"),
                              action: #selector(BaseViewController.chooseTheme(_:)),
                              propertyList: "light"),
                    UICommand(title: NBLocalization.text("Sepia"),
                              image: UIImage(systemName: "camera.filters"),
                              action: #selector(BaseViewController.chooseTheme(_:)),
                              propertyList: "sepia"),
                    UICommand(title: NBLocalization.text("Medium"),
                              image: UIImage(systemName: "text.alignleft"),
                              action: #selector(BaseViewController.chooseTheme(_:)),
                              propertyList: "medium"),
                    UICommand(title: NBLocalization.text("Dark"),
                              image: UIImage(systemName: "moon"),
                              action: #selector(BaseViewController.chooseTheme(_:)),
                              propertyList: "dark")
                ]),
            ]),
            // Plain item: Toggle Sidebar
            UIKeyCommand(title: NBLocalization.text("Show Sidebar"),
                         image: UIImage(systemName: "sidebar.left"),
                         action: #selector(BaseViewController.toggleFeeds(_:)),
                         input: "s", modifierFlags: [.command, .control]
                        )
        ]}
        
        // ===== SITE (custom) =====
        let site = UIMenu(title: NBLocalization.text("Site"), identifier: Self.siteMenuIdentifier, children: [
            UIMenu(title: NBLocalization.text("Manage"), image: UIImage(systemName: "gearshape"), children: [
                UICommand(title: NBLocalization.text("Rename Site…"),
                          image: UIImage(systemName: "pencil"),
                          action: #selector(BaseViewController.openRenameSite(_:))),
                UICommand(title: NBLocalization.text("Mute Site…"),
                          image: UIImage(systemName: "square.grid.3x3.middleleft.filled"),
                          action: #selector(BaseViewController.muteSite(_:))),
                UICommand(title: NBLocalization.text("Delete Site…"),
                          image: UIImage(systemName: "trash"),
                          action: #selector(BaseViewController.deleteSite(_:)))
            ]),
            UIMenu(title: NBLocalization.text("Mark Story Read"), image: UIImage(systemName: "checkmark.circle"), children: [
                UICommand(title: NBLocalization.text("On Scroll or Selection"),
                          image: UIImage(systemName: "scroll"),
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "scroll"),
                UICommand(title: NBLocalization.text("Only on Selection"),
                          image: UIImage(systemName: "cursorarrow.click"),
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "selection"),
                UICommand(title: NBLocalization.text("After 1 Second"),
                          image: UIImage(systemName: "timer"),
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "after1"),
                UICommand(title: NBLocalization.text("After 2 Seconds"),
                          image: UIImage(systemName: "timer"),
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "after2"),
                UICommand(title: NBLocalization.text("After 3 Seconds"),
                          image: UIImage(systemName: "timer"),
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "after3"),
                UICommand(title: NBLocalization.text("After 4 Seconds"),
                          image: UIImage(systemName: "timer"),
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "after4"),
                UICommand(title: NBLocalization.text("After 5 Seconds"),
                          image: UIImage(systemName: "timer"),
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "after5"),
                UICommand(title: NBLocalization.text("After 10 Seconds"),
                          image: UIImage(systemName: "timer"),
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "after10"),
                UICommand(title: NBLocalization.text("After 15 Seconds"),
                          image: UIImage(systemName: "timer"),
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "after15"),
                UICommand(title: NBLocalization.text("After 30 Seconds"),
                          image: UIImage(systemName: "timer"),
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "after30"),
                UICommand(title: NBLocalization.text("After 45 Seconds"),
                          image: UIImage(systemName: "timer"),
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "after45"),
                UICommand(title: NBLocalization.text("After 60 Seconds"),
                          image: UIImage(systemName: "timer"),
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "after60"),
                UICommand(title: NBLocalization.text("Manually"),
                          image: UIImage(systemName: "hand.tap"),
                          action: #selector(BaseViewController.chooseMarkRead(_:)),
                          propertyList: "manually"),
            ]),
            UIMenu(title: "", options: .displayInline, children: [
                UICommand(title: NBLocalization.text("Train…"),
                          image: UIImage(systemName: "brain"),
                          action: #selector(BaseViewController.openTrainSite(_:))),
                UICommand(title: NBLocalization.text("Notifications…"),
                          image: UIImage(systemName: "bell"),
                          action: #selector(BaseViewController.openNotifications(_:))),
                UICommand(title: NBLocalization.text("Statistics…"),
                          image: UIImage(systemName: "chart.bar"),
                          action: #selector(BaseViewController.openStatistics(_:))),
            ]),
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: NBLocalization.text("Insta-Fetch Stories"),
                             image: UIImage(systemName: "bolt"),
                             action: #selector(BaseViewController.instaFetchFeed(_:)),
                             input: "r", modifierFlags: [.command, .alternate])
            ]),
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: NBLocalization.text("Mark All as Read"),
                             image: UIImage(systemName: "checkmark.circle"),
                             action: #selector(BaseViewController.doMarkAllRead(_:)),
                             input: "a", modifierFlags: [.command, .alternate]
                            )
            ]),
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: NBLocalization.text("Next Site"),
                             image: UIImage(systemName: "chevron.down"),
                             action: #selector(BaseViewController.nextSite(_:)),
                             input: "j", modifierFlags: [.command, .alternate]),
                UIKeyCommand(title: NBLocalization.text("Previous Site"),
                             image: UIImage(systemName: "chevron.up"),
                             action: #selector(BaseViewController.previousSite(_:)),
                             input: "k", modifierFlags: [.command, .alternate]),
                UIKeyCommand(title: NBLocalization.text("Next Folder"),
                             image: UIImage(systemName: "chevron.down"),
                             action: #selector(BaseViewController.nextFolder(_:)),
                             input: "j", modifierFlags: [.command, .shift]),
                UIKeyCommand(title: NBLocalization.text("Previous Folder"),
                             image: UIImage(systemName: "chevron.up"),
                             action: #selector(BaseViewController.previousFolder(_:)),
                             input: "k", modifierFlags: [.command, .shift])
            ]),
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: NBLocalization.text("Open Dashboard"),
                             image: UIImage(systemName: "speedometer"),
                             action: #selector(BaseViewController.openDashboard(_:)),
                             input: "d", modifierFlags: [.command, .shift]),
                UIKeyCommand(title: NBLocalization.text("Open All Stories"),
                             image: UIImage(systemName: "rectangle.stack"),
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
        let story = UIMenu(title: NBLocalization.text("Story"), identifier: Self.storyMenuIdentifier, children: [
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: NBLocalization.text("Save This Story"),
                             image: UIImage(systemName: "bookmark"),
                             action: #selector(StoriesCollection.toggleStorySaved(_:)),
                             input: "s", modifierFlags: [.command]),
                UIKeyCommand(title: NBLocalization.text("Mark as Read"),
                             image: UIImage(systemName: "checkmark.circle"),
                             action: #selector(StoriesCollection.toggleStoryUnread(_:)),
                             input: "m", modifierFlags: [.command, .alternate]),
                UICommand(title: NBLocalization.text("Send To…"),
                          image: UIImage(systemName: "paperplane"),
                          action: #selector(BaseViewController.showSendTo(_:))),
                UICommand(title: NBLocalization.text("Train This Story…"),
                          image: UIImage(systemName: "brain"),
                          action: #selector(BaseViewController.showTrain(_:))),
                UICommand(title: NBLocalization.text("Share This Story…"),
                          image: UIImage(systemName: "square.and.arrow.up"),
                          action: #selector(BaseViewController.showShare(_:)))
            ]),
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: NBLocalization.text("Next Unread Story"),
                             image: UIImage(systemName: "chevron.down.circle"),
                             action: #selector(BaseViewController.nextUnreadStory(_:)),
                             input: "u", modifierFlags: [.command]),
                UIKeyCommand(title: NBLocalization.text("Next Story"),
                             image: UIImage(systemName: "chevron.down"),
                             action: #selector(BaseViewController.nextStory(_:)),
                             input: "j", modifierFlags: [.command]),
                UIKeyCommand(title: NBLocalization.text("Previous Story"), image: UIImage(systemName: "chevron.up"), action: #selector(BaseViewController.previousStory(_:)),
                             input: "k", modifierFlags: [.command])
            ]),
            UIMenu(title: "", options: .displayInline, children: [
                UIKeyCommand(title: NBLocalization.text("Text View"),
                             image: UIImage(systemName: "doc.plaintext"),
                             action: #selector(BaseViewController.toggleTextStory(_:)),
                             input: "t", modifierFlags: [.command, .alternate]),
                UIKeyCommand(title: NBLocalization.text("Open in Browser"),
                             image: UIImage(systemName: "safari"),
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
                UIKeyCommand(title: NBLocalization.text("Keyboard Shortcuts"),
                             image: UIImage(systemName: "keyboard"),
                             action: #selector(BaseViewController.showKeyboardShortcuts(_:)),
                             input: "/", modifierFlags: [.shift]),
                UICommand(title: NBLocalization.text("Support Forum"),
                          image: UIImage(systemName: "questionmark.circle"),
                          action: #selector(BaseViewController.showSupportForum(_:))),
                UIMenu(title: "", options: .displayInline, children: [
                    UICommand(title: NBLocalization.text("Manage Account on the Web"),
                              image: UIImage(systemName: "person.crop.circle.badge.gear"),
                              action: #selector(BaseViewController.showManageAccount(_:)))
                ])
            ]), atEndOfMenu: .help)
    }
}
