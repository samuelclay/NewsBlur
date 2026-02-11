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
    @objc var isFeedsListHidden: Bool {
        return [.oneOverSecondary, .secondaryOnly].contains(displayMode)
    }
    
    /// Update the theme of the split view controller.
    @objc func updateTheme() {
        headerView.backgroundColor = ThemeManager.color(fromRGB: [0xE3E6E0, 0xF3E2CB, 0x333333, 0x222222])
        setNeedsStatusBarAppearanceUpdate()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
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
   
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { _ in
            NewsBlurAppDelegate.shared?.updateSplitBehavior(false)
        })
    }

    // Can do menu validation here.
//    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
//        print("canPerformAction: \(action) with \(sender ?? "nil")")
//        return true
//    }
}
