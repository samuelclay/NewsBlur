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
    
    /// Whether or not the feed detail is on the left; see also the following property.
    @objc var storyTitlesOnLeft: Bool {
        return layout == .left
    }
    
    /// Whether or not the feed detail is on the top; see also the previous property.
    @objc var storyTitlesOnTop: Bool {
        return layout == .top
    }
    
    /// Position of the divider between the views.
    var splitPosition: CGFloat = 200  //TODO: set this based on prefs
    
    /// The feed detail view controller, if using `top` or `bottom` layout. `nil` if using `left` layout.
    var feedDetailViewController: FeedDetailViewController?
    
    /// The horizontal page view controller.
    var horizontalPageViewController: HorizontalPageViewController?
    
    /// Returns the currently displayed story view controller, or `nil` if none.
    @objc var currentStoryController: StoryDetailViewController? {
        return horizontalPageViewController?.currentController?.currentController
    }
    
    /// Returns an array of all existing story view controllers.
    @objc var storyControllers: [StoryDetailViewController] {
        var controllers = [StoryDetailViewController]()
        
        guard let pageViewController = horizontalPageViewController else {
            return controllers
        }
        
        addStories(from: pageViewController.previousController, to: &controllers)
        addStories(from: pageViewController.currentController, to: &controllers)
        addStories(from: pageViewController.nextController, to: &controllers)
        
        return controllers
    }
    
    /// Returns an array of the previous, current, and next vertical page view controllers, each with the previous, current, and next story view controllers. Note that the top-level array will always have three values, but the inner arrays may have 0-3, depending on usage. This is mainly for debugging use.
    @objc var storyControllersMatrix: [[StoryDetailViewController]] {
        guard let pageViewController = horizontalPageViewController else {
            return [[]]
        }
        
        var previousVerticalControllers = [StoryDetailViewController]()
        var currentVerticalControllers = [StoryDetailViewController]()
        var nextVerticalControllers = [StoryDetailViewController]()
        
        addStories(from: pageViewController.previousController, to: &previousVerticalControllers)
        addStories(from: pageViewController.currentController, to: &currentVerticalControllers)
        addStories(from: pageViewController.nextController, to: &nextVerticalControllers)
        
        return [previousVerticalControllers, currentVerticalControllers, nextVerticalControllers]
    }
    
    /// Calls a closure for each story view controller.
    ///
    /// - Parameter handler: The closure to call; it takes a story controller as a parameter.
    @objc(updateStoryControllers:) func updateStoryControllers(handler:(StoryDetailViewController) -> Void) {
        for controller in storyControllers {
            handler(controller)
        }
    }
    
    /// Resets all of the other story controllers from the current one.
    @objc func resetOtherStoryControllers() {
        horizontalPageViewController?.currentController = horizontalPageViewController?.currentController
        
        navigationItem.titleView = nil
    }
    
    /// Resets the page controllers to a blank state.
    @objc func resetPageControllers() {
        if let viewController = Storyboards.shared.controller(withIdentifier: .verticalPages) as? VerticalPageViewController {
            viewController.horizontalPageViewController = horizontalPageViewController
            viewController.currentController = makeStoryController(for: -2)
            
            horizontalPageViewController?.setViewControllers([viewController], direction: .forward, animated: false, completion: nil)
        }
    }
    
    /// Creates a new story view controller for the specified page index, and starts loading the content.
    ///
    /// - Parameter pageIndex: The index of the story page.
    /// - Returns: A new `StoryDetailViewController` instance.
    func makeStoryController(for pageIndex: Int) -> StoryDetailViewController? {
        let storyController = StoryDetailViewController(pageIndex: pageIndex)
        
        applyNewIndex(pageIndex, pageController: storyController)
        
        return storyController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateLayout()
        resetPageControllers()
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
        
        //TODO: *** TO BE IMPLEMENTED ***: will want to use slightly different constraints for top & bottom layouts
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        viewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        viewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        viewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        
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
    
    func addStories(from verticalPageController: VerticalPageViewController?, to controllers: inout [StoryDetailViewController]) {
        guard let verticalPageController = verticalPageController else {
            return
        }
        
        addStory(verticalPageController.previousController, to: &controllers)
        addStory(verticalPageController.currentController, to: &controllers)
        addStory(verticalPageController.nextController, to: &controllers)
    }
    
    func addStory(_ story: StoryDetailViewController?, to controllers: inout [StoryDetailViewController]) {
        if let story = story {
            controllers.append(story)
        }
    }
}
