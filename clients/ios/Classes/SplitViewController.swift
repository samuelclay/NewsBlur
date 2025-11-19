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
        headerView.backgroundColor = ThemeManager.color(fromRGB: [0xE3E6E0, 0xFFFFC5, 0x222222, 0x111111])
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        print("preferredStatusBarStyle: \(ThemeManager.shared.isDarkTheme ? "light" : "dark")")
        
        return ThemeManager.shared.isDarkTheme ? .lightContent : .darkContent
    }
    
    override var childForStatusBarStyle: UIViewController? {
        return nil
    }
    
    private let headerView = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        updateTheme()
        
        view.addSubview(headerView)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        ])
    }
   
    // Can do menu validation here.
//    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
//        print("canPerformAction: \(action) with \(sender ?? "nil")")
//        return true
//    }
}
