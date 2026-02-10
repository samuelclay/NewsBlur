//
//  FeedsViewController.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-08-27.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit
import StoreKit

///Sidebar listing all of the feeds.
class FeedsViewController: FeedsObjCViewController {
    struct Keys {
        static let reviewDate = "datePromptedForReview"
        static let reviewVersion = "versionPromptedForReview"
    }
    
    var appearCount = 0
    
    lazy var appVersion: String = {
        let infoDictionaryKey = kCFBundleVersionKey as String
        
        guard let currentVersion = Bundle.main.object(forInfoDictionaryKey: infoDictionaryKey) as? String else {
            fatalError("Expected to find a bundle version in the info dictionary")
        }
        
        return currentVersion
    }()
    
    var datePromptedForReview: Date {
        get {
            guard let date = UserDefaults.standard.object(forKey: Keys.reviewDate) as? Date else {
                let date = Date()
                UserDefaults.standard.set(date, forKey: Keys.reviewDate)
                return date
            }
            
            return date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.reviewDate)
        }
    }
    
    var versionPromptedForReview: String {
        get {
            return UserDefaults.standard.string(forKey: Keys.reviewVersion) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.reviewVersion)
        }
    }
    
    @objc func addSubfolderFeeds() {
        for folderName in appDelegate.dictFoldersArray {
            if let folderName = folderName as? String {
                addSubfolderFeeds(for: folderName)
            }
        }
    }
    
    private func addSubfolderFeeds(for folderTitle: String) {
        guard let parentTitle = self.parentTitle(for: folderTitle) else {
            return
        }
        
        guard let childFeeds = appDelegate.dictFolders[folderTitle] as? [AnyHashable],
            let parentFeeds = appDelegate.dictFolders[parentTitle] as? [AnyHashable] else {
            return
        }
        
        let existingSubfolders = appDelegate.dictSubfolders[parentTitle] as? [AnyHashable] ?? []
        
        appDelegate.dictFolders[parentTitle] = unique(parentFeeds + childFeeds)
        appDelegate.dictSubfolders[parentTitle] = unique(existingSubfolders + childFeeds)
        
        addSubfolderFeeds(for: parentTitle)
    }
    
    private func unique(_ array: [AnyHashable]) -> [AnyHashable] {
        var seen: Set<AnyHashable> = []
        
        return array.filter { seen.insert($0).inserted }
    }
    
    @objc(parentTitleForFolderTitle:) func parentTitle(for folderTitle: String) -> String? {
        guard let range = folderTitle.range(of: " ▸ ", options: .backwards) else {
            return nil
        }
        
        return String(folderTitle[..<range.lowerBound])
    }
    
    @objc(parentTitlesForFolderTitle:) func parentTitles(for folderTitle: String) -> [String] {
        var parentTitles = [String]()
        
        guard let parentTitle = parentTitle(for: folderTitle) else {
            return []
        }
        
        parentTitles.append(parentTitle)
        parentTitles += self.parentTitles(for: parentTitle)
        
        return parentTitles
    }
    
    @objc(folderTitleForFullFolderPath:) func folderTitle(for fullFolderPath: String) -> String? {
        return fullFolderPath.components(separatedBy: " ▸ ").last
    }
    
    @objc(fullFolderPathForFolderTitle:) func fullFolderPath(for folderTitle: String) -> String? {
        let path = appDelegate.dictFoldersArray.first { folder in
            guard let folder = folder as? String else {
                return false
            }
            
            return folder.components(separatedBy: " ▸ ").last == folderTitle
        }
        
        return path as? String
    }
    
    var dashboardTimer: Timer?
    
    @objc func clearDashboard() {
        NSLog("🎛️ clearDashboard")
        
        appDelegate.feedDetailViewController.dashboardIndex = -1
        appDelegate.feedDetailViewController.dashboardSingleMode = false
        appDelegate.detailViewController.storyTitlesInDashboard = false
        
        dashboardTimer?.invalidate()
        dashboardTimer = nil
    }
    
    @objc func reloadDashboard() {
        NSLog("🎛️ feeds reloadDashboard")
        
        appDelegate.feedDetailViewController.dashboardIndex = -1
        appDelegate.feedDetailViewController.dashboardSingleMode = false
        
        immediatelyLoadNextDash(prepare: false, finishingSingleMode: false)
    }
    
    @objc func reloadOneDash(with dashIndex: Int) {
        NSLog("🎛️ feeds reloadOneDash(with: \(dashIndex))")
        
        let previousIndex = appDelegate.feedDetailViewController.dashboardIndex
        
        if previousIndex >= 0, previousIndex < StoryCache.cachedDashboard.count {
            reloadDashboard()
        } else {
            appDelegate.feedDetailViewController.dashboardIndex = dashIndex
            appDelegate.feedDetailViewController.dashboardSingleMode = true
            
            immediatelyLoadNextDash(prepare: false, finishingSingleMode: false)
        }
    }
    
    @objc func loadDashboard() {
        NSLog("🎛️ loadDashboard")
        
        if !appDelegate.detailViewController.storyTitlesInDashboard {
            NSLog("🎛️ ...not showing dashboard")
            return
        } else if appDelegate.feedDetailViewController.dashboardIndex >= 0 {
            NSLog("🎛️ ...deferred loading dashboard")
            
            deferredLoadNextDash()
        } else {
            NSLog("🎛️ ...resetting timer")
            
            let frequency: TimeInterval = 5 * 60
            
            dashboardTimer?.invalidate()
            dashboardTimer = Timer.scheduledTimer(timeInterval: frequency, target: self, selector: #selector(reloadDashboard), userInfo: nil, repeats: true
            )
            
            immediatelyLoadNextDash(prepare: true, finishingSingleMode: false)
        }
    }
    
    var dashWorkItem: DispatchWorkItem?
    
    private func deferredLoadNextDash() {
        NSLog("🎛️ deferredLoadNextDash")
        
        dashWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, isDashboard else {
                return
            }
            
            immediatelyLoadNextDash(prepare: true,
                                    finishingSingleMode: appDelegate.feedDetailViewController.dashboardSingleMode)
        }
        
        let speed = appDelegate.feedDetailViewController.storyCache.settings.dashboardSpeed
        
        dashWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(speed), execute: workItem)
    }
    
    private func immediatelyLoadNextDash(prepare: Bool, finishingSingleMode: Bool) {
        NSLog("🎛️ immediatelyLoadNextDash(prepare: \(prepare), finishingSingleMode: \(finishingSingleMode))")
        
        let previousIndex = appDelegate.feedDetailViewController.dashboardIndex
        
        if previousIndex >= 0, previousIndex < StoryCache.cachedDashboard.count {
            if finishingSingleMode || !appDelegate.feedDetailViewController.dashboardSingleMode {
                appDelegate.feedDetailViewController.storyCache.reloadDashboard(for: previousIndex)
                
                let dash = StoryCache.cachedDashboard[previousIndex]
                dash.isFetching = false
            }
            
            if finishingSingleMode {
                NSLog("🎛️ ...finished loading single dash")
                
                appDelegate.feedDetailViewController.dashboardIndex = StoryCache.cachedDashboard.count
                appDelegate.feedDetailViewController.dashboardSingleMode = false
                
                appDelegate.feedDetailViewController.reload()
                return
            }
        } else {
            appDelegate.feedDetailViewController.dashboardSingleMode = false
        }
        
        if !appDelegate.feedDetailViewController.dashboardSingleMode {
            appDelegate.feedDetailViewController.dashboardIndex += 1
        }
        
        let index = appDelegate.feedDetailViewController.dashboardIndex
        
        if index == 0 {
            if prepare {
                appDelegate.feedDetailViewController.storyCache.prepareDashboard()
            }
        } else if index >= StoryCache.cachedDashboard.count {
            // Done.
            
            NSLog("🎛️ ...finished loading dashboard: \(StoryCache.cachedDashboard)")
            
            appDelegate.feedDetailViewController.reload()
            return
        }
        
        let dash = StoryCache.cachedDashboard[index]
        
        NSLog("🎛️ ...starting to fetch dashboard \(index): \(dash)")
        
        dash.isFetching = true
        
        appDelegate.storiesCollection.reset()
        
        if let searchQuery = dash.searchQuery {
            appDelegate.storiesCollection.inSearch = true
            appDelegate.storiesCollection.searchQuery = searchQuery
            appDelegate.storiesCollection.savedSearchQuery = searchQuery
        } else {
            appDelegate.storiesCollection.inSearch = false
            appDelegate.storiesCollection.searchQuery = nil
            appDelegate.storiesCollection.savedSearchQuery = nil
        }
        
        if let feed = dash.feedId {
            NSLog("🎛️ ...loadFolder \(dash.folderId) feedID: \(feed)")
            
            appDelegate.loadFolder(dash.folderId, feedID: feed)
        } else {
            NSLog("🎛️ loadRiverFeedDetailView \(dash.folderId)")
            
            appDelegate.loadRiverFeedDetailView(appDelegate.feedDetailViewController, withFolder: dash.folderId)
        }
    }
    
    var loadWorkItem: DispatchWorkItem?
    
    @objc func loadNotificationStory() {
        loadWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            
            self.appDelegate.backgroundLoadNotificationStory()
        }
        
        loadWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + (isOffline ? .seconds(1) : .milliseconds(200)), execute: workItem)
    }
    
    var reloadWorkItem: DispatchWorkItem?
    
    @objc func deferredReloadFeedTitlesTable() {
        reloadWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            
            self.reloadFeedTitlesTable()
            self.refreshHeaderCounts()
        }
        
        reloadWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: workItem)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        appearCount += 1
        
        let month: TimeInterval = 60 * 60 * 24 * 30
        let promptedDate = datePromptedForReview
        let currentVersion = appVersion
        let promptedVersion = versionPromptedForReview
        
        // We only get a few prompts per year, so only ask for a review if gone back to the Feeds list several times, it's been at least a month since the last prompt, and it's a different version.
        if appearCount >= 5, -promptedDate.timeIntervalSinceNow > month, currentVersion != promptedVersion, let scene = view.window?.windowScene {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [navigationController] in
                if navigationController?.topViewController is FeedsViewController {
                    SKStoreReviewController.requestReview(in: scene)
                    self.datePromptedForReview = Date()
                    self.versionPromptedForReview = currentVersion
                }
            }
        }
    }
}
