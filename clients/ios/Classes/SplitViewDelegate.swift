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
        return .primary
    }
    
    func splitViewController(_ svc: UISplitViewController, displayModeForExpandingToProposedDisplayMode proposedDisplayMode: UISplitViewController.DisplayMode) -> UISplitViewController.DisplayMode {
        if UIDevice.current.userInterfaceIdiom == .phone, proposedDisplayMode == .twoOverSecondary {
            return .oneOverSecondary
        } else {
            return proposedDisplayMode
        }
    }
}
