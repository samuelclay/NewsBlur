//
//  DetailViewController.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-08-27.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit

/// Manages the detail column of the split view, with the feed detail and/or the story pages.
class DetailViewController: DetailObjCViewController {
    /// How the feed detail and story pages are laid out.
    enum Layout {
        /// The feed detail is to the left of the story pages (and managed by the split view, not here).
        case left
        
        /// The feed detail is at the top, the story pages at the bottom.
        case top
        
        /// The story pages are at the top, the feed detail at the bottom.
        case bottom
    }
    
    /// How the feed detail and story pages are laid out.
    var layout: Layout = .left {  //TODO: set this based on prefs, either here or in the initializer
        didSet {
            updateLayout()
        }
    }
    
    /// Position of the divider between the views.
    var splitPosition: CGFloat = 200  //TODO: set this based on prefs
    
    /// The feed detail view controller, if using `top` or `bottom` layout. `nil` if using `left` layout.
    var feedDetailViewController: FeedDetailViewController?
    
    /// The horizontal page view controller.
    var horizontalPageViewController: HorizontalPageViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateLayout()
        
        if let viewController = Storyboards.shared.controller(withIdentifier: .verticalPages) as? VerticalPageViewController {
            viewController.horizontalPageViewController = horizontalPageViewController
            
            horizontalPageViewController?.setViewControllers([viewController], direction: .forward, animated: false, completion: nil)
        }
    }
}

private extension DetailViewController {
    func updateLayout() {
        checkViewControllers()
        
        //TODO: *** TO BE IMPLEMENTED ***: update the layout
    }
    
    func checkViewControllers() {
        if layout == .left {
            remove(viewController: feedDetailViewController)
            
            feedDetailViewController = nil
        } else {
            if feedDetailViewController == nil {
                feedDetailViewController = Storyboards.shared.controller(withIdentifier: .feedDetail) as? FeedDetailViewController
                
                add(viewController: feedDetailViewController)
            }
        }
        
        if horizontalPageViewController == nil {
            horizontalPageViewController = Storyboards.shared.controller(withIdentifier: .horizontalPages) as? HorizontalPageViewController
            
            horizontalPageViewController?.detailViewController = self
            
            add(viewController: horizontalPageViewController)
        }
    }
    
    func add(viewController: UIViewController?) {
        guard let viewController = viewController else {
            return
        }
        
        addChild(viewController)
//        view.addSubview(viewController.view)
        view.insertSubview(viewController.view, at: 0)
        viewController.didMove(toParent: self)
    }
    
    func remove(viewController: UIViewController?) {
        guard let viewController = viewController else {
            return
        }
        
        viewController.willMove(toParent: nil)
        viewController.removeFromParent()
        viewController.view.removeFromSuperview()
    }
}
