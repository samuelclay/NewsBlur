//
//  StoryPagesViewController.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-08-27.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit

/// Manages story pages, containing the previous, current, and next stories.
class StoryPagesViewController: StoryPagesObjCViewController {
    /// Convenience initializer to load a new instance of this class from the XIB.
    convenience init() {
        self.init(nibName: "StoryPagesViewController", bundle: nil)
        
        self.appDelegate = NewsBlurAppDelegate.shared()
    }
}
