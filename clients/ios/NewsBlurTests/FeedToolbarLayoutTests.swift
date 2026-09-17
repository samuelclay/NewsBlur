import XCTest
import UIKit

@testable import NewsBlur

@MainActor final class Test_FeedToolbarLayout: XCTestCase {
    func test_livePhoneLandscapeNavigationUsesCompactHeader() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Requires the physical SE landscape safe area")
        #else
        guard Bundle.main.bundleIdentifier == "com.newsblur.NB-Alpha", UIDevice.current.userInterfaceIdiom == .phone else {
            throw XCTSkip("Requires NB Alpha on iPhone")
        }
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        app.showFeedsList(animated: false)
        let feeds = try XCTUnwrap(app.feedsViewController)
        let window = try XCTUnwrap(feeds.view.window)
        let scene = try XCTUnwrap(window.windowScene)
        let portraitBarHeight = feeds.navigationController?.navigationBar.bounds.height ?? 0
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeLeft))
        defer { scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) }
        for _ in 0..<40 {
            if scene.interfaceOrientation.isLandscape { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        try await Task.sleep(nanoseconds: 700_000_000)
        let nav = try XCTUnwrap(feeds.navigationController)
        let visibleBar = nav.view.subviews.compactMap { $0 as? UINavigationBar }.first { !$0.isHidden } ?? nav.navigationBar
        let bar = visibleBar.convert(visibleBar.bounds, to: window)
        print("LANDSCAPE_BAR sizing=\(nav.navigationBar.sizeThatFits(nav.view.bounds.size)) intrinsic=\(nav.navigationBar.intrinsicContentSize) safe=\(nav.navigationBar.safeAreaInsets) margins=\(nav.navigationBar.layoutMargins) class=\(type(of: nav.navigationBar))")
        let contentTop = feeds.view.convert(feeds.view.bounds, to: window).minY + feeds.view.safeAreaInsets.top
        print("LANDSCAPE_CONTENT top=\(contentTop) view=\(feeds.view.frame) parent=\(String(describing: nav.navigationBar.superview?.frame))")
        print("LANDSCAPE_HEADER bar=\(bar) windowSafe=\(window.safeAreaInsets) navSafe=\(nav.view.safeAreaInsets) feedSafe=\(feeds.view.safeAreaInsets) additional=\(nav.additionalSafeAreaInsets) status=\(String(describing: scene.statusBarManager?.statusBarFrame)) hidden=\(String(describing: scene.statusBarManager?.isStatusBarHidden)) vertical=\(nav.traitCollection.verticalSizeClass.rawValue) title=\(String(describing: feeds.navigationItem.titleView?.frame))")
        let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        let attachment = XCTAttachment(image: screenshot)
        attachment.name = "live-SE-landscape-header"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(scene.interfaceOrientation.isLandscape)
        XCTAssertLessThanOrEqual(bar.maxY, 44.5)
        XCTAssertEqual(contentTop, bar.maxY, accuracy: 1)
        feeds.selectEverything(nil)
        let stories = try XCTUnwrap(app.feedDetailViewController)
        for _ in 0..<150 {
            if stories.viewIfLoaded?.window != nil && !stories.pageFetching && stories.storiesCollection.storyLocationsCount > 0 { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        try await Task.sleep(nanoseconds: 400_000_000)
        let storyBar = nav.view.subviews.compactMap { $0 as? UINavigationBar }.first { !$0.isHidden } ?? nav.navigationBar
        XCTAssertLessThanOrEqual(storyBar.convert(storyBar.bounds, to: window).maxY, 44.5)
        let storyTop = stories.view.convert(stories.view.bounds, to: window).minY + stories.view.safeAreaInsets.top
        XCTAssertEqual(storyTop, 44, accuracy: 1)
        let listImage = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        let listAttachment = XCTAttachment(image: listImage)
        listAttachment.name = "live-SE-landscape-story-list"
        listAttachment.lifetime = .keepAlways
        add(listAttachment)
        app.showFeedsList(animated: false)
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        for _ in 0..<40 {
            if scene.interfaceOrientation.isPortrait { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(nav.navigationBar.bounds.height, portraitBarHeight, accuracy: 1)
        #endif
    }

    func test_landscapeReaderKeepsZeroStatusBarInset() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = LandscapeReaderWindow(windowScene: scene)
        let pages = LandscapeReaderPages()
        pages.appDelegate = NewsBlurAppDelegate.shared()
        pages.toolbarScrollHandler = StoryToolbarScrollHandler()
        window.rootViewController = pages
        window.isHidden = false
        defer { window.isHidden = true }
        XCTAssertTrue(pages.view.window === window)
        XCTAssertEqual(pages.topInset(forNavigationBarAlpha: 1), 44, accuracy: 0.5)
        XCTAssertEqual(pages.topInset(forNavigationBarAlpha: 0), 44, accuracy: 0.5)
    }

    func test_headerCountIconsStartAtTheirFinalSizeDuringRotation() throws {
        let storyboard = UIStoryboard(name: "MainInterface", bundle: nil)
        let controller = try XCTUnwrap(storyboard.instantiateViewController(withIdentifier: "FeedsViewController") as? FeedsViewController)
        controller.appDelegate = NewsBlurAppDelegate.shared()
        controller.loadViewIfNeeded()
        let navigation = UINavigationController(rootViewController: controller)
        navigation.view.frame = CGRect(x: 0, y: 0, width: 667, height: 375)
        for orientation in [UIInterfaceOrientation.portrait, .landscapeLeft, .portrait] {
            controller.layoutHeaderCounts(orientation)
            for key in ["greenIcon", "yellowIcon"] {
                let icon = try XCTUnwrap(controller.value(forKey: key) as? UIImageView)
                XCTAssertEqual(icon.bounds.width, 10, accuracy: 0.01,
                               "Rotation must never animate a full-size asset down to the count icon size")
                XCTAssertEqual(icon.bounds.height, 10, accuracy: 0.01)
            }
        }
    }

    func test_footerGroupsStayAtOppositeEdgesWithoutStretchingControls() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "story_toolbar_position")
        defaults.set("bottom", forKey: "story_toolbar_position")
        defer { defaults.set(saved, forKey: "story_toolbar_position") }
        for showsDiscovery in [false, true] {
            let parent = UIView(frame: CGRect(x: 0, y: 0, width: 667, height: 375))
            let header = StoryTitlesHeaderBar()
            header.setup(in: parent)
            header.discoverPill.isHidden = !showsDiscovery
            header.updateOptionsPill(order: "newest", readFilter: "unread")
            header.addSearchField(UITextField())
            header.setSearchActive(true)
            var wideGroupWidth: CGFloat?
            var previousWideGap: CGFloat?
            for width: CGFloat in [667, 1024, 500, 375, 330, 284, 1024] {
                parent.frame.size.width = width
                parent.setNeedsLayout()
                parent.layoutIfNeeded()
                header.relayoutPills()
                parent.layoutIfNeeded()
                let bar = header.pillBar.frame
                XCTAssertEqual(bar.midX, width / 2, accuracy: 0.5)
                XCTAssertLessThanOrEqual(bar.width, width)
                XCTAssertEqual(header.searchContainer.frame.minX, bar.minX + 16, accuracy: 0.5)
                XCTAssertEqual(header.searchContainer.frame.maxX, bar.maxX - 16, accuracy: 0.5)
                XCTAssertGreaterThanOrEqual(header.markReadPill.bounds.width, 52)
                let left = header.leadingToolbarGroup.convert(header.leadingToolbarGroup.bounds, to: header.pillBar)
                let right = header.trailingToolbarGroup.convert(header.trailingToolbarGroup.bounds, to: header.pillBar)
                XCTAssertEqual(left.minX, 16, accuracy: 0.5)
                XCTAssertEqual(right.maxX, bar.width - 16, accuracy: 0.5)
                XCTAssertGreaterThanOrEqual(right.minX - left.maxX, 7.5)
                XCTAssertEqual(left.height, 44, accuracy: 0.5)
                XCTAssertEqual(right.height, 44, accuracy: 0.5)
                if width == 500 {
                    XCTAssertEqual(header.searchPill.configuration?.title, "SEARCH",
                                   "Search text should fit even if Related Sites uses only its icon")
                }
                if width >= 330 {
                    XCTAssertFalse(header.usesMergedToolbar, "Hiding the Search label must not merge the footer")
                    XCTAssertNil(header.mergedToolbarGroup.effect)
                    XCTAssertNotNil(header.leadingToolbarGroup.effect)
                    XCTAssertNotNil(header.trailingToolbarGroup.effect)
                }
                if width >= 667 {
                    XCTAssertFalse(header.usesMergedToolbar)
                    XCTAssertNil(header.mergedToolbarGroup.effect)
                    if let wideGroupWidth { XCTAssertEqual(left.width, wideGroupWidth, accuracy: 0.5) }
                    else { wideGroupWidth = left.width }
                    if width == 1024, let previousWideGap {
                        XCTAssertGreaterThanOrEqual(right.minX - left.maxX, previousWideGap)
                    }
                    previousWideGap = right.minX - left.maxX
                    XCTAssertEqual(header.optionsPill.configuration?.title, "UNREAD · NEWEST")
                    XCTAssertEqual(header.searchPill.configuration?.title, "SEARCH")
                }
            }
        }
    }

    func test_optionsTextDisappearsBeforeWrappingWhenPaneNarrows() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "story_toolbar_position")
        defaults.set("bottom", forKey: "story_toolbar_position")
        defer { defaults.set(saved, forKey: "story_toolbar_position") }
        for filter in ["unread", "all"] {
            let parent = UIView(frame: CGRect(x: 0, y: 0, width: 600, height: 667))
            let header = StoryTitlesHeaderBar()
            header.setup(in: parent)
            header.updateOptionsPill(order: "newest", readFilter: filter)
            for width: CGFloat in [600, 330, 284, 600] {
                parent.frame.size.width = width
                parent.setNeedsLayout()
                parent.layoutIfNeeded()
                header.relayoutPills()
                parent.layoutIfNeeded()
                let title = header.optionsPill.configuration?.title ?? ""
                if width == 284 {
                    XCTAssertTrue(title.isEmpty, "A narrow four-control toolbar must use the dropdown icon instead of vertical text")
                    XCTAssertNotNil(header.optionsPill.configuration?.image)
                }
                if width == 600 {
                    XCTAssertEqual(title, "\(filter.uppercased()) · NEWEST", "Widening the pane must restore the full label")
                }
                if let label = header.optionsPill.titleLabel { XCTAssertEqual(label.numberOfLines, 1) }
                XCTAssertLessThanOrEqual(header.searchPill.bounds.width, 100, "Search must not expand into the flexible space")
                XCTAssertEqual(header.optionsPill.accessibilityLabel, "\(filter.uppercased()) · NEWEST")
            }
        }
    }

    func test_markReadPlusPresentsAboveFooterWithoutChangingGlass() async throws {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "story_toolbar_position")
        defaults.set("bottom", forKey: "story_toolbar_position")
        defer { defaults.set(saved, forKey: "story_toolbar_position") }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let owner = UIViewController()
        let navigation = UINavigationController(rootViewController: owner)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKey() }
        let header = StoryTitlesHeaderBar()
        header.setup(in: owner.view)
        header.updateMarkReadMenuFull(title: "NPR News", showVisibleOption: true, visibleCount: 3)
        var markCalls = 0
        header.markReadHandler = { _ in markCalls += 1 }
        header.markReadVisibleHandler = { markCalls += 1 }
        window.layoutIfNeeded()
        await Task.yield()
        owner.view.layoutIfNeeded()
        let originalFrame = header.headerContainer.frame
        header.markReadExpandButton.sendActions(for: .touchUpInside)
        try await Task.sleep(nanoseconds: 500_000_000)
        let menu = try XCTUnwrap(navigation.presentedViewController ?? owner.presentedViewController,
                                "The + action should present a separate popover instead of a context menu on the shared glass")
        let popover = try XCTUnwrap(menu.popoverPresentationController)
        XCTAssertEqual(menu.modalPresentationStyle, .popover)
        XCTAssertNil(popover.sourceItem)
        XCTAssertEqual(header.headerContainer.frame, originalFrame)
        let menuFrame = menu.view.convert(menu.view.bounds, to: window)
        let barFrame = header.pillBar.convert(header.pillBar.bounds, to: window)
        XCTAssertLessThan(menuFrame.maxY, barFrame.minY + 4)
        XCTAssertTrue(popover.passthroughViews?.isEmpty ?? true)
        XCTAssertEqual(markCalls, 0, "Opening the menu must not mark any stories read")
        let menuController = try XCTUnwrap((menu as? UINavigationController)?.topViewController as? MenuViewController)
        for cell in menuController.menuTableView.visibleCells {
            let icon = try XCTUnwrap(cell.imageView?.image)
            XCTAssertLessThanOrEqual(icon.size.width, 20)
            XCTAssertLessThanOrEqual(icon.size.height, 20)
        }
        let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: screenshot)
        attachment.name = "mark-read-popover-above-unified-footer"
        attachment.lifetime = .keepAlways
        add(attachment)
        menu.dismiss(animated: false)
        owner.view.layoutIfNeeded()
        XCTAssertEqual(header.headerContainer.frame, originalFrame)
        XCTAssertEqual(markCalls, 0)
    }

    func test_liveAlphaSearchFooterAndReturnToolbar() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Requires the connected NB Alpha device")
        #else
        guard Bundle.main.bundleIdentifier == "com.newsblur.NB-Alpha" else {
            throw XCTSkip("Requires NB Alpha")
        }
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        let feeds = try XCTUnwrap(app.feedsViewController)
        for _ in 0..<100 {
            if feeds.viewIfLoaded?.window != nil { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        app.showFeedsList(animated: false)
        feeds.selectEverything(nil)
        let detail = try XCTUnwrap(app.feedDetailViewController)
        // FeedToolbarLayoutTests.swift waits for initial reader routing before testing keyboard focus.
        for _ in 0..<300 {
            if detail.viewIfLoaded?.window != nil && detail.transitionCoordinator == nil &&
                !detail.pageFetching && detail.storiesCollection.storyLocationsCount > 0 &&
                (UIDevice.current.userInterfaceIdiom == .phone || app.activeStory != nil) { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertFalse(detail.pageFetching, "Initial story loading must finish before opening Search")
        if UIDevice.current.userInterfaceIdiom == .pad {
            var readySamples = 0
            for _ in 0..<100 {
                let readerReady = !detail.pageFetching && !detail.isShowingFetching &&
                    detail.transitionCoordinator == nil && detail.storiesCollection.storyLocationsCount > 0
                readySamples = readerReady ? readySamples + 1 : 0
                if readySamples >= 10 { break }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            XCTAssertGreaterThanOrEqual(readySamples, 10, "Initial story list loading must settle before opening Search")
        }
        let window = try XCTUnwrap(detail.view.window)
        let header = try XCTUnwrap(detail.storyTitlesHeaderBar)
        XCTAssertTrue(header.usesFloatingBottomBar)
        if !header.isSearchActive { header.searchPill.sendActions(for: .touchUpInside) }
        defer { detail.searchField.resignFirstResponder(); header.setSearchActive(false) }
        try await Task.sleep(nanoseconds: 600_000_000)
        detail.view.layoutIfNeeded()
        XCTAssertTrue(detail.searchField.isFirstResponder)
        XCTAssertEqual(header.searchContainer.frame.minX, header.pillBar.frame.minX + 16, accuracy: 0.5)
        XCTAssertEqual(header.searchContainer.frame.maxX, header.pillBar.frame.maxX - 16, accuracy: 0.5)
        let field = try XCTUnwrap(detail.searchField)
        XCTAssertEqual(field.frame.minY, header.searchContainer.bounds.height - field.frame.maxY, accuracy: 0.5)
        XCTAssertEqual(field.frame.minX, header.searchContainer.bounds.width - header.searchCancelButton.frame.maxX, accuracy: 0.5)
        let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: screenshot)
        attachment.name = "live-search-footer-even-margins"
        attachment.lifetime = .keepAlways
        add(attachment)
        header.searchCancelButton.sendActions(for: .touchUpInside)
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertFalse(field.isFirstResponder)
        XCTAssertFalse(header.isSearchActive)
        let footerFrame = header.headerContainer.frame
        header.markReadExpandButton.sendActions(for: .touchUpInside)
        try await Task.sleep(nanoseconds: 500_000_000)
        let menu = try XCTUnwrap(detail.navigationController?.presentedViewController)
        XCTAssertEqual(menu.modalPresentationStyle, .popover)
        XCTAssertNil(menu.popoverPresentationController?.sourceItem)
        XCTAssertEqual(header.headerContainer.frame, footerFrame)
        let menuFrame = menu.view.convert(menu.view.bounds, to: window)
        let barFrame = header.pillBar.convert(header.pillBar.bounds, to: window)
        XCTAssertLessThan(menuFrame.maxY, barFrame.minY + 4)
        let menuImage = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let menuAttachment = XCTAttachment(image: menuImage)
        menuAttachment.name = "live-mark-read-popover-keeps-footer"
        menuAttachment.lifetime = .keepAlways
        add(menuAttachment)
        // FeedToolbarLayoutTests.swift dismisses without choosing an action to preserve unread stories.
        menu.dismiss(animated: false)
        detail.view.layoutIfNeeded()
        XCTAssertEqual(header.headerContainer.frame, footerFrame)
        if UIDevice.current.userInterfaceIdiom == .phone {
            let toolbar = try XCTUnwrap(feeds.feedViewToolbar)
            var widths = [CGFloat]()
            app.showFeedsList(animated: true)
            for _ in 0..<60 {
                widths.append(toolbar.bounds.width)
                try await Task.sleep(nanoseconds: 16_000_000)
            }
            XCTAssertLessThanOrEqual((widths.max() ?? 0) - (widths.min() ?? 0), 1,
                                     "The toolbar must keep its width throughout native Back: \(widths)")
            XCTAssertEqual(feeds.intelligenceControl.widthForSegment(at: 1), 68)
        }
        #endif
    }

    func test_searchRowMatchesToolbarMarginsAndCentersItsContents() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "story_toolbar_position")
        defaults.set("bottom", forKey: "story_toolbar_position")
        defer { defaults.set(saved, forKey: "story_toolbar_position") }
        for width: CGFloat in [320, 375, 430, 600] {
            let parent = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 667))
            let header = StoryTitlesHeaderBar()
            header.setup(in: parent)
            let field = UITextField()
            field.placeholder = "Search stories"
            header.addSearchField(field)
            header.setSearchActive(true)
            parent.layoutIfNeeded()
            let row = header.searchContainer
            XCTAssertEqual(row.frame.minX, header.pillBar.frame.minX + 16, accuracy: 0.5)
            XCTAssertEqual(row.frame.maxX, header.pillBar.frame.maxX - 16, accuracy: 0.5)
            XCTAssertEqual(field.frame.minY, row.bounds.height - field.frame.maxY, accuracy: 0.5,
                           "Search input needs equal top and bottom padding")
            XCTAssertEqual(field.frame.minX, row.bounds.width - header.searchCancelButton.frame.maxX, accuracy: 0.5,
                           "Input and close button need equal outer padding")
            XCTAssertEqual(field.frame.midY, header.searchCancelButton.frame.midY, accuracy: 0.5)
            XCTAssertGreaterThan(header.searchCancelButton.frame.minX, field.frame.maxX)
        }
    }

    func test_markReadTapTargetHasBalancedPaddingAtNarrowWidths() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "story_toolbar_position")
        defaults.set("bottom", forKey: "story_toolbar_position")
        defer { defaults.set(saved, forKey: "story_toolbar_position") }
        for width: CGFloat in [320, 330, 375, 430] {
            let parent = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 667))
            let header = StoryTitlesHeaderBar()
            header.setup(in: parent)
            header.updateOptionsPill(order: "newest", readFilter: "unread")
            parent.layoutIfNeeded()
            let mark = header.markReadPill
            XCTAssertGreaterThanOrEqual(mark.bounds.width, 52, "Mark Read needs a generous target even with Related Sites visible")
            if let insets = mark.configuration?.contentInsets {
                XCTAssertEqual(insets.leading, insets.trailing, accuracy: 0.5)
            }
            let markFrame = mark.convert(mark.bounds, to: parent)
            let plusFrame = header.markReadExpandButton.convert(header.markReadExpandButton.bounds, to: parent)
            XCTAssertGreaterThanOrEqual(markFrame.minX, plusFrame.maxX)
            XCTAssertLessThanOrEqual(markFrame.maxX, parent.bounds.maxX - 16)
            XCTAssertGreaterThanOrEqual(header.searchPill.bounds.width, 44)
            XCTAssertGreaterThanOrEqual(header.discoverPill.bounds.width, 44)
        }
    }

    func test_feedToolbarKeepsLabelsWhenBackRestoresLayoutMargins() throws {
        let storyboard = UIStoryboard(name: "MainInterface", bundle: Bundle(for: FeedsViewController.self))
        let controller = try XCTUnwrap(storyboard.instantiateViewController(withIdentifier: "FeedsViewController") as? FeedsViewController)
        controller.loadViewIfNeeded()
        controller.appDelegate = NewsBlurAppDelegate()
        let parent = try XCTUnwrap(controller.view)
        parent.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        let navigation = UINavigationController(rootViewController: controller)
        navigation.view.frame = parent.frame
        let toolbar = try XCTUnwrap(controller.feedViewToolbar)
        // FeedToolbarLayoutTests.swift uses the real storyboard/controller constraints and the margins
        // captured during ClayPhone SE's native interactive Back, including the final restoration to 16.
        for right: CGFloat in [16, 0, 1, 1.5, 2.5, 16] {
            parent.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: right)
            parent.setNeedsLayout()
            parent.layoutIfNeeded()
            controller.viewDidLayoutSubviews()
            parent.layoutIfNeeded()
            let expectedWidth: CGFloat
            if #available(iOS 27.0, *) { expectedWidth = 375 } else { expectedWidth = 359 }
            XCTAssertEqual(toolbar.bounds.width, expectedWidth, accuracy: 0.5)
            XCTAssertEqual(controller.intelligenceControl.widthForSegment(at: 1), 68,
                           "Changing child margins must not change the toolbar's available width")
        }
        withExtendedLifetime(navigation) {}
    }

    func test_storyToolbarDefaultsToBottomAndHonorsExplicitTopPreference() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "story_toolbar_position")
        defer { defaults.set(saved, forKey: "story_toolbar_position") }
        defaults.removeObject(forKey: "story_toolbar_position")
        #if !targetEnvironment(macCatalyst)
        XCTAssertTrue(StoryTitlesHeaderBar().usesFloatingBottomBar,
                      "Both iPhone and iPad should default to the bottom toolbar")
        defaults.set("top", forKey: "story_toolbar_position")
        XCTAssertFalse(StoryTitlesHeaderBar().usesFloatingBottomBar)
        defaults.set("bottom", forKey: "story_toolbar_position")
        XCTAssertTrue(StoryTitlesHeaderBar().usesFloatingBottomBar)
        #endif
    }

    func test_livePadSettingsPopoverLeavesToolbarVisible() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Requires the connected iPad Alpha app")
        #else
        guard UIDevice.current.userInterfaceIdiom == .pad,
              Bundle.main.bundleIdentifier == "com.newsblur.NB-Alpha" else {
            throw XCTSkip("Requires NB Alpha on iPad")
        }
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        let feeds = try XCTUnwrap(app.feedsViewController)
        for _ in 0..<100 {
            if feeds.viewIfLoaded?.window != nil { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        let window = try XCTUnwrap(feeds.view.window)
        feeds.showSettingsPopover(nil)
        try await Task.sleep(nanoseconds: 600_000_000)
        let menu = try XCTUnwrap(feeds.navigationController?.presentedViewController ?? feeds.presentedViewController)
        defer { menu.dismiss(animated: false) }
        let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: screenshot)
        attachment.name = "claypad-settings-above-feed-toolbar"
        attachment.lifetime = .keepAlways
        add(attachment)
        let popover = try XCTUnwrap(menu.popoverPresentationController)
        XCTAssertNil(popover.sourceItem, "A bar item source morphs the shared toolbar into the menu on iOS 26+")
        let toolbar = try XCTUnwrap(feeds.feedViewToolbar)
        let toolbarFrame = toolbar.convert(toolbar.bounds, to: window)
        let menuFrame = menu.view.convert(menu.view.bounds, to: window)
        XCTAssertLessThan(menuFrame.maxY, toolbarFrame.minY, "Settings must float above the full feed toolbar")
        if #available(iOS 17.0, *), let source = popover.sourceView {
            let anchor = source.convert(popover.sourceRect, to: window)
            let gear = try XCTUnwrap(feeds.settingsBarButton.frame(in: window))
            XCTAssertEqual(anchor.midX, gear.midX, accuracy: 1, "The popover must point to Settings, not the middle of the bar")
        }
        XCTAssertTrue(popover.passthroughViews?.isEmpty ?? true, "Tapping the bar should dismiss settings")
        #endif
    }

    func test_floatingToolbarGlassAppearanceAcrossThemes() async throws {
        let defaults = UserDefaults.standard
        let keys = ["story_toolbar_position", "theme_style", "theme_light", "theme_dark", "discover_display"]
        let saved = keys.map { defaults.object(forKey: $0) }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            previousWindow?.makeKey()
            for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) }
        }
        defaults.set("bottom", forKey: "story_toolbar_position")
        defaults.set("with_icons", forKey: "discover_display")
        for theme in ["light", "sepia", "medium", "dark"] {
            let dark = theme == "medium" || theme == "dark"
            defaults.set(dark ? "dark" : "light", forKey: "theme_style")
            defaults.set(theme, forKey: dark ? "theme_dark" : "theme_light")
            controller.overrideUserInterfaceStyle = dark ? .dark : .light
            controller.view.subviews.forEach { $0.removeFromSuperview() }
            controller.view.backgroundColor = ThemeManager.shared?.color(fromLightRGB: 0xECEEEA, sepiaRGB: 0xFAF5ED, mediumRGB: 0x444444, darkRGB: 0x222222)
            var headers = [StoryTitlesHeaderBar]()
            for (index, width) in [CGFloat(330), 375].enumerated() {
                let parent = UIView(frame: CGRect(x: 16, y: CGFloat(80 + index * 220), width: min(width, window.bounds.width - 32), height: 180))
                controller.view.addSubview(parent)
                let background = UILabel(frame: parent.bounds.insetBy(dx: 12, dy: 12))
                background.text = "\(theme.capitalized) • \(index == 0 ? "Related Sites" : "All Site Stories")\n\nStory content behind the floating toolbar"
                background.numberOfLines = 0
                background.textColor = dark ? .lightGray : .darkGray
                parent.addSubview(background)
                let header = StoryTitlesHeaderBar()
                header.setup(in: parent)
                header.updateOptionsPill(order: "newest", readFilter: "unread")
                header.updateDiscoverVisibility(isRiver: true, isEverything: index == 1, isSocial: false, isSaved: false, isRead: false, isWidget: false, isInfrequent: false)
                parent.layoutIfNeeded()
                for button in [header.optionsPill, header.searchPill, header.markReadExpandButton, header.markReadPill] {
                    let center = button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: parent)
                    let hit = parent.hitTest(center, with: nil)
                    XCTAssertTrue(hit === button || hit?.isDescendant(of: button) == true)
                    XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
                }
                XCTAssertGreaterThanOrEqual(header.searchPill.bounds.width, 44,
                                            "The icon-only Search action must retain a full touch target")
                if !header.discoverPill.isHidden {
                    XCTAssertGreaterThanOrEqual(header.discoverPill.bounds.width, 44)
                }
                headers.append(header)
            }
            func capture(_ state: String) -> Data? {
                let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                let attachment = XCTAttachment(image: screenshot)
                attachment.name = "story-toolbar-\(theme)-\(state)"
                attachment.lifetime = .keepAlways
                add(attachment)
                return screenshot.pngData()
            }
            try await Task.sleep(nanoseconds: 300_000_000)
            let normal = capture("normal")
            headers.forEach { $0.optionsPill.isHighlighted = true }
            try await Task.sleep(nanoseconds: 300_000_000)
            XCTAssertNotEqual(normal, capture("pressed"), "Touching the options control must have visible feedback")
            headers.forEach { $0.optionsPill.isHighlighted = false }
        }
    }

    func test_floatingToolbarControlsSupportPointerFeedbackAndPreserveDisabledState() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "story_toolbar_position")
        defaults.set("bottom", forKey: "story_toolbar_position")
        defer { defaults.set(saved, forKey: "story_toolbar_position") }
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
        let header = StoryTitlesHeaderBar()
        header.setup(in: parent)
        parent.layoutIfNeeded()
        for button in [header.discoverPill, header.optionsPill, header.searchPill,
                       header.markReadExpandButton, header.markReadPill] {
            XCTAssertTrue(button.isPointerInteractionEnabled,
                          "Every enabled story toolbar action should provide native pointer feedback")
            XCTAssertTrue(button.isEnabled)
            if #available(iOS 26.0, *) {
                var ancestor: UIView? = button.superview
                while ancestor != nil && (ancestor as? UIVisualEffectView)?.effect == nil { ancestor = ancestor?.superview }
                let surface = ancestor as? UIVisualEffectView
                XCTAssertNotNil(surface, "Controls must sit inside the interactive glass surface")
                XCTAssertEqual((surface?.effect as? UIGlassEffect)?.isInteractive, true)
                let isMarkRead = button === header.markReadExpandButton || button === header.markReadPill
                let expected = header.usesMergedToolbar ? header.mergedToolbarGroup :
                    (isMarkRead ? header.trailingToolbarGroup : header.leadingToolbarGroup)
                XCTAssertTrue(surface === expected,
                              "Controls must share the glass surface for their side of the footer")
            }
        }
        header.updateMarkReadEnabled(false)
        XCTAssertFalse(header.markReadPill.isEnabled)
        XCTAssertFalse(header.markReadExpandButton.isEnabled)
        XCTAssertTrue(header.optionsPill.isEnabled)
        XCTAssertTrue(header.searchPill.isEnabled)
        header.updateMarkReadEnabled(true)
        XCTAssertTrue(header.markReadPill.isEnabled)
        XCTAssertEqual(header.markReadContainer.alpha, 1)
    }

    func test_floatingToolbarRefreshNeverAppliesOpaqueInactiveButtonBackgrounds() {
        assertRefreshPreservesButtonBackgrounds(searchActive: false)
    }

    func test_floatingToolbarRefreshKeepsActiveSearchHighlight() {
        assertRefreshPreservesButtonBackgrounds(searchActive: true)
    }

    private func assertRefreshPreservesButtonBackgrounds(searchActive: Bool) {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "story_toolbar_position")
        defaults.set("bottom", forKey: "story_toolbar_position")
        defer { defaults.set(saved, forKey: "story_toolbar_position") }
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
        let header = StoryTitlesHeaderBar()
        header.setup(in: parent)
        header.setSearchActive(searchActive)
        parent.layoutIfNeeded()
        let buttons = [header.optionsPill, header.searchPill]
        let expected = buttons.map { $0.backgroundColor ?? .clear }
        var intermediateColors = [[UIColor](), [UIColor]()]
        let observations = buttons.enumerated().map { index, button in
            button.observe(\.backgroundColor, options: [.new]) { observed, _ in
                intermediateColors[index].append(observed.backgroundColor ?? .clear)
            }
        }
        withExtendedLifetime(observations) {
            for _ in 0..<3 {
                // FeedToolbarLayoutTests.swift mirrors the header updates made by each received story page.
                header.setDailyBriefingMode(false)
                header.updateOptionsPill(order: "newest", readFilter: "unread")
                header.updateTheme()
            }
        }
        for index in buttons.indices {
            XCTAssertTrue(intermediateColors[index].allSatisfy { $0.isEqual(expected[index]) },
                          "Button \(index) must never briefly receive a different background during page refresh: \(intermediateColors[index])")
            XCTAssertEqual(buttons[index].backgroundColor, expected[index])
        }
    }

    func test_regularSidebarUsesOneGroupAndKeepsLabelsAt375Points() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("Requires the iOS 27 native toolbar") }
        let storyboard = UIStoryboard(name: "MainInterface", bundle: Bundle(for: FeedsViewController.self))
        let controller = try XCTUnwrap(storyboard.instantiateViewController(withIdentifier: "FeedsViewController") as? FeedsViewController)
        controller.loadViewIfNeeded()
        let app = NewsBlurAppDelegate()
        let detail = ToolbarRegularWidthDetail()
        app.detailViewController = detail
        controller.appDelegate = app
        controller.view.frame = CGRect(x: 0, y: 0, width: 375, height: 820)
        controller.viewDidLayoutSubviews()
        // FeedToolbarLayoutTests.swift resolves toolbar edge constraints without a host window.
        let leading = controller.toolbarLeadingConstraint.constant
        let trailing = controller.toolbarTrailingConstraint.constant
        controller.feedViewToolbar.frame = CGRect(x: leading, y: 0, width: 375 - leading - trailing, height: 48)
        controller.layout(for: .landscapeLeft)
        XCTAssertEqual(controller.feedViewToolbar.items?.count, 3, "Spacers split the toolbar into separate glass groups")
        XCTAssertTrue(controller.feedViewToolbar.items?.first === controller.addBarButton)
        XCTAssertTrue(controller.feedViewToolbar.items?.last === controller.settingsBarButton)
        XCTAssertEqual(controller.intelligenceControl.widthForSegment(at: 1), 68)
        XCTAssertEqual(controller.intelligenceControl.widthForSegment(at: 2), 62)
        XCTAssertEqual(controller.intelligenceControl.widthForSegment(at: 3), 60)

        controller.feedViewToolbar.frame.size.width = 286
        controller.layout(for: .landscapeLeft)
        XCTAssertEqual(controller.feedViewToolbar.items?.count, 3)
        XCTAssertLessThan(controller.intelligenceControl.widthForSegment(at: 1), 68)
        XCTAssertEqual(controller.intelligenceControl.numberOfSegments, 4)

        controller.feedViewToolbar.frame.size.width = 375
        controller.layout(for: .landscapeLeft)
        XCTAssertEqual(controller.intelligenceControl.widthForSegment(at: 1), 68,
                       "Widening the sidebar must restore the text labels")
    }

    func test_livePadToolbarUsesOneGroup() async throws {
#if targetEnvironment(simulator)
        throw XCTSkip("Requires the connected iPad Alpha app")
#else
        guard #available(iOS 27.0, *), UIDevice.current.userInterfaceIdiom == .pad,
              Bundle.main.bundleIdentifier == "com.newsblur.NB-Alpha" else {
            throw XCTSkip("Requires NewsBlur Alpha on iPad with iOS 27")
        }
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        for _ in 0..<100 {
            if app.feedsViewController?.viewIfLoaded?.window != nil { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        let feeds = try XCTUnwrap(app.feedsViewController)
        feeds.view.layoutIfNeeded()
        XCTAssertEqual(feeds.feedViewToolbar.items?.count, 3)
        XCTAssertTrue(feeds.feedViewToolbar.items?.first === feeds.addBarButton)
        XCTAssertTrue(feeds.feedViewToolbar.items?.last === feeds.settingsBarButton)
        // FeedToolbarLayoutTests.swift checks rendered hit targets because items can exist while UIKit puts them in overflow.
        let control = try XCTUnwrap(feeds.intelligenceControl)
        let toolbar = try XCTUnwrap(feeds.feedViewToolbar)
        func assertFiltersAreTappable() {
            for index in 0..<control.numberOfSegments {
                let segmentWidth = control.bounds.width / CGFloat(control.numberOfSegments)
                let point = control.convert(CGPoint(x: (CGFloat(index) + 0.5) * segmentWidth, y: control.bounds.midY), to: toolbar)
                let hit = toolbar.hitTest(point, with: nil)
                XCTAssertTrue(hit === control || hit?.isDescendant(of: control) == true,
                              "Intelligence segment \(index) must be directly tappable, not hidden in overflow")
            }
        }
        let window = try XCTUnwrap(feeds.view.window)
        func capture(_ name: String) {
            let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: screenshot)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        assertFiltersAreTappable()
        capture("claypad-single-toolbar-group")
        let split = try XCTUnwrap(app.splitViewController)
        let previousWidth = split.preferredPrimaryColumnWidth
        let previousMinimum = split.minimumPrimaryColumnWidth
        let previousMaximum = split.maximumPrimaryColumnWidth
        let previousSavedWidth = UserDefaults.standard.object(forKey: "split_primary_width")
        defer {
            split.minimumPrimaryColumnWidth = previousMinimum
            split.maximumPrimaryColumnWidth = previousMaximum
            split.preferredPrimaryColumnWidth = previousWidth
            split.view.setNeedsLayout()
            split.view.layoutIfNeeded()
            UserDefaults.standard.set(previousSavedWidth, forKey: "split_primary_width")
        }
        split.maximumPrimaryColumnWidth = 375
        split.minimumPrimaryColumnWidth = 375
        split.preferredPrimaryColumnWidth = 375
        split.view.setNeedsLayout()
        split.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(toolbar.bounds.width, 375, accuracy: 1, "The live resize fixture must reach the labeled width")
        XCTAssertEqual(control.widthForSegment(at: 1), 68)
        XCTAssertEqual(control.widthForSegment(at: 2), 62)
        XCTAssertEqual(control.widthForSegment(at: 3), 60)
        assertFiltersAreTappable()
        capture("claypad-single-toolbar-full-labels")
#endif
    }
}

@MainActor private final class ToolbarRegularWidthDetail: DetailViewController {
    override var isPhoneOrCompact: Bool { false }
}

@MainActor private final class LandscapeReaderWindow: UIWindow {
    override var safeAreaInsets: UIEdgeInsets { .zero }
}

@MainActor private final class LandscapeReaderPages: StoryPagesViewController {
    override var useCustomToolbar: Bool { true }
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 667, height: 375)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
}
