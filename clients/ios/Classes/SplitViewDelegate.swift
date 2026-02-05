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
        
        detailController.collapseToSingleColumn()
        
        return .primary
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
            default:
                NSLog("split will change to an unexpected mode")
        }

        NewsBlurAppDelegate.shared?.feedsViewController.updateSidebarButton(for: displayMode)
        NewsBlurAppDelegate.shared?.feedDetailViewController.updateSidebarButton(for: displayMode)
    }
}
