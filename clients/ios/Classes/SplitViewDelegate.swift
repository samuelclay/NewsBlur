//
//  SplitViewDelegate.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-08-27.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit

/// Split view delegate.
class SplitViewDelegate: NSObject, UISplitViewControllerDelegate {
    
    func splitViewController(_ svc: UISplitViewController, topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
        if UIDevice.current.userInterfaceIdiom == .phone {
            if let navController = svc.viewController(for: .secondary) as? UINavigationController, let detailController = navController.viewControllers[0] as? DetailViewController, let storyController = detailController.currentStoryController, storyController.hasStory {
                return .secondary
            } else {
                return .primary
            }
        } else {
            return .primary
        }
    }
    
    func splitViewController(_ svc: UISplitViewController, displayModeForExpandingToProposedDisplayMode proposedDisplayMode: UISplitViewController.DisplayMode) -> UISplitViewController.DisplayMode {
        if let supplementaryNav = svc.viewController(for: .supplementary) as? UINavigationController,
           supplementaryNav.viewControllers.isEmpty,
           let primaryNav = svc.viewController(for: .primary) as? UINavigationController,
           let feedsList = primaryNav.viewControllers[0] as? FeedsViewController {
            if primaryNav.viewControllers.count > 1,
               let feedDetail = primaryNav.viewControllers[1] as? FeedDetailViewController {
                supplementaryNav.viewControllers = [feedDetail]
            } else if let feedDetail = feedsList.appDelegate.feedDetailViewController {
                supplementaryNav.viewControllers = [feedDetail]
            }
        }
        
        if UIDevice.current.userInterfaceIdiom == .phone, proposedDisplayMode == .twoOverSecondary {
            return .oneOverSecondary
        } else {
            return proposedDisplayMode
        }
    }
}
