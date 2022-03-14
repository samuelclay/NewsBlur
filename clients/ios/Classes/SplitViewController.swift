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
}
