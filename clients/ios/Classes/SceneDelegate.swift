//
//  SceneDelegate.swift
//  NewsBlur
//
//  Created by David Sinclair on 2023-11-15.
//  Copyright © 2023 NewsBlur. All rights reserved.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    let appDelegate: NewsBlurAppDelegate = .shared
    
    var window: UIWindow?
#if targetEnvironment(macCatalyst)
    var toolbar = NSToolbar(identifier: "main")
    var toolbarDelegate = ToolbarDelegate()
#endif
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        appDelegate.window = window
        
#if targetEnvironment(macCatalyst)
        guard let windowScene = scene as? UIWindowScene, let titlebar = windowScene.titlebar else {
            return
        }
        
        toolbar.delegate = toolbarDelegate
        toolbar.displayMode = .iconOnly
        
        titlebar.toolbar = toolbar
        titlebar.toolbarStyle = .automatic
        
#endif
        appDelegate.prepareViewControllers()
    }
}
