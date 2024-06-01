//
//  AuxSceneDelegate.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-05-30.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import UIKit

/// Scene delegate for auxiliary windows. Currently only used on macOS.
class AuxSceneDelegate: UIResponder, UIWindowSceneDelegate {
    let appDelegate: NewsBlurAppDelegate = .shared
    
    var window: UIWindow?
#if targetEnvironment(macCatalyst)
    var toolbar = NSToolbar(identifier: "aux")
    var toolbarDelegate = ToolbarDelegate()
#endif
    
    /// Open a new window with an `OriginalStoryViewController` for the given URL.
    @objc(openWindowForURL:customTitle:) class func openWindow(for url: URL, customTitle: String) {
        let activity = NSUserActivity(activityType: "aux")
        
        activity.userInfo = ["url" : url, "title" : customTitle]
        
        if #available(iOS 17.0, *) {
            let request = UISceneSessionActivationRequest(userActivity: activity)
            
            UIApplication.shared.activateSceneSession(for: request) { error in
                print("Error activating scene: \(error)")
            }
        } else {
            UIApplication.shared.requestSceneSessionActivation(nil, userActivity: activity, options: nil) { error in
                print("Error activating scene: \(error)")
            }
        }
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
#if targetEnvironment(macCatalyst)
        guard let windowScene = scene as? UIWindowScene, //let titlebar = windowScene.titlebar,
        let userInfo = connectionOptions.userActivities.first?.userInfo else {
            return
        }
        
        let url = userInfo["url"] as? URL
        let title = userInfo["title"] as? String
        
        let controller = OriginalStoryViewController()
        
        windowScene.title = "Loading…"
        window?.rootViewController = controller
        
        appDelegate.activeOriginalStoryURL = url
        
        controller.customPageTitle = title
        _ = controller.view
        controller.loadInitialStory()
        
        //TODO: 🚧 perhaps make a toolbar for this window
//        toolbar.delegate = toolbarDelegate
//        toolbar.displayMode = .iconOnly
//        
//        titlebar.toolbar = toolbar
//        titlebar.toolbarStyle = .automatic
        
#endif
    }
}
