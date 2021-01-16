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
    /// Preference keys.
    enum Key {
        /// Layout of the story titles and story pages.
        static let layout = "story_titles_position"
        
        /// Position of the divider between the views when in horizontal orientation. Only used for `.top` and `.bottom` layouts.
        static let horizontalPosition = "story_titles_divider_horizontal"
        
        /// Position of the divider between the views when in vertical orientation. Only used for `.top` and `.bottom` layouts.
        static let verticalPosition = "story_titles_divider_vertical"
    }
    
    /// Preference values.
    enum Value {
        static let left = "titles_on_left"
        static let top = "titles_on_top"
        static let bottom = "titles_on_bottom"
    }
    
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
    var layout: Layout {
        get {
            switch UserDefaults.standard.string(forKey: Key.layout) {
            case Value.top:
                return .top
            case Value.bottom:
                return .bottom
            default:
                return .left
            }
        }
        set {
            guard newValue != layout else {
                return
            }
            
            switch newValue {
            case .top:
                UserDefaults.standard.set(Value.top, forKey: Key.layout)
            case .bottom:
                UserDefaults.standard.set(Value.bottom, forKey: Key.layout)
            default:
                UserDefaults.standard.set(Value.left, forKey: Key.layout)
            }
            
            updateLayout(reload: true)
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
    var dividerPosition: CGFloat {
        get {
            let key = isPortraitOrientation ? Key.verticalPosition : Key.horizontalPosition
            let value = CGFloat(UserDefaults.standard.float(forKey: key))
            
            if value == 0 {
                return 200
            } else {
                return value
            }
        }
        set {
            guard newValue != dividerPosition else {
                return
            }
            
            let key = isPortraitOrientation ? Key.verticalPosition : Key.horizontalPosition
            
            UserDefaults.standard.set(Float(newValue), forKey: key)
        }
    }
    
    /// Top container view.
    @IBOutlet weak var topContainerView: UIView!
    
    /// Bottom container view.
    @IBOutlet weak var bottomContainerView: UIView!
    
    /// Top container view top constraint. May need to adjust this for fullscreen on iPhone.
    @IBOutlet weak var topContainerTopConstraint: NSLayoutConstraint!
    
    /// Bottom constraint of the divider view.
    @IBOutlet weak var dividerViewBottomConstraint: NSLayoutConstraint!
    
    /// The feed detail navigation controller in the supplementary pane, loaded from the storyboard.
    var supplementaryFeedDetailNavigationController: UINavigationController?
    
    /// The feed detail view controller in the supplementary pane, loaded from the storyboard.
    var supplementaryFeedDetailViewController: FeedDetailViewController?
    
    /// The feed detail view controller, if using `top` or `bottom` layout. `nil` if using `left` layout.
    var feedDetailViewController: FeedDetailViewController?
    
    /// The horizontal page view controller.
    var horizontalPageViewController: HorizontalPageViewController?
    
    /// Enable paging upwards and/or downwards.
    ///
    /// - Parameter up: Allow paging up to the previous story.
    /// - Parameter down: Allow paging down to the next story.
    @objc(allowPagingUp:down:) func allowPaging(up: Bool, down: Bool) {
        horizontalPageViewController?.currentController?.allowPaging(up: up, down: down)
    }
    
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
        
//        navigationItem.titleView = nil
    }
    
    /// Resets the page controllers to a blank state.
    @objc func resetPageControllers() {
        if let viewController = Storyboards.shared.controller(withIdentifier: .verticalPages) as? VerticalPageViewController {
            viewController.horizontalPageViewController = horizontalPageViewController
            viewController.currentController = makeStoryController(for: -2)
            
            print("DetailViewController setViewControllers: \(String(describing: viewController))")
            
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
    
    /// Updates the layout; call this when the layout is changed in the preferences.
    @objc(updateLayoutWithReload:) func updateLayout(reload: Bool) {
        checkViewControllers()
        
        appDelegate.feedsViewController.loadOfflineFeeds(false)
    }
    
    @objc func adjustForAutoscroll() {
        if UIDevice.current.userInterfaceIdiom == .phone, !isNavigationBarHidden {
            topContainerTopConstraint.constant = -44
        } else {
            topContainerTopConstraint.constant = 0
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateLayout(reload: false)
        resetPageControllers()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        if layout != .left {
            coordinator.animate { context in
                self.dividerViewBottomConstraint.constant = self.dividerPosition
            }
        }
    }
    
    private var isDraggingDivider = false
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        
        guard let point = touch?.location(in: view) else {
            return
        }
        
        let isInside = dividerView.frame.contains(point)
        
        guard touch?.view == dividerView || isInside || isDraggingDivider else {
            return
        }
        
        isDraggingDivider = true
        
        let position = view.frame.height - point.y - 6
        
        guard position > 150, position < view.frame.height - 200 else {
            return
        }
        
        dividerPosition = position
        dividerViewBottomConstraint.constant = position
        view.setNeedsLayout()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDraggingDivider = false
        
        //TODO: see if I need anything from adjustFeedDetailScreenForStoryTitles
    }
}

private extension DetailViewController {
    func checkViewControllers() {
        let isTop = layout == .top
        
        if layout == .left {
            if feedDetailViewController != nil {
                remove(viewController: feedDetailViewController)
                
                feedDetailViewController = nil
                appDelegate.feedDetailViewController = supplementaryFeedDetailViewController
                appDelegate.splitViewController.setViewController(supplementaryFeedDetailNavigationController, for: .supplementary)
                supplementaryFeedDetailNavigationController = nil
                supplementaryFeedDetailViewController = nil
            }
            
            dividerViewBottomConstraint.constant = -13
        } else {
            if feedDetailViewController == nil {
                feedDetailViewController = Storyboards.shared.controller(withIdentifier: .feedDetail) as? FeedDetailViewController
                
                add(viewController: feedDetailViewController, top: isTop)
                
                supplementaryFeedDetailNavigationController = appDelegate.feedDetailNavigationController
                supplementaryFeedDetailViewController = appDelegate.feedDetailViewController
                appDelegate.feedDetailViewController = feedDetailViewController
                appDelegate.splitViewController.setViewController(nil, for: .supplementary)
            } else {
                let appropriateSuperview = isTop ? topContainerView : bottomContainerView
                
                if feedDetailViewController?.view.superview != appropriateSuperview {
                    add(viewController: feedDetailViewController, top: isTop)
                }
            }
            
            dividerViewBottomConstraint.constant = dividerPosition
        }
        
        if horizontalPageViewController == nil {
            horizontalPageViewController = Storyboards.shared.controller(withIdentifier: .horizontalPages) as? HorizontalPageViewController
            
            horizontalPageViewController?.detailViewController = self
        }
        
        let appropriateSuperview = isTop ? bottomContainerView : topContainerView
        
        if horizontalPageViewController?.view.superview != appropriateSuperview {
            add(viewController: horizontalPageViewController, top: !isTop)
            
            adjustForAutoscroll()
            
            if isTop {
                bottomContainerView.addSubview(traverseView)
                bottomContainerView.addSubview(autoscrollView)
            } else {
                topContainerView.addSubview(traverseView)
                topContainerView.addSubview(autoscrollView)
            }
        }
        
        traverseTopContainerBottomConstraint.isActive = !isTop
        traverseBottomContainerBottomConstraint.isActive = isTop
        autoscrollTopContainerBottomConstraint.isActive = !isTop
        autoscrollBottomContainerBottomConstraint.isActive = isTop
    }
    
    func add(viewController: UIViewController?, top: Bool) {
        if top {
            add(viewController: viewController, to: topContainerView)
        } else {
            add(viewController: viewController, to: bottomContainerView)
        }
    }
    
    func add(viewController: UIViewController?, to containerView: UIView) {
        guard let viewController = viewController else {
            return
        }
        
        addChild(viewController)
        
        containerView.addSubview(viewController.view)
        
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
        viewController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
        viewController.view.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
        viewController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true
        
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
