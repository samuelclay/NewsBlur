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
    
    /// The currently displayed vertical page view controller. Call `setCurrentController(_:direction:animated:completion:)` instead to animate to the page. Shouldn't be `nil`, but could be if not set up yet.
    var currentController: VerticalPageViewController? {
        get {
            return viewControllers?.first as? VerticalPageViewController
        }
        set {
            if let viewController = newValue {
                setCurrentController(viewController)
            }
        }
    }
    
    /// The previous vertical page view controller, if it has been requested, otherwise `nil`.
    var previousController: VerticalPageViewController?
    
    /// The next vertical page view controller, if it has been requested, otherwise `nil`.
    var nextController: VerticalPageViewController?
    
    /// Clear the previous and next vertical page view controllers.
    func reset() {
        previousController = nil
        nextController = nil
    }
    
    /// Sets the currently displayed vertical page view controller.
    ///
    /// - Parameter controller: The vertical page view controller to display.
    /// - Parameter direction: The navigation direction. Defaults to `.forward`.
    /// - Parameter animated: Whether or not to animate it. Defaults to `false`.
    /// - Parameter completion: A closure to call when the animation completes. Defaults to `nil`.
    func setCurrentController(_ controller: VerticalPageViewController, direction: UIPageViewController.NavigationDirection = .forward, animated: Bool = false, completion: ((Bool) -> Void)? = nil) {
        setViewControllers([controller], direction: direction, animated: animated, completion: completion)
    }
    
    override func setViewControllers(_ viewControllers: [UIViewController]?, direction: UIPageViewController.NavigationDirection, animated: Bool, completion: ((Bool) -> Void)? = nil) {
        reset()
        
        super.setViewControllers(viewControllers, direction: direction, animated: animated, completion: completion)
    }
}
