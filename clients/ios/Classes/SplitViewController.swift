//
//  SplitViewController.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-08-27.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit

/// Subclass of `UISplitViewController` to enable customizations.
class SplitViewController: UISplitViewController {
    @objc var isFeedListHidden: Bool {
        return [.oneBesideSecondary, .oneOverSecondary, .secondaryOnly].contains(displayMode)
    }
    
    /// Update the theme of the split view controller.
    @objc func updateTheme() {
        
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        print("preferredStatusBarStyle: \(ThemeManager.shared.isDarkTheme ? "light" : "dark")")
        
        return ThemeManager.shared.isDarkTheme ? .lightContent : .darkContent
    }
    
    override var childForStatusBarStyle: UIViewController? {
        return nil
    }
    
    // Can do menu validation here.
//    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
//        print("canPerformAction: \(action) with \(sender ?? "nil")")
//        return true
//    }
}
