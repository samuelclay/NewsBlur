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
    private var pendingWindowWidening = false
    private var requestedRestorationFrame: CGRect?
    private var nativeRestoredWindowFrame: CGRect?
    private var observesNativeRestoration = false
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
            if !observesNativeRestoration {
                NotificationCenter.default.addObserver(self, selector: #selector(nativeWindowsDidFinishRestoring(_:)),
                                                       name: MacReaderChrome.didFinishRestoringWindows, object: nil)
                observesNativeRestoration = true
            }
            MacReaderChrome.prepareDefaults()
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
        titlebar.toolbarStyle = .unified
#endif
        
        appDelegate.prepareViewControllers()
#if targetEnvironment(macCatalyst)
        appDelegate.splitViewController.installMacReaderChrome()
        MacReaderChrome.updateTheme()
#endif
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
#if targetEnvironment(macCatalyst)
        if let windowScene = scene as? UIWindowScene { restoreWindowFrame(in: windowScene) }
        MacReaderChrome.updateTheme()
#endif
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

    func macUsableDisplayFrame(for frame: CGRect) -> CGRect? {
        MacReaderChrome.usableDisplayFrame(for: frame)
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
        let defaults = UserDefaults.standard
        let initialFrame = macWindowFrame(in: scene)
        let savedFrame = defaults.string(forKey: "mac_main_window_frame").map { NSCoder.cgRect(for: $0) }
        let validSavedFrame = savedFrame.flatMap { isUsableWindowFrame($0) ? $0 : nil }
        var frame = validSavedFrame ?? initialFrame
        guard isUsableWindowFrame(frame) else { return }
        didRestoreWindowFrame = true

        if !defaults.bool(forKey: "mac_wide_reader_window_v1"), !macWindowIsFullScreen(in: scene),
           let visible = macUsableDisplayFrame(for: frame), isUsableWindowFrame(visible) {
            // SceneDelegate.swift combines widening and restoration in one geometry request instead of racing a separate native resize.
            frame.size.width = min(frame.width + 250, visible.width)
            frame.origin.x = max(visible.minX, min(frame.minX, visible.maxX - frame.width))
            pendingWindowWidening = true
        }
        guard validSavedFrame != nil || pendingWindowWidening else { return }
        requestedRestorationFrame = frame
        applyRestoredWindowFrame(frame, in: scene)
    }

    @objc private func nativeWindowsDidFinishRestoring(_ notification: Notification) {
        guard let scene = connectedWindowScene, isMainWindowScene(scene) else { return }
        if requestedRestorationFrame == nil { restoreWindowFrame(in: scene) }
        guard requestedRestorationFrame != nil,
              let nativeFrame = (notification.userInfo?["systemFrame"] as? NSValue)?.cgRectValue,
              isUsableWindowFrame(nativeFrame) else { return }
        nativeRestoredWindowFrame = nativeFrame
        reconcileNativeWindowRestoration(in: scene)
    }

    private func reconcileNativeWindowRestoration(in scene: UIWindowScene) {
        // SceneDelegate.swift waits for UIKit to receive AppKit's actual restored frame, which can arrive after native completion.
        guard isMainWindowScene(scene), let frame = requestedRestorationFrame,
              let nativeFrame = nativeRestoredWindowFrame, macWindowFrame(in: scene) == nativeFrame else { return }
        requestedRestorationFrame = nil
        nativeRestoredWindowFrame = nil
        // SceneDelegate.swift reconciles UIKit's requested frame after AppKit applies its separately saved native window state.
        if macWindowFrame(in: scene) != frame { applyRestoredWindowFrame(frame, in: scene) }
    }

    private func applyRestoredWindowFrame(_ frame: CGRect, in scene: UIWindowScene) {
        let initialFrame = macWindowFrame(in: scene)
        frameBeforeRestoration = initialFrame == frame ? nil : initialFrame
        requestMacWindowFrame(frame, in: scene) { [weak self] error in
            self?.frameBeforeRestoration = nil
            self?.pendingWindowWidening = false
            self?.requestedRestorationFrame = nil
            self?.nativeRestoredWindowFrame = nil
            NSLog("Unable to restore NewsBlur window frame: %@", error.localizedDescription)
        }
        if initialFrame == frame { saveWindowFrame(for: scene) }
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
        if pendingWindowWidening {
            // SceneDelegate.swift completes the migration only after the system reports its resulting frame.
            UserDefaults.standard.set(true, forKey: "mac_wide_reader_window_v1")
            pendingWindowWidening = false
        }
    }

    func windowScene(_ windowScene: UIWindowScene, didUpdateEffectiveGeometry previousEffectiveGeometry: UIWindowScene.Geometry) {
        reconcileNativeWindowRestoration(in: windowScene)
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
            pendingWindowWidening = false
            requestedRestorationFrame = nil
            nativeRestoredWindowFrame = nil
            NotificationCenter.default.removeObserver(self, name: MacReaderChrome.didFinishRestoringWindows, object: nil)
            observesNativeRestoration = false
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
