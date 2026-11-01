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
    private var didRestoreWindowFrame = false
    private var frameBeforeRestoration: CGRect?
    private weak var connectedWindowScene: UIWindowScene?
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

#if targetEnvironment(macCatalyst)
        if let windowScene = scene as? UIWindowScene {
            connectedWindowScene = windowScene
            restoreWindowFrame(in: windowScene)
        }
#endif

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
#if targetEnvironment(macCatalyst)
        // SceneDelegate.swift replays a response received while Command-W left the process without a reader window.
        // A connection response already navigates through the same handler, so it must not be replayed twice.
        if connectionOptions.notificationResponse == nil,
           appDelegate.pendingNotificationStory != nil || appDelegate.pendingDailyBriefingStoryHash != nil {
            appDelegate.backgroundLoadNotificationStory()
        }
#endif

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
    private func isMainWindowScene(_ scene: UIScene) -> Bool {
        guard let window else { return false }
        return appDelegate.window === window && (window.windowScene === scene || connectedWindowScene === scene)
    }

    // SceneDelegate.swift uses the system frame so both position and size survive new scene sessions.
    func macWindowFrame(in scene: UIWindowScene) -> CGRect {
        scene.effectiveGeometry.systemFrame
    }

    func macWindowIsFullScreen(in scene: UIWindowScene) -> Bool {
        scene.isFullScreen
    }

    func requestMacWindowFrame(_ frame: CGRect, in scene: UIWindowScene, errorHandler: @escaping (Error) -> Void) {
        scene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.Mac(systemFrame: frame), errorHandler: errorHandler)
    }

    private func isUsableWindowFrame(_ frame: CGRect) -> Bool {
        frame.origin.x.isFinite && frame.origin.y.isFinite && frame.size.width.isFinite && frame.size.height.isFinite &&
            frame.size.width > 0 && frame.size.height > 0
    }

    private func restoreWindowFrame(in scene: UIWindowScene) {
        guard isMainWindowScene(scene), !didRestoreWindowFrame else { return }
        didRestoreWindowFrame = true
        guard let saved = UserDefaults.standard.string(forKey: "mac_main_window_frame") else { return }
        let frame = NSCoder.cgRect(for: saved)
        guard isUsableWindowFrame(frame) else { return }
        let initialFrame = macWindowFrame(in: scene)
        frameBeforeRestoration = initialFrame == frame ? nil : initialFrame
        requestMacWindowFrame(frame, in: scene) { [weak self] error in
            self?.frameBeforeRestoration = nil
            NSLog("Unable to restore NewsBlur window frame: %@", error.localizedDescription)
        }
    }

    private func saveWindowFrame(for scene: UIScene) {
        guard isMainWindowScene(scene), let windowScene = scene as? UIWindowScene,
              !macWindowIsFullScreen(in: windowScene) else { return }
        let frame = macWindowFrame(in: windowScene)
        guard isUsableWindowFrame(frame) else { return }
        // SceneDelegate.swift must not replace the saved frame with the startup frame while restoration is pending.
        if frameBeforeRestoration == frame { return }
        frameBeforeRestoration = nil
        UserDefaults.standard.set(NSCoder.string(for: frame), forKey: "mac_main_window_frame")
    }

    func windowScene(_ windowScene: UIWindowScene, didUpdateEffectiveGeometry previousEffectiveGeometry: UIWindowScene.Geometry) {
        saveWindowFrame(for: windowScene)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        saveWindowFrame(for: scene)
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        saveWindowFrame(for: scene)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // SceneDelegate.swift releases only this scene's reader, allowing Dock activation to reconnect it.
        // Closing a window keeps the process running; the system Quit command owns app termination.
        if isMainWindowScene(scene) {
            saveWindowFrame(for: scene)
            appDelegate.window = nil
            didRestoreWindowFrame = false
            frameBeforeRestoration = nil
            connectedWindowScene = nil
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
