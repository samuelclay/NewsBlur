//
//  SceneDelegate.swift
//  NewsBlur
//
//  Created by David Sinclair on 2023-11-15.
//  Copyright © 2023 NewsBlur. All rights reserved.
//

import UIKit
import UserNotifications

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var appDelegate: NewsBlurAppDelegate = .shared
    
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
        // SceneDelegate.swift gives the storyboard window the account language's direction before any view loads.
        if let windowScene = scene as? UIWindowScene {
            NBLocalization.applyDirection(to: windowScene)
        }
        if appDelegate.window != nil {
            handleNotificationResponse(connectionOptions.notificationResponse)
            connectionOptions.urlContexts.forEach { appDelegate.open($0.url) }
            DispatchQueue.main.async {
                self.window?.isHidden = true
                UIApplication.shared.requestSceneSessionDestruction(session, options: .none)
            }
            return
        }
        
        appDelegate.window = window

        if #available(iOS 16.0, *) {
            NewsBlurUITestHarness.prepareLaunchEnvironmentIfNeeded(appDelegate: self.appDelegate)
        }
        
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
        connectionOptions.urlContexts.forEach { appDelegate.open($0.url) }
        handleNotificationResponse(connectionOptions.notificationResponse)

        if #available(iOS 16.0, *) {
            Task { @MainActor in
                NewsBlurUITestHarness.configureIfNeeded(appDelegate: self.appDelegate)
            }
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        appDelegate.resumeFeedSubscription()
    }

    private func handleNotificationResponse(_ response: UNNotificationResponse?) {
        guard let response else { return }

        // SceneDelegate.swift receives notification launches that do not reach the legacy app launch options.
        appDelegate.processNotification(response.notification.request.content.userInfo,
                                        action: response.actionIdentifier,
                                        withCompletionHandler: nil)
    }
    
#if targetEnvironment(macCatalyst)
    func sceneDidDisconnect(_ scene: UIScene) {
        // SceneDelegate.swift releases only this scene's reader, allowing Dock activation to reconnect it.
        // Closing a window keeps the process running; the system Quit command owns app termination.
        if appDelegate.window === window {
            appDelegate.window = nil
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
