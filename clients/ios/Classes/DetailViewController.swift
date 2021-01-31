//
//  DetailViewController.swift
//  NewsBlur
//
//  Created by David Sinclair on 2020-08-27.
//  Copyright © 2020 NewsBlur. All rights reserved.
//

import UIKit

/// Manages the detail column of the split view, with the feed detail and/or the story pages.
class DetailViewController: BaseViewController {
    /// Returns the shared app delegate.
    var appDelegate: NewsBlurAppDelegate {
        return NewsBlurAppDelegate.shared()
    }
    
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
    
    /// Returns `true` if the window is in portrait orientation, otherwise `false`.
    @objc var isPortraitOrientation: Bool {
        return view.window?.windowScene?.interfaceOrientation.isPortrait ?? false
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
    
    /// Draggable divider view.
    @IBOutlet weak var dividerView: UIView!
    
    /// Indicator image in the divider view.
    @IBOutlet weak var dividerImageView: UIImageView!
    
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
    
    /// The horizontal page view controller. [Not currently used; might be used for #1351 (gestures in vertical scrolling).]
//    var horizontalPageViewController: HorizontalPageViewController?
    
    /// The story pages view controller, that manages the previous, current, and next story view controllers.
    var storyPagesViewController: StoryPagesViewController? {
        return appDelegate.storyPagesViewController
    }
    
    /// Returns the currently displayed story view controller, or `nil` if none.
    @objc var currentStoryController: StoryDetailViewController? {
        return storyPagesViewController?.currentPage
    }
    
    /// Updates the layout; call this when the layout is changed in the preferences.
    @objc(updateLayoutWithReload:) func updateLayout(reload: Bool) {
        checkViewControllers()
        
        appDelegate.feedsViewController.loadOfflineFeeds(false)
    }
    
    /// Update the theme.
    @objc override func updateTheme() {
        super.updateTheme()
        
        guard let manager = ThemeManager.shared else {
            return
        }
        
        manager.update(navigationController)
        manager.updateBackground(of: view)
        
        dividerImageView.image = manager.themedImage(UIImage(named: "drag_icon.png"))
        view.backgroundColor = navigationController?.navigationBar.barTintColor;
    }
    
    /// Adjusts the container when autoscrolling. Only applies to iPhone.
    @objc func adjustForAutoscroll() {
        if UIDevice.current.userInterfaceIdiom == .phone, let controller = storyPagesViewController, !controller.isNavigationBarHidden {
            topContainerTopConstraint.constant = -44
        } else {
            topContainerTopConstraint.constant = 0
        }
        
        updateTheme()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateLayout(reload: false)
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
        
        guard let storyPagesViewController = storyPagesViewController else {
            return
        }
        
        let appropriateSuperview = isTop ? bottomContainerView : topContainerView
        
        if storyPagesViewController.view.superview != appropriateSuperview {
            add(viewController: storyPagesViewController, top: !isTop)
            
            adjustForAutoscroll()
            
//            if isTop {
//                bottomContainerView.addSubview(traverseView)
//                bottomContainerView.addSubview(autoscrollView)
//            } else {
//                topContainerView.addSubview(traverseView)
//                topContainerView.addSubview(autoscrollView)
//            }
        }
//
//        traverseTopContainerBottomConstraint.isActive = !isTop
//        traverseBottomContainerBottomConstraint.isActive = isTop
//        autoscrollTopContainerBottomConstraint.isActive = !isTop
//        autoscrollBottomContainerBottomConstraint.isActive = isTop
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
}
