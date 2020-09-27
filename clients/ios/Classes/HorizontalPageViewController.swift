//
//  HorizontalPageViewController.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-08-27.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit

/// Manages horizontal story pages. An instance of this is contained within `DetailViewController`.
class HorizontalPageViewController: UIPageViewController {
    /// Weak reference to owning detail view controller.
    weak var detailViewController: DetailViewController?
}
