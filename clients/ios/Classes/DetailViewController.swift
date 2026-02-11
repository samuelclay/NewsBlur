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
    /// Preference keys.
    enum Key {
        /// Style of the feed detail list layout.
        static let style = "story_titles_style"
        
        /// Behavior of the split controller.
        static let behavior = "split_behavior"
        
        /// Position of the vertical divider between the views when in landscape orientation. Only used for `.left`layout.
        static let verticalDividerLandscapePosition = "story_titles_vertical_divider_landscape"
        
        /// Position of the vertical divider between the views when in portrait orientation. Only used for `.left` layout.
        static let verticalDividerPortraitPosition = "story_titles_vertical_divider_portrait"
        
        /// Position of the horizontal divider between the views when in landscape orientation. Only used for `.top` and `.bottom` layouts.
        static let horizontalDividerLandscapePosition = "story_titles_divider_horizontal"
        
        /// Position of the horizontal divider between the views when in portrait orientation. Only used for `.top` and `.bottom` layouts.
        static let horizontalDividerPortraitPosition = "story_titles_divider_vertical"
        
        /// Width of the feeds view, i.e. the primary split column.
        static let feedsWidth = "split_primary_width"
    }
    
    /// Preference values.
    enum LayoutValue {
        static let left = "titles_on_left"
        static let top = "titles_on_top"
        static let bottom = "titles_on_bottom"
        static let list = "titles_in_list"
        static let magazine = "titles_in_magazine"
        static let grid = "titles_in_grid"
    }
    
    /// How the feed detail and story pages are laid out.
    enum Layout {
        /// The feed detail is to the left of the story pages (and managed by the split view, not here).
        case left
        
        /// The feed detail is at the top, the story pages at the bottom.
        case top
        
        /// The story pages are at the top, the feed detail at the bottom.
        case bottom
        
        /// Using a list-style grid view for the story titles and story pages.
        case list
        
        /// Using a magazine-style grid view for the story titles and story pages.
        case magazine
        
        /// Using a grid-style grid view for the story titles and story pages.
        case grid
    }
    
    /// How the feed detail and story pages are laid out.
    var layout: Layout {
        get {
            switch appDelegate.storiesCollection.activeStoryTitlesPosition {
                case LayoutValue.top:
                    return .top
                case LayoutValue.bottom:
                    return .bottom
                case LayoutValue.list:
                    return .list
                case LayoutValue.magazine:
                    return .magazine
                case LayoutValue.grid:
                    return .grid
                default:
                    return .left
            }
        }
        set {
            guard newValue != layout, let key = appDelegate.storiesCollection.storyTitlesPositionKey else {
                return
            }
            
            switch newValue {
                case .top:
                    UserDefaults.standard.set(LayoutValue.top, forKey: key)
                case .bottom:
                    UserDefaults.standard.set(LayoutValue.bottom, forKey: key)
                case .list:
                    UserDefaults.standard.set(LayoutValue.list, forKey: key)
                case .magazine:
                    UserDefaults.standard.set(LayoutValue.magazine, forKey: key)
                case .grid:
                    UserDefaults.standard.set(LayoutValue.grid, forKey: key)
                default:
                    UserDefaults.standard.set(LayoutValue.left, forKey: key)
            }
            
            updateLayout(reload: true, fetchFeeds: true)
        }
    }
    
    /// Whether or not the feed detail is on the left; see also the following properties.
    @objc var storyTitlesOnLeft: Bool {
        return layout == .left
    }
    
    /// Whether or not the feed detail is on the top; see also the previous property.
    @objc var storyTitlesOnTop: Bool {
        return layout == .top
    }
    
    /// Whether or not using the list layout; see also the previous properties.
    @objc var storyTitlesInList: Bool {
        return layout == .list || storyTitlesInDashboard
    }
    
    /// Whether or not using the magazine layout; see also the previous properties.
    @objc var storyTitlesInMagazine: Bool {
        return layout == .magazine
    }
    
    /// Whether or not using the grid layout; see also the previous properties.
    @objc var storyTitlesInGrid: Bool {
        return layout == .grid
    }
    
    /// Whether or not using the list, magazine, or grid layout; see also the previous properties.
    @objc var storyTitlesInGridView: Bool {
        return [.list, .magazine, .grid].contains(layout) || storyTitlesInDashboard
    }
    
    /// Whether or not using the legacy list for non-grid layout.
    @objc var storyTitlesInLegacyTable: Bool {
        return !storyTitlesInGridView && style != .experimental
    }
    
    /// Whether or not showing the dashboard.
    @objc var storyTitlesInDashboard = false
    
    /// Whether or not showing the feed list when tapped a story in the dashboard.
    @objc var storyTitlesFromDashboardStory = false
    
    /// Whether or not we are using compact size class, instead of regular size class. (A local property, instead of asking the OS, so it is updated when the split delegate handles the change.)
    @objc var isCompact = false

    /// Convenience for phone or compact layout.
    @objc var isPhoneOrCompact: Bool {
        return isPhone || isCompact
    }
    
    /// Whether or not the views were last set up for compact size class.
    private var wasCompact = false

    /// Preference values.
    enum StyleValue {
        static let standard = "standard"
        static let experimental = "experimental"
    }
    
    /// Style of the feed detail list layout.
    enum Style {
        /// The feed detail list uses the legacy table view.
        case standard
        
        /// The feed detail list uses the SwiftUI grid view.
        case experimental
    }
    
    /// Style of the feed detail list layout.
    var style: Style {
        get {
            switch UserDefaults.standard.string(forKey: Key.style) {
                case StyleValue.experimental:
                    return .experimental
                default:
                    return .standard
            }
        }
        set {
            guard newValue != style else {
                return
            }
            
            switch newValue {
                case .experimental:
                    UserDefaults.standard.set(StyleValue.experimental, forKey: Key.style)
                default:
                    UserDefaults.standard.set(StyleValue.standard, forKey: Key.style)
            }
            
            updateLayout(reload: true, fetchFeeds: true)
        }
    }
    
   /// Preference values.
    enum BehaviorValue {
        static let auto = "auto"
        static let tile = "tile"
        static let displace = "displace"
        static let overlay = "overlay"
    }
    
    /// How the split controller behaves.
    enum Behavior {
        /// The split controller figures out the best behavior.
        case auto
        
        /// The split controller arranges the views side-by-side.
        case tile
        
        /// The split controller pushes the detail view aside.
        case displace
        
        /// The split controller puts the left columns over the detail view.
        case overlay
    }
    
    /// How the split controller behaves.
    var behavior: Behavior {
        switch behaviorString {
        case BehaviorValue.tile:
            return .tile
        case BehaviorValue.displace:
            return .displace
        case BehaviorValue.overlay:
            return .overlay
        default:
            return .auto
        }
    }
    
    /// The split controller behavior as a raw string.
    @objc var behaviorString: String {
        return UserDefaults.standard.string(forKey: Key.behavior) ?? BehaviorValue.auto
    }
    
    /// Position of the vertical divider between the views.
    var verticalDividerPosition: CGFloat {
        get {
            let key = isPortrait ? Key.verticalDividerPortraitPosition : Key.verticalDividerLandscapePosition
            let value = CGFloat(UserDefaults.standard.float(forKey: key))
            
            if value == 0 {
                return 400
            } else {
                return value
            }
        }
        set {
            guard newValue != verticalDividerPosition else {
                return
            }
            
            let key = isPortrait ? Key.verticalDividerPortraitPosition : Key.verticalDividerLandscapePosition
            
            UserDefaults.standard.set(Float(newValue), forKey: key)
        }
    }
    
    /// Position of the horizontal divider between the views.
    var horizontalDividerPosition: CGFloat {
        get {
            let key = isPortrait ? Key.horizontalDividerPortraitPosition : Key.horizontalDividerLandscapePosition
            let value = CGFloat(UserDefaults.standard.float(forKey: key))
            
            if value == 0 {
                return 200
            } else {
                return value
            }
        }
        set {
            guard newValue != horizontalDividerPosition else {
                return
            }
            
            let key = isPortrait ? Key.horizontalDividerPortraitPosition : Key.horizontalDividerLandscapePosition
            
            UserDefaults.standard.set(Float(newValue), forKey: key)
        }
    }
    
    /// Width of the feeds view, i.e. the primary split column.
    var feedsWidth: CGFloat {
        get {
            let value = CGFloat(UserDefaults.standard.float(forKey: Key.feedsWidth))
            
            if value == 0 {
                return 320
            } else {
                return value
            }
        }
        set {
            guard newValue != feedsWidth else {
                return
            }
            
            UserDefaults.standard.set(Float(newValue), forKey: Key.feedsWidth)
        }
    }
    
    /// Left container view.
    @IBOutlet weak var leftContainerView: UIView!
    
    /// Top container view.
    @IBOutlet weak var topContainerView: UIView!
    
    /// Bottom container view.
    @IBOutlet weak var bottomContainerView: UIView!
    
    /// Draggable vertical divider view.
    @IBOutlet weak var verticalDividerView: UIView!
    
    /// Draggable horizontal divider view.
    @IBOutlet weak var horizontalDividerView: UIView!
    
    /// Vertical divider view leading constraint.
    @IBOutlet weak var verticalDividerViewLeadingConstraint: NSLayoutConstraint!
    
    /// Top container view top constraint. May need to adjust this for fullscreen on iPhone.
    @IBOutlet weak var topContainerTopConstraint: NSLayoutConstraint!
    
    /// Horizontal divider view bottom constraint.
    @IBOutlet weak var horizontalDividerViewBottomConstraint: NSLayoutConstraint!
    
    /// The navigation controller managed by the split view controller, that encloses the immediate navigation controller of the detail view when in compact layout.
    @objc var parentNavigationController: UINavigationController? {
        return navigationController?.parent as? UINavigationController
    }
    
    /// The navigation item to use for the feed detail view controller.
    @objc var feedDetailNavigationItem: UINavigationItem {
        if isPhone {
            return feedDetailViewController?.navigationItem ?? navigationItem
        } else {
            return navigationItem
        }
    }
    
    /// The navigation item to use for the story pages view controller.
    @objc var storiesNavigationItem: UINavigationItem {
        if isPhone {
            return storyPagesViewController?.navigationItem ?? navigationItem
        } else {
            return navigationItem
        }
    }
    
    /// The feed detail view controller.
    @objc var feedDetailViewController: FeedDetailViewController?
    
    /// Whether or not a grid view-based layout was used the last time checking the view controllers.
    var wasGridView = false
    
    /// An instance of the story pages view controller for list layouts.
    lazy var listStoryPagesViewController = StoryPagesViewController()
    
    /// A separate instance of the story pages view controller for use in a grid view-based layout.
    lazy var gridStoryPagesViewController = StoryPagesViewController()
    
    /// The story pages view controller, that manages the previous, current, and next story view controllers.
    @objc var storyPagesViewController: StoryPagesViewController?
    
    /// Returns the currently displayed story view controller, or `nil` if none.
    @objc var currentStoryController: StoryDetailViewController? {
        return storyPagesViewController?.currentPage
    }
    
    /// Moves the feed detail and story pages (as appropriate) onto the feeds navigation stack. Called when collapsing to a compact size class.
    func collapseToSingleColumn() {
        isCompact = true
        
        checkViewControllers()
    }
    
    /// Moves the feed detail and story pages (as appropriate) to the detail view. Called when expanding to a regular size class.
    func expandToTwoColumns() {
        isCompact = false
        
        appDelegate.feedsNavigationController.popToRootViewController(animated: false)
        
        checkViewControllers()
    }
    
    /// Prepare the views.
    @objc func checkLayout() {
        checkViewControllers()
    }
    
    /// Updates the layout; call this when the layout is changed in the preferences.
    @objc(updateLayoutWithReload:fetchFeeds:) func updateLayout(reload: Bool, fetchFeeds: Bool) {
        checkViewControllers()
        
        if fetchFeeds {
            appDelegate.feedsViewController.loadOfflineFeeds(false)
        }
        
        if reload {
            feedDetailViewController?.reload()
        }
    }
    
    /// Update the theme.
    @objc override func updateTheme() {
        super.updateTheme()
        
        guard let manager = ThemeManager.shared else {
            return
        }
        
        manager.update(navigationController)
        manager.updateBackground(of: view)
        
        view.backgroundColor = navigationController?.navigationBar.barTintColor
        navigationController?.navigationBar.barStyle = manager.isDarkTheme ? .black : .default

        (verticalDividerView as? DividerView)?.updateTheme()
        (horizontalDividerView as? DividerView)?.updateTheme()
        
        tidyNavigationController()
    }
    
    /// Moves the story pages controller to a Grid layout cell content (automatically removing it from the previous parent).
    func prepareStoriesForGridView() {
        guard !isPhone, let storyPagesViewController else {
            return
        }
        
        NSLog("🎈 prepareStoriesForGridView: \(storyPagesViewController.currentPage.activeStory?["story_title"] ?? "none")")
        
        remove(viewController: storyPagesViewController)
        
        storyPagesViewController.updatePage(withActiveStory: appDelegate.storiesCollection.locationOfActiveStory(), updateFeedDetail: false)
        
        adjustForAutoscroll()
        
        storyPagesViewController.currentPage.webView.scrollView.isScrollEnabled = false
    }
    
    /// Moves the story pages controller to the appropriate container in the detail controller (automatically removing it from the previous parent).
    @objc func moveStoriesToDetailContainer() {
        guard let storyPagesViewController else {
            return
        }
        
        let isTop = layout == .top
        let appropriateContainerView = isTop ? bottomContainerView : topContainerView
        
        if isCompact || storyPagesViewController.view.superview != appropriateContainerView {
            add(viewController: storyPagesViewController, to: appropriateContainerView, compactPush: isStoryShown)
            
            adjustForAutoscroll()
            
            storyPagesViewController.currentPage.webView.scrollView.isScrollEnabled = true
        }
    }
    
    /// Adjusts the container when autoscrolling. Only applies to iPhone.
    @objc func adjustForAutoscroll() {
        adjustTopConstraint()
        updateTheme()
    }
    
    @objc(showColumn:animated:) func show(column: UISplitViewController.Column, animated: Bool) {
        if isCompact {
            if column == .primary {
                appDelegate.feedsNavigationController.popToRootViewController(animated: animated)
            } else {
                if isFeedShown, let feedDetailViewController, appDelegate.feedsNavigationController.viewControllers.count < 2 {
                    appDelegate.feedsNavigationController.pushViewController(feedDetailViewController, animated: animated)
                }
                
                if isStoryShown, let storyPagesViewController, appDelegate.feedsNavigationController.viewControllers.count < 3 {
                    appDelegate.feedsNavigationController.pushViewController(storyPagesViewController, animated: animated)
                }
            }
        } else {
            guard let splitViewController = appDelegate.splitViewController else {
                return
            }
            
            if column == .primary {
                appDelegate.updateSplitBehavior(false)
            }
            
            if (splitViewController.displayMode != .secondaryOnly && splitViewController.preferredDisplayMode != .oneBesideSecondary) || splitViewController.preferredDisplayMode != .oneOverSecondary {
                splitViewController.show(column)
            }
        }
    }

    @objc func collapseFeedListIfNeededForStory() {
        DispatchQueue.main.async {
            self.performStoryAutoCollapseIfNeeded()
        }
    }

    private func performStoryAutoCollapseIfNeeded() {
        guard !isPhone, !isCompact, appDelegate.activeStory != nil else {
            return
        }
        guard let splitViewController = splitViewController as? SplitViewController else {
            return
        }
        if splitViewController.displayMode == .secondaryOnly {
            return
        }
        if splitViewController.displayMode != .oneBesideSecondary {
            return
        }

        splitViewController.view.layoutIfNeeded()
        view.layoutIfNeeded()

        if behavior == .tile {
            return
        }

        if behavior == .auto {
            let size = splitViewController.view.bounds.size
            #if targetEnvironment(macCatalyst)
            // On Mac, only skip auto-collapse if window is wide enough for tiled layout
            if size.width >= 900 {
                return
            }
            #else
            let isLandscape = size.width > size.height
            if isLandscape {
                return
            }
            #endif
        }

        UIView.animate(withDuration: 0.2) {
            splitViewController.preferredDisplayMode = .oneOverSecondary
        }
        splitViewController.show(.secondary)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateLayout(reload: false, fetchFeeds: false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        adjustTopConstraint()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        if self.verticalDividerView == nil {
            return
        }
        
        if [.left].contains(layout) {
            coordinator.animate { context in
                self.verticalDividerViewLeadingConstraint.constant = self.verticalDividerPosition
            }
        } else if [.top, .bottom].contains(layout) {
            coordinator.animate { context in
                self.horizontalDividerViewBottomConstraint.constant = self.horizontalDividerPosition
            }
        }
        
        coordinator.animate { context in
            self.adjustTopConstraint()
        }

        coordinator.animate(alongsideTransition: nil) { _ in
            self.collapseFeedListIfNeededForStory()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let currentFeedsWidth = splitViewController?.primaryColumnWidth ?? 320
        
        if currentFeedsWidth != feedsWidth {
            feedsWidth = currentFeedsWidth
        }

        performStoryAutoCollapseIfNeeded()
    }
    
    private func adjustTopConstraint() {
        guard let scene = view.window?.windowScene else {
            return
        }
        
        if !isPhone {
            if scene.traitCollection.horizontalSizeClass == .compact {
                topContainerTopConstraint.constant = -50
            } else {
                topContainerTopConstraint.constant = 0
            }
        } else if let controller = storyPagesViewController, !controller.isNavigationBarHidden {
            let navigationHeight = navigationController?.navigationBar.frame.height ?? 0
            let adjustment: CGFloat = view.safeAreaInsets.top > 25 ? 5 : 0
            
            topContainerTopConstraint.constant = -(navigationHeight - adjustment)
        } else {
            topContainerTopConstraint.constant = 0
        }
    }
    
    private var isDraggingVerticalDivider = false
    private var isDraggingHorizontalDivider = false

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        if touch.view === verticalDividerView {
            (verticalDividerView as? DividerView)?.isHighlighted = true
        } else if touch.view === horizontalDividerView {
            (horizontalDividerView as? DividerView)?.isHighlighted = true
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first

        guard let point = touch?.location(in: view) else {
            return
        }

        let isInsideVertical = verticalDividerView.frame.contains(point)
        let isInsideHorizontal = horizontalDividerView.frame.contains(point)

        if touch?.view == verticalDividerView || isInsideVertical || isDraggingVerticalDivider {
            isDraggingVerticalDivider = true

            let leftContainerOriginX = leftContainerView.frame.origin.x
            let position = point.x - leftContainerOriginX

            guard position > 150, position < view.frame.width - leftContainerOriginX - 200 else {
                return
            }

            verticalDividerPosition = position
            verticalDividerViewLeadingConstraint.constant = position
        } else if touch?.view == horizontalDividerView || isInsideHorizontal || isDraggingHorizontalDivider {
            isDraggingHorizontalDivider = true

            let position = view.frame.height - point.y

            guard position > 150, position < view.frame.height - 200 else {
                return
            }

            horizontalDividerPosition = position
            horizontalDividerViewBottomConstraint.constant = position
        }

        view.setNeedsLayout()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDraggingVerticalDivider = false
        isDraggingHorizontalDivider = false
        (verticalDividerView as? DividerView)?.isHighlighted = false
        (horizontalDividerView as? DividerView)?.isHighlighted = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDraggingVerticalDivider = false
        isDraggingHorizontalDivider = false
        (verticalDividerView as? DividerView)?.isHighlighted = false
        (horizontalDividerView as? DividerView)?.isHighlighted = false
    }
}

private extension DetailViewController {
    func checkViewControllers() {
        let isTop = layout == .top
        
#if targetEnvironment(macCatalyst)
        splitViewController?.primaryBackgroundStyle = .sidebar
        splitViewController?.minimumPrimaryColumnWidth = 250
        splitViewController?.maximumPrimaryColumnWidth = 700
        splitViewController?.preferredPrimaryColumnWidth = feedsWidth
#endif
        
        if isCompact, let feedDetailViewController {
            if !isStoryShown {
                remove(viewController: storyPagesViewController)
            }
            
            if !feedDetailViewController.isFeedShown {
                remove(viewController: feedDetailViewController)
            }
        }
        
        resetControllersIfCompactStateChanged()
        
        if !storyTitlesInGridView {
            storyPagesViewController = listStoryPagesViewController
            _ = storyPagesViewController?.view
            
            if !isCompact {
                moveStoriesToDetailContainer()
            }
        } else {
            storyPagesViewController = gridStoryPagesViewController
            _ = storyPagesViewController?.view
        }
        
        if storyTitlesInGridView {
            if feedDetailViewController == nil || !wasGridView {
                addResetFeedDetail(to: topContainerView)
                
                if storyTitlesInDashboard, let feedDetailViewController, feedDetailViewController.storyCache.dashboardAll.isEmpty {
                    feedDetailViewController.storyCache.prepareDashboard()
                    
                    DispatchQueue.main.async {
                        self.appDelegate.feedsViewController.loadDashboard()
                    }
                }
            } else {
                add(viewController: feedDetailViewController, to: topContainerView, compactPush: isFeedShown)
            }
            
            verticalDividerViewLeadingConstraint.constant = -13
            horizontalDividerViewBottomConstraint.constant = -13
            wasGridView = true
        } else if layout == .left {
            if feedDetailViewController == nil {
                addResetFeedDetail(to: leftContainerView)
            } else if feedDetailViewController?.view.superview != leftContainerView {
                add(viewController: feedDetailViewController, to: leftContainerView, compactPush: isFeedShown)
            }
            
            if wasGridView && !isPhone {
                DispatchQueue.main.async {
                    self.appDelegate.loadStoryDetailView()
                }
            }
            
            verticalDividerViewLeadingConstraint.constant = verticalDividerPosition
            horizontalDividerViewBottomConstraint.constant = -13
            wasGridView = false
        } else {
            let appropriateContainerView: UIView = isTop ? topContainerView : bottomContainerView
            
            if feedDetailViewController == nil || wasGridView {
                addResetFeedDetail(to: appropriateContainerView)
            } else if isCompact || feedDetailViewController?.view.superview != appropriateContainerView {
                add(viewController: feedDetailViewController, to: appropriateContainerView, compactPush: isFeedShown)
            }
            
            verticalDividerViewLeadingConstraint.constant = -13
            horizontalDividerViewBottomConstraint.constant = horizontalDividerPosition
            
            appDelegate.updateSplitBehavior(true)
            wasGridView = false
        }
        
        if !storyTitlesInGridView, isCompact, isStoryShown {
            moveStoriesToDetailContainer()
        }
        
        wasCompact = isCompact
        
        feedDetailViewController?.changedLayout()
    }
    
    func addResetFeedDetail(to containerView: UIView?) {
        remove(viewController: feedDetailViewController)
        
        feedDetailViewController = Storyboards.shared.controller(withIdentifier: .feedDetail) as? FeedDetailViewController
        feedDetailViewController?.resetFeedDetail()
        feedDetailViewController?.storiesCollection = appDelegate.storiesCollection
        
        add(viewController: feedDetailViewController, to: containerView, compactPush: isFeedShown)
    }
    
    func add(viewController: UIViewController?, to containerView: UIView?, compactPush: Bool) {
        guard let viewController, let containerView else {
            return
        }
        
        if isCompact {
            remove(viewController: viewController)
            
            if compactPush {
                appDelegate.feedsNavigationController.pushViewController(viewController, animated: false)
            }
            
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
        guard let viewController else {
            return
        }
        
        removeFromFeedsNavigation(viewController: viewController)
        
        viewController.willMove(toParent: nil)
        viewController.removeFromParent()
        viewController.view.removeFromSuperview()
    }
    
    func removeFromFeedsNavigation(viewController: UIViewController?) {
        guard let viewController, let nav = appDelegate.feedsNavigationController else {
            return
        }
        
        var controllers = nav.viewControllers
        
        if let idx = controllers.firstIndex(where: { $0 === viewController }) {
            controllers.remove(at: idx)
            nav.setViewControllers(controllers, animated: false)
        }
    }
    
    func resetControllersIfCompactStateChanged() {
        if isCompact != wasCompact {
            feedDetailViewController = nil
            
            listStoryPagesViewController = StoryPagesViewController()
            gridStoryPagesViewController = StoryPagesViewController()
        }
    }
    
    /// The status bar portion of the navigation controller isn't the right color, due to a white subview bleeding through the visual effect view. This somewhat hacky function will correct that.
    func tidyNavigationController() {
        guard let visualEffectSubviews = navigationController?.navigationBar.subviews.first?.subviews.first?.subviews, visualEffectSubviews.count == 3, visualEffectSubviews[1].alpha == 1 else {
            return
        }
        
        navigationController?.navigationBar.subviews.first?.backgroundColor = UINavigationBar.appearance().backgroundColor
    }
}
