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
        if isPhoneOrCompact {
            return feedDetailViewController?.navigationItem ?? navigationItem
        } else {
            return navigationItem
        }
    }
    
    /// The navigation item to use for the story pages view controller.
    @objc var storiesNavigationItem: UINavigationItem {
        if isPhoneOrCompact {
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

    private var fullscreenSidebarPresentationState = FullscreenSidebarPresentation.fullscreen
    private var fullscreenSidebarSupplementaryNavigationController: UINavigationController?
    private weak var fullscreenSidebarOverlayFeedDetailController: FeedDetailViewController?

    @objc var areStoryTitlesCollapsed: Bool {
        guard storyTitlesOnLeft, !isPhoneOrCompact else {
            return false
        }

        if shouldUseNativeFullscreenSidebarOverlay {
            return fullscreenSidebarPresentationState == .fullscreen
        }

        return leftContainerView.isHidden || verticalDividerViewLeadingConstraint.constant <= 0
    }

    @objc var isUsingNativeFullscreenSidebar: Bool {
        shouldUseNativeFullscreenSidebarOverlay
    }

    @objc var fullscreenSidebarPresentation: FullscreenSidebarPresentation {
        fullscreenSidebarPresentationState
    }

    /// Whether the detail is in temporary full-screen mode (overriding the column layout).
    @objc var isTemporaryFullScreen = false

    /// The display mode to restore when exiting temporary full-screen.
    private var preFullScreenDisplayMode: UISplitViewController.DisplayMode?
    private var preFullScreenSplitBehavior: UISplitViewController.SplitBehavior?

    @objc var shouldShowStoryTitlesFullscreenButton: Bool {
        let size = view.bounds.size.width > 0 ? view.bounds.size : UIScreen.main.bounds.size
        return StoryTitlesHeaderButtonDecision.showsFullscreenButton(
            for: fullscreenSidebarPresentationState,
            storyTitlesOnLeft: storyTitlesOnLeft,
            usesNativeFullscreenSidebar: shouldUseNativeFullscreenSidebarOverlay,
            isPhoneOrCompact: isPhoneOrCompact,
            width: size.width,
            height: size.height
        )
    }

    private var hasVisibleStoryForSidebarLayout: Bool {
        appDelegate.activeStory != nil || currentStoryController?.activeStory != nil
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
        manager.update(fullscreenSidebarSupplementaryNavigationController)
        manager.updateBackground(of: view)
        
        view.backgroundColor = navigationController?.navigationBar.barTintColor
        navigationController?.navigationBar.barStyle = manager.isDarkTheme ? .black : .default

        (verticalDividerView as? DividerView)?.updateTheme()
        (horizontalDividerView as? DividerView)?.updateTheme()
        
        tidyNavigationController()
    }
    
    /// Moves the story pages controller to a Grid layout cell content (automatically removing it from the previous parent).
    func prepareStoriesForGridView() {
        guard !isPhoneOrCompact, let storyPagesViewController else {
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

    @objc func resetStoryTitlesRevealOverride() {
        let size = view.bounds.size.width > 0 ? view.bounds.size : UIScreen.main.bounds.size
        guard StorySplitBehaviorDecision.shouldResetTemporarySidebarReveal(
            for: behaviorString,
            width: size.width,
            height: size.height,
            isMac: appDelegate.isMac
        ) else {
            return
        }

        dismissFullscreenSidebarOverlayIfNeeded(animated: false)
    }

    @objc(toggleStoryTitles:) func toggleStoryTitles(_ sender: Any?) {
        guard storyTitlesOnLeft, !isPhoneOrCompact else {
            return
        }

        resetTemporaryFullScreenIfNeeded()

        if shouldUseNativeFullscreenSidebarOverlay {
            let nextPresentation = FullscreenSidebarPresentationDecision.presentationAfterSidebarTap(
                fullscreenSidebarPresentationState
            )
            applyFullscreenSidebarPresentation(nextPresentation, sender: sender)
            return
        }

        fullscreenSidebarPresentationState = .storyTitles
        setStoryTitlesCollapsed(false, animated: true)
    }

    @objc(showStoryTitlesFromKeyboard:) func showStoryTitlesFromKeyboard(_ sender: Any?) {
        guard storyTitlesOnLeft, !isPhoneOrCompact else {
            return
        }

        resetTemporaryFullScreenIfNeeded()

        let nextPresentation = FullscreenSidebarPresentationDecision.presentationAfterKeyboardReveal(
            fullscreenSidebarPresentationState
        )
        applyKeyboardSidebarPresentation(nextPresentation, sender: sender)
    }

    @objc(hideStoryTitlesFromKeyboard:) func hideStoryTitlesFromKeyboard(_ sender: Any?) {
        guard storyTitlesOnLeft, !isPhoneOrCompact else {
            return
        }

        let nextPresentation = FullscreenSidebarPresentationDecision.presentationAfterKeyboardHide(
            fullscreenSidebarPresentationState
        )
        applyKeyboardSidebarPresentation(nextPresentation, sender: sender)
    }

    @objc(revealStoryTitlesFromLeadingEdgeGesture:) func revealStoryTitlesFromLeadingEdgeGesture(_ sender: Any?) {
        guard storyTitlesOnLeft, !isPhoneOrCompact else {
            return
        }

        resetTemporaryFullScreenIfNeeded()

        let nextPresentation = FullscreenSidebarPresentationDecision.presentationAfterLeadingEdgeReveal(
            fullscreenSidebarPresentationState
        )
        guard nextPresentation != fullscreenSidebarPresentationState else {
            return
        }

        if shouldUseNativeFullscreenSidebarOverlay {
            applyFullscreenSidebarPresentation(nextPresentation, sender: sender)
            return
        }

        fullscreenSidebarPresentationState = nextPresentation
        setStoryTitlesCollapsed(nextPresentation == .fullscreen, animated: true)
    }

    @objc(showFullscreenStoryDetail:) func showFullscreenStoryDetail(_ sender: Any?) {
        guard storyTitlesOnLeft, !isPhoneOrCompact else {
            return
        }

        let nextPresentation = FullscreenSidebarPresentationDecision.presentationAfterFullscreenButtonTap(
            fullscreenSidebarPresentationState
        )

        if shouldUseNativeFullscreenSidebarOverlay {
            applyFullscreenSidebarPresentation(nextPresentation, sender: sender)
            return
        }

        fullscreenSidebarPresentationState = nextPresentation

        if let splitViewController = appDelegate.splitViewController {
            UIView.animate(withDuration: 0.2) {
                splitViewController.preferredDisplayMode = .secondaryOnly
            }
        }

        setStoryTitlesCollapsed(true, animated: true)
    }

    @objc override func toggleTemporaryFullScreen(_ sender: Any?) {
        guard !isPhoneOrCompact else { return }

        if isTemporaryFullScreen {
            exitTemporaryFullScreen(animated: true)
        } else {
            enterTemporaryFullScreen(animated: true)
        }
    }

    private func enterTemporaryFullScreen(animated: Bool) {
        guard let splitViewController = appDelegate.splitViewController, !isTemporaryFullScreen else { return }

        preFullScreenDisplayMode = splitViewController.displayMode
        preFullScreenSplitBehavior = splitViewController.splitBehavior
        isTemporaryFullScreen = true

        let change = {
            splitViewController.preferredSplitBehavior = .overlay
            splitViewController.preferredDisplayMode = .secondaryOnly
            if splitViewController.displayMode != .secondaryOnly {
                splitViewController.hide(.primary)
            }
        }

        if animated {
            UIView.animate(withDuration: 0.2, animations: change)
        } else {
            change()
        }

        if storyTitlesOnLeft {
            setStoryTitlesCollapsed(true, animated: animated)
        }

        storyPagesViewController?.updateStoryTitleNavigationButtons()
        updateFullScreenToolbarItem()
    }

    private func exitTemporaryFullScreen(animated: Bool) {
        guard isTemporaryFullScreen else { return }

        isTemporaryFullScreen = false
        preFullScreenDisplayMode = nil
        preFullScreenSplitBehavior = nil

        if animated {
            UIView.animate(withDuration: 0.5) {
                self.appDelegate.updateSplitBehavior(true)
            }
        } else {
            appDelegate.updateSplitBehavior(true)
        }
        updateLayout(reload: false, fetchFeeds: false)
        storyPagesViewController?.updateStoryTitleNavigationButtons()
        updateFullScreenToolbarItem()
    }

    @objc func resetTemporaryFullScreenIfNeeded() {
        guard isTemporaryFullScreen else { return }
        exitTemporaryFullScreen(animated: false)
    }

    private func updateFullScreenToolbarItem() {
        #if targetEnvironment(macCatalyst)
        if let sceneDelegate = view.window?.windowScene?.delegate as? SceneDelegate {
            sceneDelegate.toolbarDelegate.updateFullScreenIcon(isFullScreen: isTemporaryFullScreen)
        }
        #endif
    }

    @objc func dismissFullscreenSidebarOverlayAfterStorySelection() {
        let nextPresentation = FullscreenSidebarPresentationDecision.presentationAfterStorySelection(
            fullscreenSidebarPresentationState
        )

        guard shouldUseNativeFullscreenSidebarOverlay else {
            let size = view.bounds.size.width > 0 ? view.bounds.size : UIScreen.main.bounds.size
            let shouldCollapse = StoryAutoCollapseDecision.shouldCollapse(
                isPhone: isPhone,
                isCompact: isCompact,
                hasActiveStory: hasVisibleStoryForSidebarLayout,
                behavior: StoryAutoCollapseBehavior(rawValue: behaviorString) ?? .auto,
                size: size,
                isMac: appDelegate.isMac
            )
            if shouldCollapse {
                fullscreenSidebarPresentationState = nextPresentation
                setStoryTitlesCollapsed(true, animated: true)
            }
            return
        }

        applyFullscreenSidebarPresentation(nextPresentation, sender: nil)
    }

    @objc func restoreStoryKeyboardFocusIfNeeded() {
        guard hasVisibleStoryForSidebarLayout else {
            return
        }

        DispatchQueue.main.async {
            _ = self.storyPagesViewController?.becomeFirstResponder()
        }
    }

    @objc func dismissFullscreenSidebarOverlayAfterFeedSelection() {
        let prefersNativeFullscreenSidebarOverlay = shouldPreferNativeFullscreenSidebarOverlay
        let nextPresentation = FullscreenSidebarPresentationDecision.presentationAfterFeedSelection(
            fullscreenSidebarPresentationState,
            usesNativeFullscreenSidebar: prefersNativeFullscreenSidebarOverlay
        )

        guard prefersNativeFullscreenSidebarOverlay else {
            fullscreenSidebarPresentationState = nextPresentation
            setStoryTitlesCollapsed(nextPresentation == .fullscreen, animated: true)
            return
        }

        guard shouldUseNativeFullscreenSidebarOverlay else {
            fullscreenSidebarPresentationState = nextPresentation
            return
        }

        applyFullscreenSidebarPresentation(nextPresentation, sender: nil)
    }

    @objc(syncFullscreenSidebarPresentationForDisplayMode:)
    func syncFullscreenSidebarPresentation(for displayMode: UISplitViewController.DisplayMode) {
        if !shouldUseNativeFullscreenSidebarOverlay {
            clearFullscreenSidebarSupplementaryControllerIfNeeded()
            switch displayMode {
            case .oneBesideSecondary, .oneOverSecondary, .twoBesideSecondary, .twoOverSecondary, .twoDisplaceSecondary:
                fullscreenSidebarPresentationState = .feeds
            default:
                fullscreenSidebarPresentationState = areStoryTitlesCollapsed ? .fullscreen : .storyTitles
            }
            fullscreenSidebarOverlayFeedDetailController?.updateSidebarButton(for: displayMode)
            appDelegate.feedDetailViewController.updateSidebarButton(for: displayMode)
            storyPagesViewController?.updateStoryTitleNavigationButtons()
            return
        }

        let presentation = FullscreenSidebarPresentationDecision.presentation(
            for: splitPreferredDisplayMode(for: displayMode)
        )
        fullscreenSidebarPresentationState = presentation

        if presentation == .fullscreen {
            scheduleFullscreenSidebarSupplementaryCleanup()
        } else {
            _ = ensureFullscreenSidebarSupplementaryController()
        }

        fullscreenSidebarOverlayFeedDetailController?.updateSidebarButton(for: displayMode)
        appDelegate.feedDetailViewController.updateSidebarButton(for: displayMode)
        storyPagesViewController?.updateStoryTitleNavigationButtons()
    }

    @objc(applyFullscreenSidebarPresentation:sender:)
    func applyFullscreenSidebarPresentation(
        _ presentation: FullscreenSidebarPresentation,
        sender: Any?
    ) {
        let _ = sender

        guard shouldUseNativeFullscreenSidebarOverlay,
              let splitViewController = appDelegate.splitViewController else {
            if presentation == .fullscreen {
                dismissFullscreenSidebarOverlayIfNeeded(animated: true)
            }
            return
        }

        let previousPresentation = fullscreenSidebarPresentationState
        if presentation != .fullscreen {
            guard ensureFullscreenSidebarSupplementaryController() != nil else {
                return
            }
        }

        switch presentation {
        case .fullscreen:
            dismissFullscreenSidebarOverlayIfNeeded(animated: true)
        case .storyTitles:
            fullscreenSidebarPresentationState = .storyTitles
            if previousPresentation == .feeds {
                splitViewController.hide(.primary)
            } else {
                splitViewController.show(.supplementary)
            }
        case .feeds:
            fullscreenSidebarPresentationState = .feeds
            splitViewController.show(.primary)
        }

        fullscreenSidebarOverlayFeedDetailController?.updateSidebarButton(for: splitViewController.displayMode)
        appDelegate.feedDetailViewController.updateSidebarButton(for: splitViewController.displayMode)
        storyPagesViewController?.updateStoryTitleNavigationButtons()
    }

    private func performStoryAutoCollapseIfNeeded() {
        guard storyTitlesOnLeft else {
            let size = view.bounds.size.width > 0 ? view.bounds.size : UIScreen.main.bounds.size
            let shouldCollapse = StoryAutoCollapseDecision.shouldCollapse(
                isPhone: isPhone,
                isCompact: isCompact,
                hasActiveStory: hasVisibleStoryForSidebarLayout,
                behavior: StoryAutoCollapseBehavior(rawValue: behaviorString) ?? .auto,
                size: size,
                isMac: appDelegate.isMac
            )
            if shouldCollapse {
                dismissFullscreenSidebarOverlayIfNeeded(animated: false)
            }
            return
        }

        if shouldUseNativeFullscreenSidebarOverlay {
            if let splitViewController,
               FullscreenSidebarPresentationDecision.needsNativeDisplayModeUpdate(
                for: fullscreenSidebarPresentationState,
                currentDisplayMode: splitPreferredDisplayMode(for: splitViewController.displayMode)
               ) {
                if fullscreenSidebarPresentationState == .fullscreen {
                    dismissFullscreenSidebarOverlayIfNeeded(animated: false)
                } else {
                    applyFullscreenSidebarPresentation(fullscreenSidebarPresentationState, sender: nil)
                }
            }
            setStoryTitlesCollapsed(true, animated: false)
            return
        }

        clearFullscreenSidebarSupplementaryControllerIfNeeded()

        if isTemporaryFullScreen {
            setStoryTitlesCollapsed(true, animated: false)
            return
        }

        let baseShouldCollapse = StoryAutoCollapseDecision.shouldCollapse(
            isPhone: isPhone,
            isCompact: isCompact,
            hasActiveStory: hasVisibleStoryForSidebarLayout,
            behavior: StoryAutoCollapseBehavior(rawValue: behaviorString) ?? .auto,
            size: view.bounds.size,
            isMac: appDelegate.isMac
        )
        let shouldCollapse = StoryAutoCollapseDecision.resolvedShouldCollapse(
            baseShouldCollapse: baseShouldCollapse,
            fullscreenSidebarPresentation: fullscreenSidebarPresentationState,
            usesNativeFullscreenSidebar: false,
            isTemporaryFullScreen: isTemporaryFullScreen
        )

        setStoryTitlesCollapsed(shouldCollapse, animated: true)
    }

    private func applyKeyboardSidebarPresentation(
        _ presentation: FullscreenSidebarPresentation,
        sender: Any?
    ) {
        if shouldUseNativeFullscreenSidebarOverlay {
            if presentation != fullscreenSidebarPresentationState {
                applyFullscreenSidebarPresentation(presentation, sender: sender)
            }
            restoreStoryKeyboardFocusIfNeeded()
            return
        }

        fullscreenSidebarPresentationState = presentation

        switch presentation {
        case .fullscreen:
            dismissFullscreenSidebarOverlayIfNeeded(animated: true)
        case .storyTitles:
            if let splitViewController {
                if splitViewController.displayMode == .secondaryOnly {
                    splitViewController.show(.supplementary)
                } else if splitViewController.displayMode != .oneBesideSecondary
                            && splitViewController.displayMode != .oneOverSecondary {
                    splitViewController.hide(.primary)
                }
                appDelegate.feedDetailViewController.updateSidebarButton(for: splitViewController.displayMode)
            }
            setStoryTitlesCollapsed(false, animated: true)
        case .feeds:
            break
        }

        storyPagesViewController?.updateStoryTitleNavigationButtons()
        restoreStoryKeyboardFocusIfNeeded()
    }

    private func setStoryTitlesCollapsed(_ shouldCollapse: Bool, animated: Bool) {
        guard storyTitlesOnLeft, !isPhoneOrCompact else {
            return
        }

        let collapsedLeadingConstant: CGFloat = 0
        let targetLeadingConstant = shouldCollapse ? collapsedLeadingConstant : verticalDividerPosition
        let targetAlpha: CGFloat = shouldCollapse ? 0 : 1

        guard verticalDividerViewLeadingConstraint.constant != targetLeadingConstant
                || leftContainerView.isHidden == shouldCollapse
                || leftContainerView.alpha != targetAlpha else {
            return
        }

        if !shouldCollapse {
            leftContainerView.isHidden = false
            verticalDividerView.isHidden = false
        }

        view.layoutIfNeeded()

        let animations = {
            self.verticalDividerViewLeadingConstraint.constant = targetLeadingConstant
            self.leftContainerView.alpha = targetAlpha
            self.verticalDividerView.alpha = targetAlpha
            self.view.layoutIfNeeded()
        }

        let completion: (Bool) -> Void = { _ in
            self.leftContainerView.isHidden = shouldCollapse
            self.verticalDividerView.isHidden = shouldCollapse
            self.appDelegate.feedDetailViewController.updateSidebarButton(for: self.appDelegate.splitViewController.displayMode)
            self.storyPagesViewController?.updateStoryTitleNavigationButtons()
        }

        if animated {
            UIView.animate(withDuration: 0.2, animations: animations, completion: completion)
        } else {
            animations()
            completion(true)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        (verticalDividerView as? DividerView)?.handleOffset = -6

        leftContainerView.clipsToBounds = true
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
                self.verticalDividerViewLeadingConstraint.constant = self.isTemporaryFullScreen
                    ? 0
                    : self.verticalDividerPosition
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
        storyPagesViewController?.updateStoryTitleNavigationButtons()
    }
    
    private func adjustTopConstraint() {
        guard let scene = view.window?.windowScene else {
            return
        }
        
        if !isPhoneOrCompact {
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
        guard let touch = touches.first else {
            super.touchesBegan(touches, with: event)
            return
        }

        if touch.view === verticalDividerView {
            (verticalDividerView as? DividerView)?.isHighlighted = true
        } else if touch.view === horizontalDividerView {
            (horizontalDividerView as? DividerView)?.isHighlighted = true
        } else {
            super.touchesBegan(touches, with: event)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first

        guard let point = touch?.location(in: view) else {
            super.touchesMoved(touches, with: event)
            return
        }

        let isInsideVertical = verticalDividerView.frame.contains(point)
        let isInsideHorizontal = horizontalDividerView.frame.contains(point)

        if touch?.view == verticalDividerView || isInsideVertical || isDraggingVerticalDivider {
            isDraggingVerticalDivider = true

            let leftContainerOriginX = leftContainerView.frame.origin.x
            let position = point.x - leftContainerOriginX

            guard position > 150, position < view.frame.width - leftContainerOriginX - 150 else {
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
        } else {
            super.touchesMoved(touches, with: event)
            return
        }

        view.setNeedsLayout()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDraggingVerticalDivider || isDraggingHorizontalDivider {
            isDraggingVerticalDivider = false
            isDraggingHorizontalDivider = false
            (verticalDividerView as? DividerView)?.isHighlighted = false
            (horizontalDividerView as? DividerView)?.isHighlighted = false
        } else {
            super.touchesEnded(touches, with: event)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDraggingVerticalDivider || isDraggingHorizontalDivider {
            isDraggingVerticalDivider = false
            isDraggingHorizontalDivider = false
            (verticalDividerView as? DividerView)?.isHighlighted = false
            (horizontalDividerView as? DividerView)?.isHighlighted = false
        } else {
            super.touchesCancelled(touches, with: event)
        }
    }
}

private extension DetailViewController {
    var shouldPreferNativeFullscreenSidebarOverlay: Bool {
        guard storyTitlesOnLeft, !isPhoneOrCompact else {
            return false
        }

        guard splitViewController?.style == .tripleColumn else {
            return false
        }

        let size = view.bounds.size.width > 0 ? view.bounds.size : UIScreen.main.bounds.size
        return StorySplitBehaviorDecision.preferredBehavior(
            for: behaviorString,
            width: size.width,
            height: size.height,
            isMac: appDelegate.isMac
        ) == .overlay
    }

    var shouldUseNativeFullscreenSidebarOverlay: Bool {
        shouldPreferNativeFullscreenSidebarOverlay && hasVisibleStoryForSidebarLayout
    }

    func splitPreferredDisplayMode(
        for displayMode: UISplitViewController.DisplayMode
    ) -> StorySplitPreferredDisplayMode {
        switch displayMode {
        case .oneBesideSecondary:
            return .oneBesideSecondary
        case .oneOverSecondary:
            return .oneOverSecondary
        case .twoBesideSecondary:
            return .twoBesideSecondary
        case .twoOverSecondary:
            return .twoOverSecondary
        case .twoDisplaceSecondary:
            return .twoDisplaceSecondary
        default:
            return .secondaryOnly
        }
    }

    @discardableResult
    func ensureFullscreenSidebarSupplementaryController() -> FeedDetailViewController? {
        guard shouldUseNativeFullscreenSidebarOverlay,
              let splitViewController else {
            return nil
        }

        if let controller = fullscreenSidebarOverlayFeedDetailController,
           let navigationController = fullscreenSidebarSupplementaryNavigationController {
            controller.storiesCollection = appDelegate.storiesCollection
            controller.changedLayout()
            controller.reload()
            splitViewController.setViewController(navigationController, for: .supplementary)
            return controller
        }

        guard let controller = Storyboards.shared.controller(withIdentifier: .feedDetail) as? FeedDetailViewController else {
            return nil
        }

        controller.storiesCollection = appDelegate.storiesCollection
        _ = controller.view
        controller.changedLayout()
        controller.reload()

        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.navigationBar.prefersLargeTitles = false
        ThemeManager.shared?.update(navigationController)

        splitViewController.setViewController(navigationController, for: .supplementary)

        fullscreenSidebarOverlayFeedDetailController = controller
        fullscreenSidebarSupplementaryNavigationController = navigationController

        return controller
    }

    func clearFullscreenSidebarSupplementaryControllerIfNeeded() {
        guard fullscreenSidebarSupplementaryNavigationController != nil
                || fullscreenSidebarOverlayFeedDetailController != nil else {
            return
        }

        splitViewController?.setViewController(nil, for: .supplementary)
        fullscreenSidebarSupplementaryNavigationController = nil
        fullscreenSidebarOverlayFeedDetailController = nil
    }

    func scheduleFullscreenSidebarSupplementaryCleanup() {
        guard fullscreenSidebarPresentationState == .fullscreen else {
            return
        }

        if let coordinator = splitViewController?.transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { _ in
                guard self.fullscreenSidebarPresentationState == .fullscreen else {
                    return
                }
                self.clearFullscreenSidebarSupplementaryControllerIfNeeded()
            }
        } else {
            DispatchQueue.main.async {
                guard self.fullscreenSidebarPresentationState == .fullscreen else {
                    return
                }
                self.clearFullscreenSidebarSupplementaryControllerIfNeeded()
            }
        }
    }

    func dismissFullscreenSidebarOverlayIfNeeded(animated: Bool) {
        let shouldDismissNativeOverlay = shouldUseNativeFullscreenSidebarOverlay
            && splitViewController?.displayMode != .secondaryOnly
        guard fullscreenSidebarPresentationState != .fullscreen
                || fullscreenSidebarSupplementaryNavigationController != nil
                || shouldDismissNativeOverlay else {
            return
        }

        if !shouldUseNativeFullscreenSidebarOverlay {
            fullscreenSidebarPresentationState = .fullscreen

            if let splitViewController, splitViewController.displayMode != .secondaryOnly {
                let dismissFeeds = {
                    splitViewController.hide(.primary)
                }

                if animated {
                    dismissFeeds()
                } else {
                    UIView.performWithoutAnimation {
                        dismissFeeds()
                    }
                }
            }

            setStoryTitlesCollapsed(true, animated: animated)
            return
        }

        fullscreenSidebarPresentationState = .fullscreen

        guard let splitViewController else {
            clearFullscreenSidebarSupplementaryControllerIfNeeded()
            return
        }

        let dismissOverlay = {
            splitViewController.hide(.supplementary)
        }

        if splitViewController.displayMode == .secondaryOnly {
            clearFullscreenSidebarSupplementaryControllerIfNeeded()
        } else if animated {
            dismissOverlay()
            scheduleFullscreenSidebarSupplementaryCleanup()
        } else {
            UIView.performWithoutAnimation {
                dismissOverlay()
            }
            clearFullscreenSidebarSupplementaryControllerIfNeeded()
        }

        fullscreenSidebarOverlayFeedDetailController?.updateSidebarButton(for: splitViewController.displayMode)
        appDelegate.feedDetailViewController.updateSidebarButton(for: splitViewController.displayMode)
    }

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

        if storyTitlesInGridView || layout != .left {
            dismissFullscreenSidebarOverlayIfNeeded(animated: false)
        }
        
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
            
            if wasGridView && !isPhoneOrCompact {
                DispatchQueue.main.async {
                    self.appDelegate.loadStoryDetailView()
                }
            }
            
            verticalDividerViewLeadingConstraint.constant = isTemporaryFullScreen ? 0 : verticalDividerPosition
            if isTemporaryFullScreen {
                leftContainerView.alpha = 0
                leftContainerView.isHidden = true
                verticalDividerView.alpha = 0
                verticalDividerView.isHidden = true
            }
            horizontalDividerViewBottomConstraint.constant = -13
            appDelegate.updateSplitBehavior(true)
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
        
        if viewController.parent !== self {
            addChild(viewController)
        } else if viewController.view.superview === containerView {
            return
        } else {
            viewController.view.removeFromSuperview()
        }

        containerView.addSubview(viewController.view)
        
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
        viewController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
        viewController.view.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
        viewController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true

        if viewController.parent === self {
            viewController.didMove(toParent: self)
        }
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
