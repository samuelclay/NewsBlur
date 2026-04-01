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
    
    @objc(closeAuxWindows) class func closeAuxWindows() {
        for window in UIApplication.shared.windows {
            if window.windowScene?.delegate is AuxSceneDelegate, let session = window.windowScene?.session {
                window.isHidden = true
                UIApplication.shared.requestSceneSessionDestruction(session, options: .none)
            }
        }
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if appDelegate.window != nil {
            DispatchQueue.main.async {
                self.window?.isHidden = true
                UIApplication.shared.requestSceneSessionDestruction(session, options: .none)
            }
            return
        }
        
        appDelegate.window = window
        
#if targetEnvironment(macCatalyst)
        guard let windowScene = scene as? UIWindowScene, let titlebar = windowScene.titlebar else {
            return
        }
        
//        if #available(macCatalyst 16.0, *) {
//            windowScene.windowingBehaviors?.isClosable = false
//        }
        
        toolbar.delegate = toolbarDelegate
        toolbar.displayMode = .iconOnly
        
        titlebar.toolbar = toolbar
        titlebar.toolbarStyle = .automatic
#endif
        
        appDelegate.prepareViewControllers()
    }
    
#if targetEnvironment(macCatalyst)
    func sceneDidDisconnect(_ scene: UIScene) {
        appDelegate.window = nil

        // Scene churn can briefly disconnect one scene while another main scene is activating.
        // Only terminate when there are truly no remaining application window scenes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let appWindowSceneCount = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter { $0.session.role == .windowApplication }
                .count

            guard appWindowSceneCount == 0 else {
                return
            }

            exit(0)
        }
    }
#endif
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else {
            return
        }

        appDelegate.open(url)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        appDelegate.handleUserActivity(userActivity)
    }
}
