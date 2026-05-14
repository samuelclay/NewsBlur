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
        guard let detailNavController = svc.viewController(for: .secondary) as? UINavigationController,
              let detailController = detailNavController.viewControllers[0] as? DetailViewController else {
            return .primary
        }

        let hasFeed = detailController.isFeedShown
        let hasStory = detailController.hasVisibleStoryForSidebarLayout || detailController.isStoryShown
        let topColumn = SplitCollapseColumnDecision.topColumn(
            hasFeed: hasFeed,
            hasStory: hasStory,
            proposedTopColumn: splitCollapseTopColumn(for: proposedTopColumn)
        )
        
        detailController.collapseToSingleColumn()

        let restoreCompactNavigation = {
            detailController.restoreCompactNavigationAfterSplitCollapse(showFeed: hasFeed, showStory: hasStory)
        }
        if let transitionCoordinator = svc.transitionCoordinator {
            transitionCoordinator.animate(alongsideTransition: nil) { _ in
                restoreCompactNavigation()
            }
        } else {
            DispatchQueue.main.async(execute: restoreCompactNavigation)
        }
        
        return uiSplitViewColumn(for: topColumn)
    }
    
    func splitViewController(_ svc: UISplitViewController, displayModeForExpandingToProposedDisplayMode proposedDisplayMode: UISplitViewController.DisplayMode) -> UISplitViewController.DisplayMode {
        guard let detailNavController = svc.viewController(for: .secondary) as? UINavigationController,
              let detailController = detailNavController.viewControllers[0] as? DetailViewController else {
            return proposedDisplayMode
        }
        
        detailController.expandToTwoColumns()
        
        return proposedDisplayMode
    }
    
    func splitViewController(_ svc: UISplitViewController, willChangeTo displayMode: UISplitViewController.DisplayMode) {
        switch displayMode {
            case .automatic:
                NSLog("split will change to automatic")
            case .secondaryOnly:
                NSLog("split will change to secondary only")
            case .oneBesideSecondary:
                NSLog("split will change to one beside secondary")
            case .oneOverSecondary:
                NSLog("split will change to one over secondary")
            case .twoBesideSecondary:
                NSLog("split will change to two beside secondary")
            case .twoOverSecondary:
                NSLog("split will change to two over secondary")
            case .twoDisplaceSecondary:
                NSLog("split will change to two displace secondary")
            default:
                NSLog("split will change to an unexpected mode")
        }

        // If display mode changed away from secondaryOnly while temporary fullscreen is active,
        // something external (e.g. Mac sidebar toggle) changed the mode, so exit temporary fullscreen.
        if let detail = NewsBlurAppDelegate.shared?.detailViewController,
           detail.isTemporaryFullScreen,
           displayMode != .secondaryOnly {
            detail.resetTemporaryFullScreenIfNeeded()
        }

        NewsBlurAppDelegate.shared?.detailViewController.syncFullscreenSidebarPresentation(for: displayMode)
        NewsBlurAppDelegate.shared?.feedsViewController.updateSidebarButton(for: displayMode)
        NewsBlurAppDelegate.shared?.feedDetailViewController.updateSidebarButton(for: displayMode)
    }

    private func splitCollapseTopColumn(for column: UISplitViewController.Column) -> SplitCollapseTopColumn {
        switch column {
        case .secondary:
            return .secondary
        default:
            return .primary
        }
    }

    private func uiSplitViewColumn(for column: SplitCollapseTopColumn) -> UISplitViewController.Column {
        switch column {
        case .secondary:
            return .secondary
        case .primary:
            return .primary
        }
    }
}
