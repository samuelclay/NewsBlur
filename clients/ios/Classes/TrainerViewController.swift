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
    
    lazy var hostingController = makeHostingController()
    
    var trainerView: TrainerView {
        return hostingController.rootView
    }
    
    var storyCache: StoryCache {
        return appDelegate.feedDetailViewController.storyCache
    }
    
    private func makeHostingController() -> UIHostingController<TrainerView> {
        let trainerView = TrainerView(interaction: self, cache: storyCache)
        let trainerController = UIHostingController(rootView: trainerView)
        trainerController.view.translatesAutoresizingMaskIntoConstraints = false
        
        return trainerController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
//        changedLayout()
    }
    
    @objc func reload() {
        trainerView.reload()
    }
}

extension TrainerViewController: TrainerInteraction {
    //TODO: 🚧
}
