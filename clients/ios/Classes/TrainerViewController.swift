//
//  TrainerViewController.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-04-01.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import SwiftUI

@objc class TrainerViewController: BaseViewController {
    @objc var isStoryTrainer = false
    
    @objc var isFeedLoaded = false

    private struct RetainedStoryContext {
        let storyHash: String
        let feedID: String
        let account: String?
        let host: String?
        let classifiers: AnyDictionary
    }

    private var retainedStoryContext: RetainedStoryContext?
    private var retainedStoryCache: StoryCache?
    
    lazy var hostingController = makeHostingController()
    
    var trainerView: TrainerView {
        return hostingController.rootView
    }
    
    var storyCache: StoryCache {
        guard isStoryTrainer else { return appDelegate.feedDetailViewController.storyCache }
        if let retainedStoryCache { return retainedStoryCache }
        let cache = StoryCache()
        retainedStoryCache = cache
        return cache
    }

    @objc func captureRetainedStoryContext() {
        guard let story = appDelegate.activeStory,
              let hash = story["story_hash"] as? String,
              let rawFeedID = story["story_feed_id"],
              let feedID = appDelegate.feedIdWithoutSearchQuery("\(rawFeedID)") else {
            retainedStoryContext = nil
            return
        }

        if let context = retainedStoryContext,
           context.storyHash != hash || context.feedID != feedID ||
            context.account != appDelegate.activeUsername || context.host != appDelegate.url {
            retainedStoryContext = nil
        }
        guard let classifiers = appDelegate.storiesCollection.activeClassifiers[feedID] as? AnyDictionary else { return }
        // TrainerViewController.swift captures only the article retained when fullscreen source browsing begins.
        retainedStoryContext = RetainedStoryContext(storyHash: hash, feedID: feedID,
                                                    account: appDelegate.activeUsername, host: appDelegate.url,
                                                    classifiers: NSDictionary(dictionary: classifiers, copyItems: true) as! AnyDictionary)
    }

    @objc func resetForAccountChange() {
        retainedStoryContext = nil
        retainedStoryCache?.reloadForTraining(story: nil)
    }

    private func restoreRetainedStoryClassifiers() {
        captureRetainedStoryContext()
        guard let context = retainedStoryContext,
              appDelegate.storiesCollection.activeClassifiers[context.feedID] == nil else { return }
        // NewsBlurAppDelegate.m's classifier actions read and update this feed-keyed map; preserve every browsed-feed entry.
        appDelegate.storiesCollection.activeClassifiers[context.feedID] = context.classifiers
    }
    
    private func makeHostingController() -> UIHostingController<TrainerView> {
        let trainerView = TrainerView(interaction: self, cache: storyCache)
        let trainerController = UIHostingController(rootView: trainerView)
        trainerController.view.translatesAutoresizingMaskIntoConstraints = false
        
        return trainerController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.backgroundColor = .clear
        hostingController.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
//        changedLayout()
    }
    
    func reloadTrainerContext() {
        if isStoryTrainer {
            restoreRetainedStoryClassifiers()
            storyCache.reloadForTraining(story: appDelegate.activeStory as? AnyDictionary)
        } else {
            storyCache.reload()
        }
    }

    @objc func reload() {
        reloadTrainerContext()
        let freshView = TrainerView(interaction: self, cache: storyCache)
        hostingController.rootView = freshView
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }
}

extension TrainerViewController: TrainerInteraction {
    //TODO: 🚧
}
