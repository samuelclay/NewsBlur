//
//  VerticalPageViewController.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-09-24.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit

/// Manages vertical story pages. Instances of this are contained within `HorizontalPageViewController`.
class VerticalPageViewController: UIPageViewController {
    /// Weak reference to owning horizontal page view controller.
    weak var horizontalPageViewController: HorizontalPageViewController?
    
    /// Weak computed reference to owning detail view controller.
    weak var detailViewController: DetailViewController? {
        return horizontalPageViewController?.detailViewController
    }
}
