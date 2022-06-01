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
    
    var loadWorkItem: DispatchWorkItem?
    
    @objc func loadNotificationStory() {
        loadWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else {
                return
            }
            
            self.appDelegate.backgroundLoadNotificationStory()
        }
        
        loadWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + (isOffline ? .seconds(1) : .milliseconds(100)), execute: workItem)
    }
    
    var reloadWorkItem: DispatchWorkItem?
    
    @objc func deferredUpdateFeedTitlesTable() {
        reloadWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else {
                return
            }
            
            self.updateFeedTitlesTable()
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
