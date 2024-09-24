//
//  AppDelegateHelper.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-07-29.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import UIKit

/// Singleton class to provide Swift functions to the app delegate. Can't make `NewsBlurAppDelegate` Swift code, or inherit from Swift code, due to circular references.
class AppDelegateHelper: NSObject {
    /// Singleton shared instance.
    @MainActor @objc static let shared = AppDelegateHelper()
    
    /// Private init to prevent others constructing a new instance.
    private override init() {
    }
    
    @objc func upgradeSettings(from release: Int) {
        if release < 154 {
            upgradeFeedScrollSettings()
        }
    }
    
    func upgradeFeedScrollSettings() {
        let settings = UserDefaults.standard
        let isScroll = settings.bool(forKey: "default_scroll_read_filter")
        let isOverride = settings.bool(forKey: "override_scroll_read_filter")
        
        settings.set(isScroll ? "scroll" : "selection", forKey: "default_mark_read_filter")
        settings.set(isOverride, forKey: "override_mark_read_filter")
        
        let dictionary = settings.dictionaryRepresentation()
        let scrollSettings = dictionary.filter { $0.key.hasSuffix(":scroll_read_filter") }
        let dropLength = ":scroll_read_filter".count
        
        for (key, value) in scrollSettings {
            let newKey = "\(key.dropLast(dropLength)):mark_read_filter"
            let isScroll = value as? Bool ?? false
            
            settings.set(isScroll ? "scroll" : "selection", forKey: newKey)
        }
    }
}
