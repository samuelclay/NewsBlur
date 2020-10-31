//
//  StoryDetailViewController.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-08-27.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit

/// An individual story.
class StoryDetailViewController: StoryDetailObjCViewController {
    /// Convenience initializer to load a new instance of this class from the XIB.
    ///
    /// - Parameter pageIndex: The page index of the story.
    convenience init(pageIndex: Int) {
        self.init(nibName: "StoryDetailViewController", bundle: nil)
        
        self.appDelegate = NewsBlurAppDelegate.shared()
        self.pageIndex = pageIndex
    }
}
