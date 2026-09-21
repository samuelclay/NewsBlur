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
    private var retainedDiscoveryController: UIViewController?
    private var discoveryPaneNavigationController: UINavigationController?
    private var discoveryHiddenViews: [(UIView, Bool)] = []
    private var discoveryPreviewActive = false
    private var discoveryPreviousNavigationBarHidden: Bool?
    private var discoveryPreviousNavigationBackground: (UIView, UIColor?)?
    private var discoveryStatusBarBackground: UIView?
    private var discoveryPreviousSplitPresentation: (UISplitViewController.DisplayMode, UISplitViewController.SplitBehavior)?

    @objc var isDiscoverSitesVisible: Bool {
        if let navigation = discoveryPaneNavigationController { return navigation.parent === self }
        guard let controller = retainedDiscoveryController else { return false }
        return appDelegate.feedsNavigationController?.topViewController === controller
    }

    @objc var canReturnToDiscoverSites: Bool {
        guard let controller = retainedDiscoveryController, discoveryPreviewActive else { return false }
        return !isPhoneOrCompact || appDelegate.feedsNavigationController.viewControllers.contains { $0 === controller }
    }

    @available(iOS 15.0, *)
    @objc func showDiscoverSites(_ controller: DiscoverSitesViewController) {
        dismissDiscoverSites()
        controller.appDelegate = appDelegate
        retainedDiscoveryController = controller
        appDelegate.feedsViewController?.highlightDiscoverySelection()
        if isPhoneOrCompact {
            appDelegate.feedsNavigationController.pushViewController(controller, animated: true)
        } else {
            mountDiscoveryPane(controller)
        }
    }

    private func mountDiscoveryPane(_ controller: UIViewController) {
        loadViewIfNeeded()
        guard discoveryPaneNavigationController == nil else { return }
        removeFromFeedsNavigation(viewController: controller)
        if let split = appDelegate.splitViewController {
            discoveryPreviousSplitPresentation = (split.preferredDisplayMode, split.preferredSplitBehavior)
            dismissFullscreenSidebarOverlayIfNeeded(animated: false)
        }
        let navigation = UINavigationController(rootViewController: controller)
        discoveryPaneNavigationController = navigation
        addChild(navigation)
        // DetailViewController.swift snapshots the underlying reader state, not the temporary hidden host used beside tiled Feeds.
        restoreReaderBesideStoryTitles()
        // DetailViewController.swift replaces both reader columns while retaining their navigation state.
        discoveryHiddenViews = view.subviews.map { ($0, $0.isHidden) }
        discoveryHiddenViews.forEach { $0.0.isHidden = true }
        navigation.view.frame = view.bounds
        navigation.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(navigation.view)
        navigation.didMove(toParent: self)
        if let parentNavigation = navigationController {
            discoveryPreviousNavigationBarHidden = parentNavigation.isNavigationBarHidden
            discoveryPreviousNavigationBackground = (parentNavigation.view, parentNavigation.view.backgroundColor)
            parentNavigation.setNavigationBarHidden(true, animated: false)
        }
        let statusBarHost = navigationController?.view ?? view!
        let statusBarBackground = UIView()
        statusBarBackground.accessibilityIdentifier = "discover-status-bar-background"
        statusBarBackground.isUserInteractionEnabled = false
        statusBarBackground.translatesAutoresizingMaskIntoConstraints = false
        statusBarHost.addSubview(statusBarBackground)
        NSLayoutConstraint.activate([
            statusBarBackground.topAnchor.constraint(equalTo: statusBarHost.topAnchor),
            statusBarBackground.leadingAnchor.constraint(equalTo: statusBarHost.leadingAnchor),
            statusBarBackground.trailingAnchor.constraint(equalTo: statusBarHost.trailingAnchor),
            statusBarBackground.bottomAnchor.constraint(equalTo: statusBarHost.safeAreaLayoutGuide.topAnchor)
        ])
        discoveryStatusBarBackground = statusBarBackground
        updateDiscoveryPaneTheme()
        if let split = appDelegate.splitViewController {
            split.preferredSplitBehavior = .tile
            split.preferredDisplayMode = .oneBesideSecondary
            split.show(.primary)
        }
    }

    private func unmountDiscoveryPane() {
        guard let navigation = discoveryPaneNavigationController else { return }
        navigation.willMove(toParent: nil)
        navigation.view.removeFromSuperview()
        navigation.removeFromParent()
        navigation.setViewControllers([], animated: false)
        discoveryPaneNavigationController = nil
        discoveryStatusBarBackground?.removeFromSuperview()
        discoveryStatusBarBackground = nil
        discoveryHiddenViews.forEach { $0.0.isHidden = $0.1 }
        discoveryHiddenViews.removeAll()
        if let hidden = discoveryPreviousNavigationBarHidden {
            navigationController?.setNavigationBarHidden(hidden, animated: false)
            discoveryPreviousNavigationBarHidden = nil
        }
        if let (backgroundView, color) = discoveryPreviousNavigationBackground {
            backgroundView.backgroundColor = color
            discoveryPreviousNavigationBackground = nil
        }
        if let previous = discoveryPreviousSplitPresentation, let split = appDelegate.splitViewController {
            split.preferredSplitBehavior = previous.1
            split.preferredDisplayMode = previous.0
            discoveryPreviousSplitPresentation = nil
        }
    }

    @objc func resetDiscoveryForAccountChange() {
        expandedFeedsReveal = nil
        appDelegate.trainerViewController?.resetForAccountChange()
        duoFullscreenRequested = false
        hasPendingDuoFullscreenRestoration = false
        appDelegate.splitViewController?.updateDuoEmptyReaderProtection(for: self)
        duoPreviousSplitBehavior = nil
        if let previous = duoPreviousPresentsWithGesture {
            appDelegate.splitViewController?.presentsWithGesture = previous
        }
        duoPreviousPresentsWithGesture = nil
        if let previous = duoPreviousDisplayModeButtonVisibility {
            appDelegate.splitViewController?.displayModeButtonVisibility = previous
        }
        duoPreviousDisplayModeButtonVisibility = nil
        // DetailViewController.swift owns Discovery even while its preview reader is visible.
        if #available(iOS 15.0, *), let controller = retainedDiscoveryController as? DiscoverSitesViewController {
            controller.resetForAccountChange()
        }
        dismissDiscoverSites()
    }

    private func updateDiscoveryPaneTheme() {
        guard let navigation = discoveryPaneNavigationController else { return }
        ThemeManager.shared?.update(navigation)
        // DetailViewController.swift colors both navigation roots where the status-bar safe area is exposed.
        let color = navigation.navigationBar.backgroundColor ?? navigation.navigationBar.barTintColor
        navigation.view.backgroundColor = color
        navigationController?.view.backgroundColor = color
        discoveryStatusBarBackground?.backgroundColor = color
    }

    @objc func dismissDiscoverSites() {
        let hadDiscovery = retainedDiscoveryController != nil
        unmountDiscoveryPane()
        if let controller = retainedDiscoveryController { removeFromFeedsNavigation(viewController: controller) }
        retainedDiscoveryController = nil
        discoveryPreviewActive = false
        navigationItem.leftBarButtonItems?.removeAll { $0.accessibilityIdentifier == "discover-preview-back" }
        feedDetailViewController?.navigationItem.leftBarButtonItems?.removeAll { $0.accessibilityIdentifier == "discover-preview-back" }
        if hadDiscovery, !isPhoneOrCompact, topContainerView != nil { checkViewControllers() }
    }

    @objc func discoverSitesDidAppear(_ controller: UIViewController) {
        guard retainedDiscoveryController === controller, isDiscoverSitesVisible else { return }
        // DetailViewController.swift also observes the native compact Back gesture, not just its explicit return button.
        discoveryPreviewActive = false
        appDelegate.feedsViewController?.highlightDiscoverySelection()
    }

    @objc func beginDiscoverPreview() {
        guard retainedDiscoveryController != nil else { return }
        discoveryPreviewActive = true
        unmountDiscoveryPane()
        if !isPhoneOrCompact, topContainerView != nil { checkViewControllers() }
        addDiscoverPreviewBackButton()
    }

    @objc func returnToDiscoverSites() {
        guard let controller = retainedDiscoveryController else { return }
        discoveryPreviewActive = false
        appDelegate.feedsViewController?.highlightDiscoverySelection()
        if isPhoneOrCompact {
            appDelegate.feedsNavigationController.popToViewController(controller, animated: true)
        } else {
            mountDiscoveryPane(controller)
        }
    }

    @objc func addDiscoverPreviewBackButton() {
        guard canReturnToDiscoverSites, !isPhoneOrCompact else { return }
        let button = UIBarButtonItem(title: "Discover", style: .plain, target: self, action: #selector(returnToDiscoverSites))
        button.accessibilityIdentifier = "discover-preview-back"
        var items = feedDetailNavigationItem.leftBarButtonItems ?? []
        items.removeAll { $0.accessibilityIdentifier == button.accessibilityIdentifier }
        feedDetailNavigationItem.leftBarButtonItems = [button] + items
    }
    /// Preference keys.
    enum Key {
        /// Style of the feed detail list layout.
        static let style = "story_titles_style"
        
        /// Behavior of the split controller.
        static let behavior = "split_behavior"

        static func duoFullscreenReader(forAccount username: String) -> String {
            "duo_fullscreen_reader.\(username)"
        }
        
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
            // DetailViewController.swift keeps source preferences intact while fullscreen uses a primary titles overlay.
            if duoFullscreenRequested && supportsDuoFullscreenLayout { return .left }
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
    @objc var isCompact = false {
        didSet { hasResolvedSplitLayout = true }
    }

    private var hasResolvedSplitLayout = false

    /// Whether the reader uses a single navigation stack, including a closed regular-width-capable phone.
    @objc var isPhoneOrCompact: Bool {
        // DetailViewController.swift preserves conventional landscape-phone navigation while Duo's native side bar identifies an in-progress fold handoff.
        if isPhone, traitCollection.verticalSizeClass == .compact,
           !Utilities.usesSystemVerticalBar(traitCollection) {
            return true
        }
        // DetailViewController.swift trusts split callbacks while UIKit is still updating the child traits.
        if hasResolvedSplitLayout { return isCompact }
        let horizontalSizeClass = splitViewController?.traitCollection.horizontalSizeClass
            ?? viewIfLoaded?.window?.windowScene?.traitCollection.horizontalSizeClass
            ?? traitCollection.horizontalSizeClass
        return horizontalSizeClass == .compact || (isPhone && horizontalSizeClass != .regular)
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
    
    /// The split controller behavior for the current reader presentation.
    @objc var behaviorString: String {
        let preference = UserDefaults.standard.string(forKey: Key.behavior) ?? BehaviorValue.auto
        // DetailViewController.swift gives expanded phones the two-column iPad portrait reader without rewriting preferences.
        if isPhone, !isPhoneOrCompact, preference == BehaviorValue.auto || preference == BehaviorValue.tile {
            return BehaviorValue.displace
        }
        return preference
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
        if isPhoneOrCompact || isDuoFullscreenReader {
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
    private var expandedFeedsReveal: (id: UUID, behavior: String)?
    private var fullscreenSidebarSupplementaryNavigationController: UINavigationController?
    private weak var fullscreenSidebarOverlayFeedDetailController: FeedDetailViewController?
    private var duoFullscreenRequested = false
    private var isUpdatingDuoFullscreenSidebar = false
    private var duoPreviousSplitBehavior: UISplitViewController.SplitBehavior?
    private var duoPreviousPresentsWithGesture: Bool?
    private var duoPreviousDisplayModeButtonVisibility: UISplitViewController.DisplayModeButtonVisibility?
    private var hasPendingDuoFullscreenRestoration = false

    private var supportsDuoFullscreenLayout: Bool {
        isPhone && !isPhoneOrCompact && appDelegate.splitViewController?.style == .doubleColumn && !isDiscoverSitesVisible
    }

    @objc var canToggleDuoFullscreenReader: Bool {
        supportsDuoFullscreenLayout && (duoFullscreenRequested || storyTitlesOnLeft)
    }

    @objc var isDuoFullscreenReader: Bool { duoFullscreenRequested && canToggleDuoFullscreenReader }
    @objc var isBrowsingDuoSources: Bool {
        supportsDuoFullscreenLayout && !isDuoFullscreenReader && storyTitlesOnLeft &&
            !hasVisibleStoryForSidebarLayout
    }
    @objc var preservesExpandedFeedsReveal: Bool {
        supportsDuoFullscreenLayout && !isDuoFullscreenReader && storyTitlesOnLeft && isFeedShown &&
            expandedFeedsReveal?.behavior == behaviorString
    }
    @objc var isBrowsingDuoFullscreenSources: Bool {
        isDuoFullscreenReader && fullscreenSidebarPresentationState != .fullscreen
    }

    @objc var requiresDuoFullscreenSidebar: Bool {
        isDuoFullscreenReader && !hasVisibleStoryForSidebarLayout
    }

    @objc(restoreDuoFullscreenReaderForAccount:)
    func restoreDuoFullscreenReader(forAccount username: String?) -> Bool {
        guard isPhone, appDelegate.splitViewController?.style == .doubleColumn,
              let username, !username.isEmpty,
              UserDefaults.standard.bool(forKey: Key.duoFullscreenReader(forAccount: username)) else { return false }
        // DetailViewController.swift restores only the account's layout preference; cold launch starts at Feeds without an article.
        duoPreviousSplitBehavior = appDelegate.splitViewController?.preferredSplitBehavior
        duoPreviousPresentsWithGesture = appDelegate.splitViewController?.presentsWithGesture
        duoPreviousDisplayModeButtonVisibility = appDelegate.splitViewController?.displayModeButtonVisibility
        duoFullscreenRequested = true
        fullscreenSidebarPresentationState = .feeds
        hasPendingDuoFullscreenRestoration = true
        completeDuoFullscreenRestorationIfNeeded()
        return isDuoFullscreenReader
    }

    private func completeDuoFullscreenRestorationIfNeeded() {
        guard hasPendingDuoFullscreenRestoration, isDuoFullscreenReader,
              viewIfLoaded?.window != nil else { return }
        hasPendingDuoFullscreenRestoration = false
        guard !hasVisibleStoryForSidebarLayout, !isFeedShown,
              appDelegate.pendingNotificationStory == nil, appDelegate.pendingDailyBriefingStoryHash == nil,
              !appDelegate.inFindingStoryMode, appDelegate.tryFeedFeedId == nil else { return }
        // DetailViewController.swift reveals restored Feeds once attached, after UIKit's initial secondary-only callback, without overriding an explicit destination.
        applyDuoFullscreenSidebar(.feeds, animated: false)
    }

    // DetailViewController.swift keeps Duo's primary navigation independent of the retained secondary reader.
    @objc(showDuoFullscreenFeeds:) func showDuoFullscreenFeeds(_ sender: Any?) {
        applyDuoFullscreenSidebar(.feeds, animated: true)
    }

    @objc func updateDuoFullscreenSplitBehavior() {
        guard isDuoFullscreenReader, let split = appDelegate.splitViewController else { return }
        let mode: UISplitViewController.DisplayMode = fullscreenSidebarPresentationState == .fullscreen ? .secondaryOnly : .oneOverSecondary
        if split.preferredDisplayMode != mode { split.preferredDisplayMode = mode }
        if split.preferredSplitBehavior != .overlay { split.preferredSplitBehavior = .overlay }
        // DetailViewController.swift already provides Sidebar in the native reader rail; enabling gestures must not add another button over the article.
        split.displayModeButtonVisibility = .never
        split.presentsWithGesture = !requiresDuoFullscreenSidebar
        feedDetailViewController?.updateDuoFullscreenSidebarGestures()
        split.updateDuoEmptyReaderProtection(for: self)
    }

    private var hasSelectedDuoSidebarSource: Bool {
        appDelegate.storiesCollection?.activeFeed != nil || appDelegate.storiesCollection?.activeFolder != nil
    }

    private func mountDuoFullscreenTitles() {
        // DetailViewController.swift keeps the native overlay rooted at Feeds until there is a source for its story list.
        guard isDuoFullscreenReader, hasSelectedDuoSidebarSource, let titles = feedDetailViewController,
              let feeds = appDelegate.feedsViewController,
              let navigation = appDelegate.feedsNavigationController else { return }
        if titles.parent !== navigation {
            remove(viewController: titles)
        }
        if navigation.topViewController !== titles {
            navigation.setViewControllers([feeds, titles], animated: false)
        }
        navigation.setNavigationBarHidden(false, animated: false)
        titles.navigationItem.titleView = appDelegate.makeFeedTitle(appDelegate.storiesCollection.activeFeed)
    }

    private func applyDuoFullscreenSidebar(_ requestedPresentation: FullscreenSidebarPresentation, animated: Bool) {
        guard isDuoFullscreenReader, !isUpdatingDuoFullscreenSidebar,
              let split = appDelegate.splitViewController else { return }
        let presentation: FullscreenSidebarPresentation
        if requestedPresentation == .fullscreen && requiresDuoFullscreenSidebar {
            presentation = hasSelectedDuoSidebarSource ? .storyTitles : .feeds
        } else if requestedPresentation == .storyTitles && !hasSelectedDuoSidebarSource {
            presentation = .feeds
        } else {
            presentation = requestedPresentation
        }
        hasPendingDuoFullscreenRestoration = false
        isUpdatingDuoFullscreenSidebar = true
        defer { isUpdatingDuoFullscreenSidebar = false }
        if presentation != .fullscreen {
            appDelegate.trainerViewController?.captureRetainedStoryContext()
        }
        fullscreenSidebarPresentationState = presentation
        restoreReaderBesideStoryTitles()
        if presentation == .storyTitles {
            mountDuoFullscreenTitles()
        } else if presentation == .feeds {
            appDelegate.feedsNavigationController.popToRootViewController(animated: animated)
        }
        setStoryTitlesCollapsed(true, animated: false)
        updateDuoFullscreenSplitBehavior()
        let change = {
            if presentation == .fullscreen {
                split.hide(.primary)
            }
            else { split.show(.primary) }
        }
        if animated { change() } else { UIView.performWithoutAnimation(change) }
        feedDetailViewController?.updateSidebarButton(for: split.displayMode)
        storyPagesViewController?.updateStoryTitleNavigationButtons()
        storyPagesViewController?.viewIfLoaded?.setNeedsLayout()
        navigationController?.view.setNeedsLayout()
    }

    private func toggleDuoFullscreenReader() {
        // DetailViewController.swift animates the existing reader host rather than replacing its loaded document during the column change.
        view.layoutIfNeeded()
        UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.25,
                       delay: 0, options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut]) {
            self.applyDuoFullscreenReaderToggle()
            self.view.layoutIfNeeded()
        }
    }

    private func applyDuoFullscreenReaderToggle() {
        hasPendingDuoFullscreenRestoration = false
        expandedFeedsReveal = nil
        if !duoFullscreenRequested {
            duoPreviousSplitBehavior = appDelegate.splitViewController?.preferredSplitBehavior
            duoPreviousPresentsWithGesture = appDelegate.splitViewController?.presentsWithGesture
            duoPreviousDisplayModeButtonVisibility = appDelegate.splitViewController?.displayModeButtonVisibility
        }
        duoFullscreenRequested.toggle()
        if let username = appDelegate.activeUsername, !username.isEmpty {
            UserDefaults.standard.set(duoFullscreenRequested, forKey: Key.duoFullscreenReader(forAccount: username))
        }
        if isDuoFullscreenReader {
            fullscreenSidebarPresentationState = .fullscreen
            mountDuoFullscreenTitles()
            applyDuoFullscreenSidebar(.fullscreen, animated: true)
        } else {
            if let split = appDelegate.splitViewController {
                split.preferredDisplayMode = .secondaryOnly
                if let behavior = duoPreviousSplitBehavior { split.preferredSplitBehavior = behavior }
                split.hide(.primary)
            }
            duoPreviousSplitBehavior = nil
            fullscreenSidebarPresentationState = .storyTitles
            if storyTitlesOnLeft {
                if let titles = feedDetailViewController { add(viewController: titles, to: leftContainerView, compactPush: false) }
                setStoryTitlesCollapsed(false, animated: false)
            } else {
                checkViewControllers()
            }
            navigationItem.titleView = appDelegate.makeFeedTitle(appDelegate.storiesCollection.activeFeed)
            feedDetailViewController?.updateDuoFullscreenSidebarGestures()
            if let previous = duoPreviousPresentsWithGesture {
                appDelegate.splitViewController?.presentsWithGesture = previous
            }
            duoPreviousPresentsWithGesture = nil
            if let previous = duoPreviousDisplayModeButtonVisibility {
                appDelegate.splitViewController?.displayModeButtonVisibility = previous
            }
            duoPreviousDisplayModeButtonVisibility = nil
            appDelegate.splitViewController?.updateDuoEmptyReaderProtection(for: self)
            feedDetailViewController?.updateSidebarButton(for: appDelegate.splitViewController.displayMode)
            storyPagesViewController?.updateStoryTitleNavigationButtons()
            storyPagesViewController?.viewIfLoaded?.setNeedsLayout()
            navigationController?.view.setNeedsLayout()
        }
    }

    @objc var areStoryTitlesCollapsed: Bool {
        guard storyTitlesOnLeft, !isPhoneOrCompact else {
            return false
        }
        if isDuoFullscreenReader { return true }

        if !tiledFeedTitlesConstraints.isEmpty { return false }

        if shouldUseNativeFullscreenSidebarOverlay {
            return fullscreenSidebarPresentationState == .fullscreen
        }

        return leftContainerView.isHidden || verticalDividerViewLeadingConstraint.constant <= 0
    }

    @objc var isUsingNativeFullscreenSidebar: Bool {
        isDuoFullscreenReader || shouldUseNativeFullscreenSidebarOverlay
    }

    @objc var fullscreenSidebarPresentation: FullscreenSidebarPresentation {
        fullscreenSidebarPresentationState
    }

    /// Whether the detail is in temporary full-screen mode (overriding the column layout).
    @objc var isTemporaryFullScreen = false

    /// The display mode to restore when exiting temporary full-screen.
    private var preFullScreenDisplayMode: UISplitViewController.DisplayMode?
    private var preFullScreenSplitBehavior: UISplitViewController.SplitBehavior?

    @objc var hasVisibleStoryForSidebarLayout: Bool {
        appDelegate.activeStory != nil || currentStoryController?.activeStory != nil
    }

    private var shouldShowStoryInCompactNavigation: Bool {
        hasVisibleStoryForSidebarLayout || isStoryShown
    }

    private struct CompactCollapseRestoration {
        let generation: UInt
        let collection: StoriesCollection
        let feedID: String?
        let folder: String?
        let fetchID: UInt
        let showFeed: Bool
        let showStory: Bool
        let page: StoryDetailViewController?
        let storyHash: String?
        let story: [AnyHashable: Any]?
    }
    private var compactCollapseGeneration: UInt = 0
    private var pendingCompactCollapseRestoration: CompactCollapseRestoration?

    func beginCompactNavigationRestoration(showFeed: Bool, showStory: Bool) -> UInt {
        cancelCompactNavigationRestoration()
        guard let collection = appDelegate.storiesCollection else { return compactCollapseGeneration }
        let page = currentStoryController
        let story = appDelegate.activeStory ?? (page?.activeStory as? [AnyHashable: Any])
        pendingCompactCollapseRestoration = CompactCollapseRestoration(
            generation: compactCollapseGeneration, collection: collection,
            feedID: collection.activeFeed?["id"].map { String(describing: $0) },
            folder: collection.activeFolder, fetchID: feedDetailViewController?.fetchRequestId ?? 0,
            showFeed: showFeed, showStory: showStory, page: page,
            storyHash: story?["story_hash"] as? String, story: story
        )
        return compactCollapseGeneration
    }

    @objc func cancelCompactNavigationRestoration() {
        compactCollapseGeneration &+= 1
        pendingCompactCollapseRestoration = nil
    }

    private func isCurrentCompactCollapse(_ restoration: CompactCollapseRestoration) -> Bool {
        guard restoration.generation == compactCollapseGeneration,
              restoration.collection === appDelegate.storiesCollection,
              restoration.feedID == appDelegate.storiesCollection.activeFeed?["id"].map({ String(describing: $0) }),
              restoration.folder == appDelegate.storiesCollection.activeFolder,
              restoration.fetchID == (feedDetailViewController?.fetchRequestId ?? 0),
              !isDiscoverSitesVisible else { return false }
        guard restoration.showStory else { return true }
        guard let page = restoration.page, currentStoryController === page,
              let hash = restoration.storyHash, page.activeStoryId == hash else { return false }
        // DetailViewController.swift tolerates only the transient nil selection cleared by compact titles appearance.
        let activeHash = appDelegate.activeStory?["story_hash"] as? String
        return activeHash == nil || activeHash == hash
    }

    @objc func preservesArticleDuringSplitCollapse(_ article: StoryDetailViewController) -> Bool {
        guard let restoration = pendingCompactCollapseRestoration,
              restoration.showStory, restoration.page === article else { return false }
        return isCurrentCompactCollapse(restoration)
    }

    func completeCompactNavigationRestoration(generation: UInt, split: UISplitViewController) {
        // DetailViewController.swift waits until UIKit's DidCollapse callback has returned from its final stack mutation.
        DispatchQueue.main.async { [weak self, weak split] in
            guard let self, let split,
                  let restoration = self.pendingCompactCollapseRestoration,
                  restoration.generation == generation else { return }
            guard self.isCompact, split.isCollapsed, self.isCurrentCompactCollapse(restoration) else {
                self.cancelCompactNavigationRestoration()
                return
            }
            if restoration.showStory && self.appDelegate.activeStory == nil {
                self.appDelegate.activeStory = restoration.story
            }
            self.restoreCompactNavigationAfterSplitCollapse(showFeed: restoration.showFeed, showStory: restoration.showStory)
            self.cancelCompactNavigationRestoration()
        }
    }
    
    /// Moves the feed detail and story pages (as appropriate) onto the feeds navigation stack. Called when collapsing to a compact size class.
    func collapseToSingleColumn() {
        expandedFeedsReveal = nil
        let discoveryWasVisible = isDiscoverSitesVisible
        unmountDiscoveryPane()
        isCompact = true
        if let controller = retainedDiscoveryController {
            var controllers: [UIViewController] = [appDelegate.feedsViewController, controller]
            if !discoveryWasVisible {
                if let feedDetailViewController {
                    remove(viewController: feedDetailViewController)
                    controllers.append(feedDetailViewController)
                }
                if shouldShowStoryInCompactNavigation, let storyPagesViewController {
                    remove(viewController: storyPagesViewController)
                    controllers.append(storyPagesViewController)
                }
            }
            appDelegate.feedsNavigationController.setViewControllers(controllers, animated: false)
            if discoveryWasVisible { return }
        }
        
        checkViewControllers()
    }

    func restoreCompactNavigationAfterSplitCollapse(showFeed: Bool, showStory: Bool) {
        guard !isDiscoverSitesVisible else { return }
        guard isCompact, showFeed || showStory else {
            return
        }

        guard let nav = appDelegate.feedsNavigationController,
              let feedsViewController = appDelegate.feedsViewController else {
            return
        }

        var controllers = discoveryNavigationPrefix(in: nav) ?? [feedsViewController]

        if (showFeed || showStory), let feedDetailViewController {
            if feedDetailViewController.parent !== nav {
                remove(viewController: feedDetailViewController)
            }
            controllers.append(feedDetailViewController)
        }

        if showStory, let storyPagesViewController {
            if storyPagesViewController.parent !== nav {
                remove(viewController: storyPagesViewController)
            }
            controllers.append(storyPagesViewController)
        }

        let currentControllers = nav.viewControllers.map { ObjectIdentifier($0) }
        let desiredControllers = controllers.map { ObjectIdentifier($0) }
        if currentControllers != desiredControllers {
            nav.setViewControllers(controllers, animated: false)
        }

        if showStory, let storyPagesViewController {
            refreshRestoredStoryPageWhenLaidOut(storyPagesViewController)
        }
    }

    private func refreshRestoredStoryPageWhenLaidOut(_ storyPagesViewController: StoryPagesViewController, attempt: Int = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self, weak storyPagesViewController] in
            guard let self, self.isCompact, let storyPagesViewController,
                  let navigation = self.appDelegate.feedsNavigationController,
                  storyPagesViewController.parent === navigation,
                  navigation.topViewController === storyPagesViewController else {
                return
            }

            navigation.view.setNeedsLayout()
            navigation.view.layoutIfNeeded()
            storyPagesViewController.view.setNeedsLayout()
            storyPagesViewController.view.layoutIfNeeded()

            let hasUsableBounds = storyPagesViewController.view.bounds.width > 0 && storyPagesViewController.view.bounds.height > 0
            if !hasUsableBounds && attempt < 20 {
                self.refreshRestoredStoryPageWhenLaidOut(storyPagesViewController, attempt: attempt + 1)
                return
            }

            storyPagesViewController.updatePage(
                withActiveStory: self.appDelegate.storiesCollection.locationOfActiveStory(),
                updateFeedDetail: false
            )
            storyPagesViewController.refreshPages()
            storyPagesViewController.reorientPages()
            storyPagesViewController.currentPage.view.isHidden = false
        }
    }
    
    /// Moves the feed detail and story pages (as appropriate) to the detail view. Called when expanding to a regular size class.
    func expandToTwoColumns() {
        cancelCompactNavigationRestoration()
        if let controller = retainedDiscoveryController,
           discoveryPaneNavigationController == nil,
           !appDelegate.feedsNavigationController.viewControllers.contains(where: { $0 === controller }) {
            // DetailViewController.swift must inspect the compact stack before expansion removes it.
            // Native Back can dismiss Discover without going through dismissDiscoverSites().
            dismissDiscoverSites()
        }
        isCompact = false
        let discoveryWasVisible = isDiscoverSitesVisible
        if isDuoFullscreenReader {
            let top = appDelegate.feedsNavigationController.topViewController
            fullscreenSidebarPresentationState = top === appDelegate.feedsViewController ? .feeds :
                (top === feedDetailViewController ? .storyTitles : .fullscreen)
        }
        appDelegate.feedsNavigationController.popToRootViewController(animated: false)
        if discoveryWasVisible, let controller = retainedDiscoveryController {
            mountDiscoveryPane(controller)
            return
        }
        
        checkViewControllers()
        addDiscoverPreviewBackButton()
    }

    private func discoveryNavigationPrefix(in navigation: UINavigationController) -> [UIViewController]? {
        // DetailViewController.swift retains the live discovery screen while preview readers move between columns.
        guard #available(iOS 15.0, *),
              let index = navigation.viewControllers.lastIndex(where: { $0 is DiscoverSitesViewController }) else {
            return nil
        }
        return Array(navigation.viewControllers.prefix(through: index))
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
        updateDiscoveryPaneTheme()
        if #available(iOS 15.0, *), let discovery = retainedDiscoveryController as? DiscoverSitesViewController {
            discovery.updateTheme()
        }
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
            add(viewController: storyPagesViewController, to: appropriateContainerView, compactPush: shouldShowStoryInCompactNavigation)
            
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
        if column == .secondary { expandedFeedsReveal = nil }
        if isDuoFullscreenReader {
            if column == .primary { applyDuoFullscreenSidebar(.feeds, animated: animated) }
            return
        }
        if isCompact {
            if column == .primary {
                cancelCompactNavigationRestoration()
                appDelegate.feedsNavigationController.popToRootViewController(animated: animated)
            } else {
                if !shouldShowStoryInCompactNavigation {
                    removeFromFeedsNavigation(viewController: storyPagesViewController)
                }

                // DetailViewController.swift keeps discovery or other source screens beneath the reader.
                if isFeedShown, let feedDetailViewController,
                   !appDelegate.feedsNavigationController.viewControllers.contains(where: { $0 === feedDetailViewController }) {
                    remove(viewController: feedDetailViewController)
                    appDelegate.feedsNavigationController.pushViewController(feedDetailViewController, animated: animated)
                }
                
                if shouldShowStoryInCompactNavigation, let storyPagesViewController,
                   !appDelegate.feedsNavigationController.viewControllers.contains(where: { $0 === storyPagesViewController }) {
                    remove(viewController: storyPagesViewController)
                    appDelegate.feedsNavigationController.pushViewController(storyPagesViewController, animated: animated)
                }
            }
        } else {
            guard let splitViewController = appDelegate.splitViewController else {
                return
            }
            
            if column == .primary {
                if supportsDuoFullscreenLayout && storyTitlesOnLeft && isFeedShown {
                    expandedFeedsReveal = (UUID(), behaviorString)
                }
                rememberReaderWidthBeforeTiledFeeds()
                // DetailViewController.swift must not queue secondaryOnly while explicitly revealing the primary column.
                var preferredBehavior: UISplitViewController.SplitBehavior
                if isDiscoverSitesVisible || isBrowsingDuoSources {
                    preferredBehavior = .tile
                } else if !storyTitlesOnLeft {
                    preferredBehavior = behavior == .overlay ? .overlay : .displace
                } else {
                    let size = splitViewController.view.bounds.size
                    switch StorySplitBehaviorDecision.preferredBehavior(
                        for: behaviorString,
                        width: size.width,
                        height: size.height,
                        isMac: appDelegate.isMac
                    ) {
                    case .tile: preferredBehavior = .tile
                    case .overlay: preferredBehavior = .overlay
                    case .displace: preferredBehavior = .displace
                    }
                }

                // DetailViewController.swift uses an overlay because a double-column split cannot displace its secondary.
                // Tiling Feeds would squeeze the secondary's existing title and article panes into three columns.
                if isPhone, splitViewController.style == .doubleColumn, preferredBehavior == .displace {
                    preferredBehavior = .overlay
                }

                // DetailViewController.swift cancels a pending layout hide even when UIKit still reports the primary as visible.
                let hasSupplementaryColumn = splitViewController.style == .tripleColumn
                switch preferredBehavior {
                case .tile:
                    splitViewController.preferredDisplayMode = hasSupplementaryColumn ? .twoBesideSecondary : .oneBesideSecondary
                case .overlay:
                    splitViewController.preferredDisplayMode = hasSupplementaryColumn ? .twoOverSecondary : .oneOverSecondary
                default:
                    splitViewController.preferredDisplayMode = hasSupplementaryColumn ? .twoDisplaceSecondary : .oneBesideSecondary
                }
                // DetailViewController.swift applies behavior last because UIKit infers tile when setting oneBesideSecondary.
                splitViewController.preferredSplitBehavior = preferredBehavior
            }

            if column == .secondary, showsStoryTitlesBesideTiledFeeds {
                revealsStoryTitlesAfterTiledFeeds = true
                splitViewController.hide(.primary)
            }
            splitViewController.show(column)
            updateResolvedFeedSidebarLayout()
        }
    }

    @objc var showsStoryTitlesBesideTiledFeeds: Bool {
        if isDuoFullscreenReader { return false }
        guard let split = appDelegate.splitViewController else { return false }
        return StorySplitBehaviorDecision.shouldShowStoryTitlesBesideTiledFeeds(
            isPhone: isPhone, isCompact: isPhoneOrCompact,
            isDoubleColumn: split.style == .doubleColumn,
            isDiscoverSitesVisible: isDiscoverSitesVisible, storyTitlesOnLeft: storyTitlesOnLeft,
            displayMode: splitPreferredDisplayMode(for: split.displayMode)
        )
    }

    private var revealsStoryTitlesAfterTiledFeeds = false
    private var tiledFeedOriginalConstraints: [NSLayoutConstraint] = []
    private var tiledFeedTitlesConstraints: [NSLayoutConstraint] = []
    private var tiledFeedReaderWasHidden = false
    private var lastReadingColumnWidth: CGFloat = 0

    private func rememberReaderWidthBeforeTiledFeeds() {
        guard tiledFeedTitlesConstraints.isEmpty, let reader = topContainerView,
              !reader.isHidden, reader.bounds.width > 0 else { return }
        lastReadingColumnWidth = reader.bounds.width
    }

    private func showTitlesBesideTiledFeeds() {
        guard let titles = leftContainerView, let reader = topContainerView,
              let divider = verticalDividerView else { return }
        let needsPresentationUpdate = tiledFeedTitlesConstraints.isEmpty || titles.isHidden || titles.alpha != 1 ||
            !divider.isHidden || divider.alpha != 0
        if tiledFeedTitlesConstraints.isEmpty {
            let originals = view.constraints.filter { constraint in
                guard constraint.isActive else { return false }
                let first = constraint.firstItem as? UIView
                let second = constraint.secondItem as? UIView
                let titlesToDivider = (first === titles && second === divider) || (first === divider && second === titles)
                let readerToDivider = (first === reader && second === divider) || (first === divider && second === reader)
                return (titlesToDivider || readerToDivider) &&
                    [.leading, .trailing].contains(constraint.firstAttribute) &&
                    [.leading, .trailing].contains(constraint.secondAttribute)
            }
            guard originals.count == 2 else { return }
            let readerWidth = lastReadingColumnWidth > 0 ? lastReadingColumnWidth : reader.bounds.width
            guard readerWidth > 0 else { return }
            tiledFeedReaderWasHidden = reader.isHidden
            reader.isHidden = true
            // DetailViewController.swift retains the original constraints and article viewport while titles fill the native secondary.
            tiledFeedOriginalConstraints = originals
            tiledFeedTitlesConstraints = [
                titles.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                reader.widthAnchor.constraint(equalToConstant: readerWidth)
            ]
            NSLayoutConstraint.deactivate(originals)
            NSLayoutConstraint.activate(tiledFeedTitlesConstraints)
        }
        guard needsPresentationUpdate else { return }
        titles.isHidden = false
        titles.alpha = 1
        divider.isHidden = true
        divider.alpha = 0
        appDelegate.feedDetailViewController.updateSidebarButton(for: appDelegate.splitViewController.displayMode)
        storyPagesViewController?.updateStoryTitleNavigationButtons()
        view.layoutIfNeeded()
        storyPagesViewController?.viewIfLoaded?.setNeedsLayout()
        storyPagesViewController?.viewIfLoaded?.layoutIfNeeded()
    }

    private func restoreReaderBesideStoryTitles() {
        guard !tiledFeedTitlesConstraints.isEmpty else { return }
        NSLayoutConstraint.deactivate(tiledFeedTitlesConstraints)
        NSLayoutConstraint.activate(tiledFeedOriginalConstraints)
        tiledFeedTitlesConstraints.removeAll()
        tiledFeedOriginalConstraints.removeAll()
        topContainerView.isHidden = tiledFeedReaderWasHidden
        appDelegate.feedDetailViewController.updateSidebarButton(for: appDelegate.splitViewController.displayMode)
        storyPagesViewController?.updateStoryTitleNavigationButtons()
        storyPagesViewController?.viewIfLoaded?.setNeedsLayout()
    }

    func updateResolvedFeedSidebarLayout() {
        guard isViewLoaded,
              leftContainerView != nil, verticalDividerView != nil,
              verticalDividerViewLeadingConstraint != nil else { return }
        if !showsStoryTitlesBesideTiledFeeds { restoreReaderBesideStoryTitles() }
        guard isPhone, !isPhoneOrCompact else { return }
        if revealsStoryTitlesAfterTiledFeeds, appDelegate.splitViewController.isFeedsListHidden {
            // DetailViewController.swift preserves an explicit title reveal across UIKit's pending sidebar dismissal.
            revealsStoryTitlesAfterTiledFeeds = false
            fullscreenSidebarPresentationState = .storyTitles
        }
        // DetailViewController.swift follows UIKit's resolved mode when a partial fold forces tiling despite an overlay preference.
        performStoryAutoCollapseIfNeeded()
    }

    @objc func collapseFeedListIfNeededForStory() {
        DispatchQueue.main.async {
            self.performStoryAutoCollapseIfNeeded()
        }
    }

    @objc func resetStoryTitlesRevealOverride() {
        // DetailViewController.swift ignores a legacy layout reset queued before fullscreen took ownership of the sidebar.
        guard !isDuoFullscreenReader, !preservesExpandedFeedsReveal, !isBrowsingDuoSources else { return }
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
        if isDuoFullscreenReader {
            applyDuoFullscreenSidebar(fullscreenSidebarPresentationState == .fullscreen ? .storyTitles : .fullscreen, animated: true)
            return
        }
        guard storyTitlesOnLeft, !isPhoneOrCompact else {
            return
        }

        if showsStoryTitlesBesideTiledFeeds {
            revealsStoryTitlesAfterTiledFeeds = true
            appDelegate.splitViewController.hide(.primary)
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
        if isDuoFullscreenReader { applyDuoFullscreenSidebar(.storyTitles, animated: true); return }
        guard storyTitlesOnLeft, !isPhoneOrCompact else {
            return
        }

        if showsStoryTitlesBesideTiledFeeds {
            revealsStoryTitlesAfterTiledFeeds = true
            appDelegate.splitViewController.hide(.primary)
            return
        }

        resetTemporaryFullScreenIfNeeded()

        let nextPresentation = FullscreenSidebarPresentationDecision.presentationAfterKeyboardReveal(
            fullscreenSidebarPresentationState
        )
        applyKeyboardSidebarPresentation(nextPresentation, sender: sender)
    }

    @objc(hideStoryTitlesFromKeyboard:) func hideStoryTitlesFromKeyboard(_ sender: Any?) {
        if isDuoFullscreenReader { applyDuoFullscreenSidebar(.fullscreen, animated: true); return }
        guard storyTitlesOnLeft, !isPhoneOrCompact else {
            return
        }

        let nextPresentation = FullscreenSidebarPresentationDecision.presentationAfterKeyboardHide(
            fullscreenSidebarPresentationState
        )
        applyKeyboardSidebarPresentation(nextPresentation, sender: sender)
    }

    @objc(revealStoryTitlesFromLeadingEdgeGesture:) func revealStoryTitlesFromLeadingEdgeGesture(_ sender: Any?) {
        if isDuoFullscreenReader { applyDuoFullscreenSidebar(.storyTitles, animated: true); return }
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

    @objc override func toggleTemporaryFullScreen(_ sender: Any?) {
        guard !isPhoneOrCompact else { return }
        if canToggleDuoFullscreenReader { toggleDuoFullscreenReader(); return }

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
        expandedFeedsReveal = nil
        if isDuoFullscreenReader { applyDuoFullscreenSidebar(.fullscreen, animated: true); return }
        if showsStoryTitlesBesideTiledFeeds {
            revealsStoryTitlesAfterTiledFeeds = true
            appDelegate.splitViewController.hide(.primary)
            return
        }
        let nextPresentation = FullscreenSidebarPresentationDecision.presentationAfterStorySelection(
            fullscreenSidebarPresentationState
        )

        guard shouldUseNativeFullscreenSidebarOverlay else {
            let size = view.bounds.size.width > 0 ? view.bounds.size : UIScreen.main.bounds.size
            let shouldCollapse = StoryAutoCollapseDecision.shouldCollapse(
                isPhone: isPhone && isPhoneOrCompact,
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
        expandedFeedsReveal = nil
        if isDuoFullscreenReader { applyDuoFullscreenSidebar(.storyTitles, animated: true); return }
        if isBrowsingDuoSources {
            // DetailViewController.swift keeps source browsing beside Feeds until a story is explicitly selected.
            appDelegate.updateSplitBehavior(false)
            return
        }
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
        if displayMode == .secondaryOnly { clearExpandedFeedsRevealAfterDismissal() }
        if isDuoFullscreenReader {
            if !isUpdatingDuoFullscreenSidebar {
                // DetailViewController.swift keeps source navigation available until a story selection gives the reader content.
                if displayMode == .secondaryOnly && !requiresDuoFullscreenSidebar {
                    fullscreenSidebarPresentationState = .fullscreen
                } else {
                    fullscreenSidebarPresentationState = hasSelectedDuoSidebarSource &&
                        appDelegate.feedsNavigationController.topViewController === feedDetailViewController ? .storyTitles : .feeds
                }
            }
            if displayMode == .secondaryOnly { prepareDuoTitlesAfterSidebarDismissal() }
            feedDetailViewController?.updateSidebarButton(for: displayMode)
            storyPagesViewController?.updateStoryTitleNavigationButtons()
            appDelegate.splitViewController?.updateDuoEmptyReaderProtection(for: self)
            return
        }
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

    private func prepareDuoTitlesAfterSidebarDismissal() {
        guard let split = appDelegate?.splitViewController else { return }
        // DetailViewController.swift prepares the next native edge reveal only after the primary has actually disappeared.
        let prepareTitles = { [weak self, weak split] in
            guard let self, let split, let app = self.appDelegate,
                  app.detailViewController === self, app.splitViewController === split,
                  let navigation = app.feedsNavigationController, let feeds = app.feedsViewController,
                  self.isDuoFullscreenReader, !self.isUpdatingDuoFullscreenSidebar,
                  self.fullscreenSidebarPresentationState == .fullscreen,
                  split.displayMode == .secondaryOnly,
                  navigation.topViewController === feeds else { return }
            self.mountDuoFullscreenTitles()
        }
        if let coordinator = split.transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { context in
                guard !context.isCancelled else { return }
                prepareTitles()
            }
        } else {
            DispatchQueue.main.async(execute: prepareTitles)
        }
    }

    private func clearExpandedFeedsRevealAfterDismissal() {
        guard let reveal = expandedFeedsReveal, let split = appDelegate.splitViewController else { return }
        // DetailViewController.swift receives willChange callbacks, so an outgoing or cancelled hide must not revoke a newer Feeds tap.
        let clearReveal = { [weak self, weak split] in
            guard let self, let split, self.appDelegate.splitViewController === split,
                  self.expandedFeedsReveal?.id == reveal.id,
                  split.displayMode == .secondaryOnly else { return }
            self.expandedFeedsReveal = nil
        }
        if let coordinator = split.transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { context in
                if !context.isCancelled { clearReveal() }
            }
        } else {
            DispatchQueue.main.async(execute: clearReveal)
        }
    }

    @objc(applyFullscreenSidebarPresentation:sender:)
    func applyFullscreenSidebarPresentation(
        _ presentation: FullscreenSidebarPresentation,
        sender: Any?
    ) {
        if isDuoFullscreenReader { applyDuoFullscreenSidebar(presentation, animated: true); return }
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
        guard !isDiscoverSitesVisible else { return }
        if isDuoFullscreenReader { setStoryTitlesCollapsed(true, animated: false); return }
        guard storyTitlesOnLeft else {
            let size = view.bounds.size.width > 0 ? view.bounds.size : UIScreen.main.bounds.size
            let shouldCollapse = StoryAutoCollapseDecision.shouldCollapse(
                isPhone: isPhone && isPhoneOrCompact,
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
            isPhone: isPhone && isPhoneOrCompact,
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
        if isDuoFullscreenReader { applyDuoFullscreenSidebar(presentation, animated: true); return }
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
                    // DetailViewController.swift reveals embedded titles below; only triple-column splits have a supplementary column.
                    if splitViewController.style == .tripleColumn {
                        splitViewController.show(.supplementary)
                    }
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

    private var isAdjustingStoryTitleColumns = false

    private func setStoryTitlesCollapsed(_ requestedCollapse: Bool, animated: Bool) {
        if !showsStoryTitlesBesideTiledFeeds { restoreReaderBesideStoryTitles() }
        guard storyTitlesOnLeft, !isPhoneOrCompact else {
            return
        }

        guard !isAdjustingStoryTitleColumns else { return }
        isAdjustingStoryTitleColumns = true
        defer { isAdjustingStoryTitleColumns = false }
        if showsStoryTitlesBesideTiledFeeds {
            showTitlesBesideTiledFeeds()
            return
        }
        let shouldCollapse = requestedCollapse
        let shouldAnimate = animated

        let collapsedLeadingConstant: CGFloat = 0
        let targetLeadingConstant = shouldCollapse ? collapsedLeadingConstant : verticalDividerPosition
        let targetAlpha: CGFloat = shouldCollapse ? 0 : 1

        guard verticalDividerViewLeadingConstraint.constant != targetLeadingConstant
                || leftContainerView.isHidden != shouldCollapse
                || verticalDividerView.isHidden != shouldCollapse
                || leftContainerView.alpha != targetAlpha
                || verticalDividerView.alpha != targetAlpha else {
            return
        }

        if !shouldCollapse {
            leftContainerView.isHidden = false
            verticalDividerView.isHidden = false
        }

        if shouldAnimate { view.layoutIfNeeded() }

        let animations = {
            self.verticalDividerViewLeadingConstraint.constant = targetLeadingConstant
            self.leftContainerView.alpha = targetAlpha
            self.verticalDividerView.alpha = targetAlpha
            // DetailViewController.swift makes the next tap follow the new layout as soon as its model frames change.
            self.appDelegate.feedDetailViewController.updateSidebarButton(for: self.appDelegate.splitViewController.displayMode)
            self.storyPagesViewController?.updateStoryTitleNavigationButtons()
            self.view.layoutIfNeeded()
            self.rememberReaderWidthBeforeTiledFeeds()
            self.storyPagesViewController?.viewIfLoaded?.layoutIfNeeded()
        }

        let completion: (Bool) -> Void = { _ in
            // DetailViewController.swift ignores an outgoing column animation after tiled Feeds has taken over the title pane.
            guard !self.showsStoryTitlesBesideTiledFeeds,
                  self.verticalDividerViewLeadingConstraint.constant == targetLeadingConstant,
                  self.leftContainerView.alpha == targetAlpha else { return }
            self.leftContainerView.isHidden = shouldCollapse
            self.verticalDividerView.isHidden = shouldCollapse
        }

        if shouldAnimate {
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
        completeDuoFullscreenRestorationIfNeeded()
        
        adjustTopConstraint()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        if self.verticalDividerView == nil {
            return
        }
        
        if [.left].contains(layout) {
            coordinator.animate { context in
                self.verticalDividerViewLeadingConstraint.constant = (self.isTemporaryFullScreen || self.isDuoFullscreenReader)
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
        if isDiscoverSitesVisible {
            // DetailViewController.swift keeps UIKit's navigation wrapper from covering the themed status area.
            if let background = discoveryStatusBarBackground {
                background.superview?.bringSubviewToFront(background)
            }
            return
        }

        if isPhone, !isPhoneOrCompact { adjustTopConstraint() }
        
        let currentFeedsWidth = splitViewController?.primaryColumnWidth ?? 320
        
        // DetailViewController.swift leaves Duo's remembered width to explicit primary-divider drags, not transient fold/layout clamps.
        if (splitViewController as? SplitViewController)?.preservesDuoSidebarWidth != true,
           currentFeedsWidth != feedsWidth {
            feedsWidth = currentFeedsWidth
        }
        performStoryAutoCollapseIfNeeded()
        if !showsStoryTitlesBesideTiledFeeds { rememberReaderWidthBeforeTiledFeeds() }
        storyPagesViewController?.updateStoryTitleNavigationButtons()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        if isPhone, !isPhoneOrCompact { adjustTopConstraint() }
    }
    
    private func adjustTopConstraint() {
        guard let topConstraint = topContainerTopConstraint else { return }
        // DetailViewController.swift stops adjusting the departed split column once compact navigation owns the reader.
        if isCompact, storyPagesViewController?.parent !== self {
            return
        }
        guard let window = view.window, let scene = window.windowScene else {
            return
        }

        if isPhone, !isPhoneOrCompact, storyTitlesOnLeft, !isDiscoverSitesVisible {
            // MainInterface.storyboard ties this host to the shared safe area; the article must not follow the left title bar's minimization.
            let protectedTop = window.bounds.minY + window.safeAreaInsets.top
            let articleTop = view.convert(CGPoint(x: window.bounds.minX, y: protectedTop), from: window).y
            let compensation = view.safeAreaLayoutGuide.layoutFrame.minY - articleTop
            if abs(topConstraint.constant - compensation) > 0.5 {
                topConstraint.constant = compensation
            }
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
        expandedFeedsReveal = nil
        if isDuoFullscreenReader { applyDuoFullscreenSidebar(.fullscreen, animated: animated); return }
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
        guard isViewLoaded else {
            return
        }
        if !showsStoryTitlesBesideTiledFeeds { restoreReaderBesideStoryTitles() }
        if isDiscoverSitesVisible { return }

        let isTop = layout == .top
        
#if targetEnvironment(macCatalyst)
        splitViewController?.primaryBackgroundStyle = .sidebar
        splitViewController?.minimumPrimaryColumnWidth = 250
        splitViewController?.maximumPrimaryColumnWidth = 700
        splitViewController?.preferredPrimaryColumnWidth = feedsWidth
#endif
        
        if isCompact, let feedDetailViewController {
            if !shouldShowStoryInCompactNavigation {
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
            // MainInterface.storyboard has a 5-point divider and 1-point gap; this keeps the reader at the host's bottom edge.
            horizontalDividerViewBottomConstraint.constant = -6
            wasGridView = true
        } else if layout == .left {
            if feedDetailViewController == nil {
                addResetFeedDetail(to: leftContainerView)
            } else if !isDuoFullscreenReader && feedDetailViewController?.view.superview != leftContainerView {
                add(viewController: feedDetailViewController, to: leftContainerView, compactPush: isFeedShown)
            }
            
            if wasGridView && !isPhoneOrCompact {
                DispatchQueue.main.async {
                    self.appDelegate.loadStoryDetailView()
                }
            }
            
            if isDuoFullscreenReader && fullscreenSidebarPresentationState != .feeds { mountDuoFullscreenTitles() }
            verticalDividerViewLeadingConstraint.constant = (isTemporaryFullScreen || isDuoFullscreenReader) ? 0 : verticalDividerPosition
            if isTemporaryFullScreen || isDuoFullscreenReader {
                leftContainerView.alpha = 0
                leftContainerView.isHidden = true
                verticalDividerView.alpha = 0
                verticalDividerView.isHidden = true
            }
            horizontalDividerViewBottomConstraint.constant = -6
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
        
        if !storyTitlesInGridView, isCompact, shouldShowStoryInCompactNavigation {
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
            // DetailViewController.swift completes the departing navigation handoff before mounting the expanded column.
            remove(viewController: viewController)
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
        viewController.viewIfLoaded?.removeFromSuperview()
        viewController.removeFromParent()
        // DetailViewController.swift returns root-view sizing to UIKit after removing the old column's constraints.
        viewController.viewIfLoaded?.translatesAutoresizingMaskIntoConstraints = true
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
        guard SplitCollapseColumnDecision.shouldResetControllers(
            compactStateChanged: isCompact != wasCompact,
            hasFeed: isFeedShown || feedDetailViewController?.isFeedShown == true,
            hasStory: hasVisibleStoryForSidebarLayout || isStoryShown
        ) else {
            return
        }

        feedDetailViewController = nil

        listStoryPagesViewController = StoryPagesViewController()
        gridStoryPagesViewController = StoryPagesViewController()
    }

    /// The status bar portion of the navigation controller isn't the right color, due to a white subview bleeding through the visual effect view. This somewhat hacky function will correct that.
    func tidyNavigationController() {
        guard let visualEffectSubviews = navigationController?.navigationBar.subviews.first?.subviews.first?.subviews, visualEffectSubviews.count == 3, visualEffectSubviews[1].alpha == 1 else {
            return
        }
        
        navigationController?.navigationBar.subviews.first?.backgroundColor = UINavigationBar.appearance().backgroundColor
    }
}
