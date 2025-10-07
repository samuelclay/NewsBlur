//
//  Storyboards.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-09-24.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit

/// Singleton to manage the storyboards of the app.
class Storyboards {
    /// Singleton shared instance.
    static let shared = Storyboards()
    
    /// Private init to prevent others constructing a new instance.
    private init() {
    }
    
    /// Main storyboard identifiers.
    enum Main: String {
        case feedDetail = "FeedDetailViewController"
        case horizontalPages = "HorizontalPageViewController"
        case verticalPages = "VerticalPageViewController"
//        case storyDetail = "StoryDetailViewController" // loading from XIB currently
    }
    
    /// Storyboard names.
    private struct Name {
        static let main = "MainInterface"
    }
    
    /// The storyboard for the main view controllers.
    private lazy var mainStoryboard: UIStoryboard = {
        return UIStoryboard(name: Name.main, bundle: nil)
    }()
    
    /// Returns a view controller loaded from the main storyboard, or `nil` if it couldn't be found.
    ///
    /// - Parameter identifier: The identifier of the controller.
    /// - Returns: The instantiated view controller, or `nil`.
    func controller(withIdentifier identifier: Main) -> Any? {
        return mainStoryboard.instantiateViewController(withIdentifier: identifier.rawValue)
    }
}
