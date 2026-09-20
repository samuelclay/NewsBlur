import XCTest
import UIKit

@testable import NewsBlur

@MainActor final class Test_StoryTitlesHeaderBarLayout: XCTestCase {
    private var originalDiscoverDisplay: Any?
    private var originalToolbarPosition: Any?

    override func setUp() {
        super.setUp()
        originalDiscoverDisplay = UserDefaults.standard.object(forKey: "discover_display")
        originalToolbarPosition = UserDefaults.standard.object(forKey: "story_toolbar_position")
        UserDefaults.standard.set("with_icons", forKey: "discover_display")
        UserDefaults.standard.set("bottom", forKey: "story_toolbar_position")
    }

    override func tearDown() {
        UserDefaults.standard.set(originalDiscoverDisplay, forKey: "discover_display")
        UserDefaults.standard.set(originalToolbarPosition, forKey: "story_toolbar_position")
        super.tearDown()
    }

    func test_reopeningSearchBeforeCloseAnimationCompletesKeepsFieldVisible() async throws {
        let host = try HeaderDuoTestWindow()
        defer { host.close() }
        let bar = StoryTitlesHeaderBar()
        bar.setup(in: host.controller.view)
        bar.addSearchField(UITextField())
        host.window.layoutIfNeeded()
        UIView.performWithoutAnimation { bar.setSearchActive(true) }
        host.window.layoutIfNeeded()

        // StoryTitlesHeaderBarLayoutTests.swift reproduces a second tap while the close animation is still pending.
        bar.setSearchActive(false)
        try await Task.sleep(nanoseconds: 50_000_000)
        bar.setSearchActive(true)
        try await Task.sleep(nanoseconds: 450_000_000)

        XCTAssertTrue(bar.isSearchActive)
        XCTAssertFalse(bar.searchContainer.isHidden, "The earlier close completion must not hide a newly reopened search")
        XCTAssertGreaterThan(bar.searchContainer.alpha, 0.99)
    }

    func test_activeSearchSurvivesFoldChangesAndRestoresTopToolbarPreference() throws {
        UserDefaults.standard.set("top", forKey: "story_toolbar_position")
        let host = try HeaderDuoTestWindow()
        defer { host.close() }
        let bar = StoryTitlesHeaderBar()
        let field = UITextField()
        bar.setup(in: host.controller.view)
        bar.addSearchField(field)
        UIView.performWithoutAnimation { bar.setSearchActive(true) }
        host.window.layoutIfNeeded()
        field.text = "Duo search"
        XCTAssertTrue(field.becomeFirstResponder())
        defer { field.resignFirstResponder() }

        for vertical in [true, false, true, false] {
            UIView.performWithoutAnimation {
                bar.setUsesSystemVerticalBar(vertical)
                host.window.layoutIfNeeded()
            }
            XCTAssertTrue(bar.isSearchActive)
            XCTAssertTrue(field.isFirstResponder)
            XCTAssertEqual(field.text, "Duo search")
            XCTAssertFalse(bar.headerContainer.isHidden)
            XCTAssertFalse(bar.searchContainer.isHidden)
            XCTAssertEqual(bar.pillBar.isHidden, vertical)
            XCTAssertFalse(bar.usesFloatingBottomBar, "Folding must preserve the user's top-toolbar preference")
            XCTAssertEqual(bar.headerContainer.bounds.height, vertical ? 36 : 72, accuracy: 0.5)
        }
        UIView.performWithoutAnimation { bar.setSearchActive(false) }
        host.window.layoutIfNeeded()
        XCTAssertEqual(bar.headerContainer.bounds.height, 36, accuracy: 0.5)
    }

    func test_nativeMarkReadMenuRetainsVisibleAndAgeActionsWithoutReadingAnything() {
        let bar = StoryTitlesHeaderBar()
        var marks = 0
        bar.markReadHandler = { _ in marks += 1 }
        bar.markReadVisibleHandler = { marks += 1 }
        bar.updateMarkReadMenuFull(title: "this site", showVisibleOption: true, visibleCount: 3)
        XCTAssertEqual(bar.nativeMarkReadMenu.children.map(\.title), [
            "Mark this site as read", "Mark these 3 stories read",
            "Older than 1 day", "Older than 3 days", "Older than 7 days", "Older than 14 days"
        ])
        bar.updateMarkReadMenuFull(title: "everything", showVisibleOption: false, visibleCount: 3)
        XCTAssertEqual(bar.nativeMarkReadMenu.children.count, 5)
        XCTAssertEqual(marks, 0)
    }

    func test_unselectedExpandedPhoneHasNoStoryToolbarOrReservedSpace() throws {
#if targetEnvironment(macCatalyst)
        throw XCTSkip("Expanded iPhone Duo layout is not used by Catalyst")
#else
        for position in ["bottom", "top"] {
            try assertStoryToolbarSelectionStates(phone: true, compact: false,
                                                  position: position, selections: [nil])
        }
#endif
    }

    func test_emptySelectedSourcesRestoreExpandedPhoneStoryToolbar() throws {
#if targetEnvironment(macCatalyst)
        throw XCTSkip("Expanded iPhone Duo layout is not used by Catalyst")
#else
        for position in ["bottom", "top"] {
            try assertStoryToolbarSelectionStates(phone: true, compact: false, position: position,
                                                  selections: [nil, "feed", nil, "everything", nil, "daily_briefing", nil])
        }
#endif
    }

    func test_unselectedCompactPhoneAndPadRetainStoryToolbar() throws {
        for (phone, compact) in [(true, true), (false, false), (false, true)] {
            try assertStoryToolbarSelectionStates(phone: phone, compact: compact,
                                                  position: "bottom", selections: [nil, "feed", nil])
        }
    }

    func test_unselectedSourceStaysHiddenAcrossSearchAndBarChangesThenRestoresSearch() throws {
        let host = try HeaderDuoTestWindow()
        defer { host.close() }
        let header = StoryTitlesHeaderBar()
        header.setup(in: host.controller.view)
        let field = UITextField()
        header.addSearchField(field)
        field.text = "Preserved search"
        UIView.performWithoutAnimation { header.setSearchActive(true) }
        header.setSourceControlsHidden(true)

        for vertical in [false, true, false] {
            UIView.performWithoutAnimation {
                header.setUsesSystemVerticalBar(vertical)
                header.setSearchActive(true)
                host.window.layoutIfNeeded()
            }
            XCTAssertTrue(header.headerContainer.isHidden)
            XCTAssertEqual(header.headerContainer.bounds.height, 0, accuracy: 0.5)
            XCTAssertTrue(header.isSearchActive)
            XCTAssertEqual(field.text, "Preserved search")
        }

        header.setSourceControlsHidden(false)
        host.window.layoutIfNeeded()
        XCTAssertFalse(header.headerContainer.isHidden)
        XCTAssertFalse(header.searchContainer.isHidden)
        XCTAssertEqual(header.headerContainer.bounds.height, (header.usesFloatingBottomBar ? 52 : 36) + 36,
                       accuracy: 0.5)
        XCTAssertEqual(field.text, "Preserved search")
    }

    private func assertStoryToolbarSelectionStates(phone: Bool, compact: Bool, position: String,
                                                  selections: [String?], file: StaticString = #filePath,
                                                  line: UInt = #line) throws {
        UserDefaults.standard.set(position, forKey: "story_toolbar_position")
        let app = NewsBlurAppDelegate()
        let detail = HeaderDuoTiledSidebarDetail()
        detail.simulatesPhone = phone
        detail.simulatesCollapsedTitles = false
        detail.isCompact = compact
        detail.appDelegate = app
        app.detailViewController = detail
        let collection = StoriesCollection()
        app.storiesCollection = collection
        let stories = HeaderUnselectedSourceStories()
        stories.appDelegate = app
        stories.storiesCollection = collection
        detail.feedDetailViewController = stories
        stories.loadViewIfNeeded()
        let host = try HeaderDuoTestWindow(controller: stories)
        let header = StoryTitlesHeaderBar()
        stories.storyTitlesHeaderBar = header
        header.setup(in: stories.view)
        let content = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        stories.view.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: header.contentTopAnchor),
            content.bottomAnchor.constraint(equalTo: header.contentBottomAnchor),
            content.leadingAnchor.constraint(equalTo: stories.view.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: stories.view.trailingAnchor)
        ])
        defer {
            host.close()
            host.window.rootViewController = nil
            header.headerContainer.removeFromSuperview()
            detail.feedDetailViewController = nil
            app.detailViewController = nil
            app.storiesCollection = nil
            stories.appDelegate = nil
            stories.storiesCollection = nil
        }

        for selection in selections {
            collection.activeFeed = selection == "feed" ? ["id": 1, "feed_title": "Empty selected feed"] : nil
            collection.activeFolder = selection == "feed" ? nil : selection
            collection.isRiverView = selection != nil && selection != "feed"
            collection.isDailyBriefing = selection == "daily_briefing"

            // StoryTitlesHeaderBarLayoutTests.swift exercises the real layout entry point without loading account data or a reader.
            stories.perform(Selector(("configureAdaptiveStoryToolbar")))
            stories.view.setNeedsLayout()
            stories.view.layoutIfNeeded()

            let hidden = phone && !compact && selection == nil
            let context = "phone=\(phone) compact=\(compact) position=\(position) selection=\(selection ?? "none")"
            XCTAssertFalse(header.usesSystemVerticalBar, "An embedded source pane keeps horizontal controls", file: file, line: line)
            XCTAssertEqual(header.headerContainer.isHidden, hidden, context, file: file, line: line)
            XCTAssertEqual(header.headerContainer.bounds.height, hidden ? 0 : (header.usesFloatingBottomBar ? 52 : 36),
                           accuracy: 0.5, context, file: file, line: line)
            if hidden {
                XCTAssertEqual(content.frame.minY, stories.view.bounds.minY, accuracy: 0.5, context, file: file, line: line)
                XCTAssertEqual(content.frame.maxY, stories.view.safeAreaLayoutGuide.layoutFrame.maxY,
                               accuracy: 0.5, context, file: file, line: line)
            }
            XCTAssertEqual(collection.activeFeedStories?.count ?? 0, 0,
                           "Toolbar visibility must depend on source selection, not whether stories have arrived", file: file, line: line)
        }
    }

    func test_expandedPhoneOptionsExposeRegularLayoutsAndFourGridColumns() throws {
        let app = NewsBlurAppDelegate()
        let detail = HeaderDuoRegularDetail()
        detail.appDelegate = app
        detail.isCompact = false
        app.detailViewController = detail
        let collection = StoriesCollection()
        collection.activeFeed = ["id": 1, "feed_title": "Synthetic Duo feed"]
        app.storiesCollection = collection
        let stories = HeaderDuoStories()
        stories.appDelegate = app
        stories.storiesCollection = collection
        let navigation = HeaderDuoMenuNavigation(rootViewController: stories)
        detail.feedDetailViewController = stories
        app.feedsNavigationController = navigation

        stories.doOpenOptionsMenu(UIBarButtonItem(title: "Options", style: .plain, target: nil, action: nil))

        let menu = try XCTUnwrap((navigation.capturedPresentation as? UINavigationController)?.topViewController as? MenuViewController)
        let items = try XCTUnwrap(menu.value(forKey: "items") as? [[String: Any]])
        let choices = items.compactMap { $0["segmentTitles"] as? [String] }
        XCTAssertTrue(choices.contains(["layout-split.png", "layout-top2.png", "layout-full.png", "layout-list.png", "layout-magazine.png", "layout-grid.png"]), "Expanded Duo should offer every regular reader layout")
        XCTAssertTrue(choices.contains(["Auto Cols", "1", "2", "3", "4"]), "Expanded Duo should offer all grid column counts")
    }

    func test_compactPadOptionsKeepAllLayoutsAndGridColumns() throws {
        for compact in [false, true] {
            let app = NewsBlurAppDelegate()
            let detail = HeaderPadGridDetail()
            detail.appDelegate = app
            detail.isCompact = compact
            detail.traitOverrides.horizontalSizeClass = compact ? .compact : .regular
            detail.traitOverrides.verticalSizeClass = .regular
            app.detailViewController = detail
            let collection = StoriesCollection()
            collection.activeFeed = ["id": 1, "feed_title": "Synthetic iPad feed"]
            app.storiesCollection = collection
            let stories = HeaderDuoStories()
            stories.appDelegate = app
            stories.storiesCollection = collection
            let navigation = HeaderDuoMenuNavigation(rootViewController: stories)
            detail.feedDetailViewController = stories
            app.feedsNavigationController = navigation

            stories.doOpenOptionsMenu(UIBarButtonItem(title: "Options", style: .plain, target: nil, action: nil))

            let menu = try XCTUnwrap((navigation.capturedPresentation as? UINavigationController)?.topViewController as? MenuViewController)
            let items = try XCTUnwrap(menu.value(forKey: "items") as? [[String: Any]])
            let choices = items.compactMap { $0["segmentTitles"] as? [String] }
            XCTAssertTrue(choices.contains(["layout-split.png", "layout-top2.png", "layout-full.png", "layout-list.png", "layout-magazine.png", "layout-grid.png"]), "An iPad must retain all layout choices when compact=\(compact)")
            XCTAssertTrue(choices.contains(["Auto Cols", "1", "2", "3", "4"]), "An iPad must retain all grid column counts when compact=\(compact)")
        }
    }

    func test_expandedPhoneStoryListOffersSidebarInOverlayMode() throws {
        guard UIDevice.current.userInterfaceIdiom == .phone else { throw XCTSkip("Requires a phone test host") }
        let app = try XCTUnwrap(NewsBlurAppDelegate.shared())
        let oldDetail = app.detailViewController
        defer { app.detailViewController = oldDetail }
        let detail = HeaderDuoRegularDetail()
        detail.appDelegate = app
        detail.isCompact = false
        let stories = HeaderDuoStories()
        stories.appDelegate = app
        stories.settingsBarButton = UIBarButtonItem(title: "Settings", style: .plain, target: nil, action: nil)
        detail.feedDetailViewController = stories
        app.detailViewController = detail

        stories.updateSidebarButton(for: .secondaryOnly)

        let buttons = (detail.feedDetailNavigationItem.leftBarButtonItems ?? []) + (detail.feedDetailNavigationItem.rightBarButtonItems ?? [])
        XCTAssertTrue(buttons.contains { $0.accessibilityLabel == "Sidebar" }, "Expanded Duo needs a control to recover the hidden sidebar")
    }

    func test_tiledExpandedPhoneOffersAVisibleActionToReturnToReadingColumns() throws {
        for phone in [true, false] {
            for style in [UISplitViewController.Style.doubleColumn, .tripleColumn] {
                for collapsed in [true, false] {
                    let app = NewsBlurAppDelegate()
                    let detail = HeaderDuoTiledSidebarDetail()
                    detail.simulatesPhone = phone
                    detail.simulatesCollapsedTitles = collapsed
                    detail.appDelegate = app
                    detail.isCompact = false
                    app.detailViewController = detail
                    app.splitViewController = SplitViewController(style: style)
                    let stories = HeaderDuoStories()
                    stories.fixtureApp = app
                    stories.appDelegate = app
                    stories.settingsBarButton = UIBarButtonItem(title: "Settings", style: .plain, target: nil, action: nil)
                    detail.feedDetailViewController = stories

                    stories.updateSidebarButton(for: .oneBesideSecondary)

                    // StoryTitlesHeaderBarLayoutTests.swift checks the shared, displayed item rather than a retained hidden button.
                    XCTAssertTrue(detail.feedDetailNavigationItem === detail.storiesNavigationItem)
                    let visibleButtons = detail.navigationItem.leftBarButtonItems ?? []
                    let sidebar = visibleButtons.first { $0.accessibilityLabel == "Sidebar" }
                    if phone && style == .doubleColumn {
                        let sidebar = try XCTUnwrap(sidebar, "Tiled Feeds must leave a visible action to restore the reading columns")
                        if collapsed {
                            XCTAssertTrue(sidebar.target as? DetailViewController === detail)
                            XCTAssertEqual(sidebar.action, #selector(DetailViewController.toggleStoryTitles(_:)))
                        } else {
                            XCTAssertTrue(sidebar.target as? FeedDetailViewController === stories)
                            XCTAssertEqual(sidebar.action, #selector(BaseViewController.toggleFeeds(_:)))
                        }
                    } else {
                        XCTAssertNil(sidebar, "Ordinary tiled iPad and triple-column layouts retain their existing controls")
                    }
                }
            }
        }
    }

    func test_moveToMenuExcludesVirtualFoldersAndKeepsRealDestinations() throws {
        let app = NewsBlurAppDelegate()
        app.dictFoldersArray = NSMutableArray(array: [
            "discover_sites", "daily_briefing", "dashboard", "infrequent", "everything",
            "river_global", "river_blurblogs", "saved_stories", "read_stories", "widget_stories", "saved_searches",
            "Technology", "Technology ▸ iOS", "discover_sites_notes", "daily_briefing_notes"
        ])
        let stories = HeaderDuoStories()
        stories.appDelegate = app
        let navigation = HeaderDuoMenuNavigation()

        // StoryTitlesHeaderBarLayoutTests.swift builds the actual Move To menu without invoking any move handler.
        stories.openMoveView(navigation)

        let menu = try XCTUnwrap(navigation.capturedShownController as? MenuViewController)
        let items = try XCTUnwrap(menu.value(forKey: "items") as? [[String: Any]])
        let titles = items.compactMap { $0["title"] as? String }.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        XCTAssertEqual(titles, ["New Folder", "Top Level", "Technology", "iOS", "discover_sites_notes", "daily_briefing_notes"],
                       "Internal discovery and briefing entries are not destinations for subscribed feeds")
    }

    func test_duoVerticalBarDoesNotActivateStandaloneCompactPhoneHeader() throws {
        guard #available(iOS 27.1, *) else { throw XCTSkip("Requires Duo bars") }
        guard UIDevice.current.userInterfaceIdiom == .phone else { throw XCTSkip("Requires a phone test host") }
        let stories = HeaderDuoStories()
        let navigation = CompactPhoneNavigationController(rootViewController: stories)
        navigation.traitOverrides.verticalSizeClass = .compact
        let host = try HeaderDuoTestWindow(controller: navigation)
        defer { host.close() }
        host.window.layoutIfNeeded()
        guard Utilities.usesSystemVerticalBar(navigation.traitCollection) else {
            throw XCTSkip("Requires Duo closed or partial with a system vertical bar")
        }
        navigation.view.setNeedsLayout()
        navigation.view.layoutIfNeeded()

        XCTAssertTrue(navigation.compactNavigationBar.isHidden, "Duo must keep its managed side navigation instead of adding a standalone top header")
        XCTAssertLessThanOrEqual(stories.additionalSafeAreaInsets.top, 0.5,
                                "The standalone compact-phone header must not add a positive top inset on Duo")
    }

    func test_verticalStoryNavigationCoversTopGapWithCurrentTheme() throws {
        guard #available(iOS 27.1, *) else { throw XCTSkip("Requires Duo bars") }
        let stories = HeaderDuoStories()
        stories.title = "All Site Stories"
        let navigation = CompactPhoneNavigationController(rootViewController: stories)
        let host = try HeaderDuoTestWindow(controller: navigation)
        defer { host.close() }
        guard Utilities.usesSystemVerticalBar(navigation.traitCollection) else {
            throw XCTSkip("Requires a Duo pose with a system vertical bar")
        }
        // StoryTitlesHeaderBarLayoutTests.swift recreates the opaque shared bar configured in FeedsObjCViewController.m.
        navigation.navigationBar.isTranslucent = false
        navigation.view.backgroundColor = .clear
        host.window.backgroundColor = .magenta

        for (name, color) in [("sepia", UIColor(red: 0.95, green: 0.89, blue: 0.8, alpha: 1)),
                              ("dark", UIColor(red: 0.13, green: 0.14, blue: 0.15, alpha: 1))] {
            stories.view.backgroundColor = color
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = color
            navigation.navigationBar.barTintColor = color
            navigation.navigationBar.backgroundColor = color
            navigation.navigationBar.standardAppearance = appearance
            navigation.navigationBar.scrollEdgeAppearance = appearance
            navigation.navigationBar.compactAppearance = appearance
            navigation.navigationBar.compactScrollEdgeAppearance = appearance
            navigation.view.setNeedsLayout()
            host.window.layoutIfNeeded()

            let screenshot = UIGraphicsImageRenderer(bounds: host.window.bounds).image { _ in
                host.window.drawHierarchy(in: host.window.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: screenshot)
            attachment.name = "duo-standalone-navigation-top-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
            let point = CGPoint(x: host.window.bounds.midX, y: 2)
            let sample = try sampledRGB(screenshot, at: point)
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
            XCTAssertTrue(zip(sample, [red, green, blue]).allSatisfy { abs($0.0 - $0.1) < 0.03 },
                          "The vertical navigation's exposed top edge must follow \(name), not reveal its parent's background; actual RGB \(sample)")
        }
    }

    func test_closedStoryListStartsBelowItsTitleWithoutAnEmptyTopBand() throws {
        guard #available(iOS 27.1, *) else { throw XCTSkip("Requires Duo bars") }
        let root = UIViewController()
        root.title = "All"
        let stories = HeaderDuoStories()
        // StoryTitlesHeaderBarLayoutTests.swift mirrors MainInterface.storyboard's story-list edges and table constraints.
        stories.edgesForExtendedLayout = .bottom
        let table = UITableView(frame: .zero, style: .plain)
        let dataSource = HeaderDuoGeometryRows()
        table.dataSource = dataSource
        table.rowHeight = 72
        table.translatesAutoresizingMaskIntoConstraints = false
        stories.view.addSubview(table)
        stories.storyTitlesTable = table
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: stories.view.topAnchor),
            table.bottomAnchor.constraint(equalTo: stories.view.bottomAnchor),
            table.leadingAnchor.constraint(equalTo: stories.view.safeAreaLayoutGuide.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: stories.view.safeAreaLayoutGuide.trailingAnchor)
        ])
        let title = UILabel()
        title.text = "All Site Stories"
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.sizeToFit()
        stories.navigationItem.titleView = title
        stories.toolbarItems = [UIBarButtonItem(barButtonSystemItem: .search, target: nil, action: nil)]
        let navigation = CompactPhoneNavigationController(rootViewController: root)
        navigation.navigationBar.isTranslucent = false
        navigation.setToolbarHidden(false, animated: false)
        navigation.pushViewController(stories, animated: false)
        let host = try HeaderDuoTestWindow(controller: navigation)
        defer { host.close() }
        guard Utilities.usesSystemVerticalBar(navigation.traitCollection),
              navigation.traitCollection.horizontalSizeClass == .compact else {
            throw XCTSkip("Requires closed Duo with a native vertical bar")
        }
        table.reloadData()
        host.window.layoutIfNeeded()
        table.setContentOffset(CGPoint(x: 0, y: -table.adjustedContentInset.top), animated: false)
        host.window.layoutIfNeeded()

        let barFrame = navigation.navigationBar.convert(navigation.navigationBar.bounds, to: host.window)
        let titleFrame = title.convert(title.bounds, to: host.window)
        let firstRowFrame = table.convert(table.rectForRow(at: IndexPath(row: 0, section: 0)), to: host.window)
        let windowTop = host.window.safeAreaInsets.top
        let geometry = XCTAttachment(string: "window=\(host.window.bounds), safe=\(host.window.safeAreaInsets)\nnav=\(barFrame), title=\(titleFrame), firstRow=\(firstRowFrame)\ncontroller=\(stories.view.frame), safe=\(stories.view.safeAreaInsets), tableAdjusted=\(table.adjustedContentInset)\nstatus=\(String(describing: host.window.windowScene?.statusBarManager?.statusBarFrame)), hidden=\(String(describing: host.window.windowScene?.statusBarManager?.isStatusBarHidden))")
        geometry.name = "duo-story-list-empty-top-band-geometry"
        geometry.lifetime = .keepAlways
        add(geometry)
        let screenshot = UIGraphicsImageRenderer(bounds: host.window.bounds).image { _ in
            host.window.drawHierarchy(in: host.window.bounds, afterScreenUpdates: true)
        }
        let image = XCTAttachment(image: screenshot)
        image.name = "duo-story-list-empty-top-band"
        image.lifetime = .keepAlways
        add(image)

        XCTAssertEqual(barFrame.minY, windowTop, accuracy: 1,
                       "Closed Duo must not reserve a horizontal status-bar band above its native title")
        XCTAssertEqual(firstRowFrame.minY, windowTop + barFrame.height, accuracy: 1,
                       "The first story must follow the native title without a second blank top band")
        XCTAssertTrue(title.isDescendant(of: navigation.navigationBar))
        XCTAssertFalse(title.isHidden)
        XCTAssertGreaterThan(titleFrame.width, 0)
        XCTAssertGreaterThan(titleFrame.height, 0)
        XCTAssertGreaterThanOrEqual(firstRowFrame.minY, titleFrame.maxY,
                                    "Removing the gap must not place stories underneath the visible title")
        XCTAssertFalse(navigation.isNavigationBarHidden)
        XCTAssertFalse(navigation.isToolbarHidden)
        XCTAssertTrue(navigation.navigationBar.backItem === root.navigationItem,
                      "The native Back item must remain available while the title is visible")

        table.setContentOffset(CGPoint(x: 0, y: 96), animated: false)
        let scrolledOffset = table.contentOffset
        let scrolledRow = IndexPath(row: 2, section: 0)
        let scrolledFrame = table.convert(table.rectForRow(at: scrolledRow), to: host.window)
        for _ in 0..<4 {
            navigation.view.setNeedsLayout()
            host.window.layoutIfNeeded()
        }
        XCTAssertEqual(table.contentOffset.y, scrolledOffset.y, accuracy: 1,
                       "Repeated layout must not drift a scrolled story list")
        XCTAssertEqual(table.convert(table.rectForRow(at: scrolledRow), to: host.window).minY,
                       scrolledFrame.minY, accuracy: 1)
        let scrolledImage = UIGraphicsImageRenderer(bounds: host.window.bounds).image { _ in
            host.window.drawHierarchy(in: host.window.bounds, afterScreenUpdates: true)
        }
        let scrolledAttachment = XCTAttachment(image: scrolledImage)
        scrolledAttachment.name = "duo-story-list-top-band-scrolled"
        scrolledAttachment.lifetime = .keepAlways
        add(scrolledAttachment)

        let reader = HeaderDuoRetainedReader()
        navigation.pushViewController(reader, animated: false)
        host.window.layoutIfNeeded()
        XCTAssertEqual(stories.additionalSafeAreaInsets.top, 0, accuracy: 0.5,
                       "The closed story-list correction must relinquish its inset when the reader takes over")
        XCTAssertEqual(reader.additionalSafeAreaInsets.top, 0, accuracy: 0.5)
        navigation.popViewController(animated: false)
        host.window.layoutIfNeeded()
        XCTAssertEqual(navigation.navigationBar.convert(navigation.navigationBar.bounds, to: host.window).minY,
                       windowTop, accuracy: 1)
        XCTAssertEqual(title.convert(title.bounds, to: host.window).minY, titleFrame.minY, accuracy: 1)
        XCTAssertEqual(table.contentOffset.y, scrolledOffset.y, accuracy: 1,
                       "Returning from the reader must preserve the scrolled position")

        navigation.traitOverrides.horizontalSizeClass = .regular
        navigation.view.setNeedsLayout()
        host.window.layoutIfNeeded()
        XCTAssertEqual(stories.additionalSafeAreaInsets.top, 0, accuracy: 0.5,
                       "Expanded layouts must keep their normal native title insets")
        withExtendedLifetime(dataSource) {}
    }

    func test_closedStoryNavigationDoesNotPaintOverCollapsedNativeTitle() async throws {
        guard #available(iOS 27.1, *) else { throw XCTSkip("Requires Duo bars") }
        let theme = UIColor(red: 0.84, green: 0.62, blue: 0.35, alpha: 1)
        let storyColor = UIColor(red: 0.125, green: 0.75, blue: 0.25, alpha: 1)
        let root = UIViewController()
        root.title = "All"
        let stories = HeaderDuoStories()
        stories.edgesForExtendedLayout = .all
        stories.view.backgroundColor = storyColor
        let rows = HeaderDuoGeometryRows()
        rows.backgroundColor = storyColor
        rows.rowCount = 60
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = storyColor
        table.dataSource = rows
        table.rowHeight = 72
        table.translatesAutoresizingMaskIntoConstraints = false
        stories.view.addSubview(table)
        stories.storyTitlesTable = table
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: stories.view.topAnchor),
            table.bottomAnchor.constraint(equalTo: stories.view.bottomAnchor),
            table.leadingAnchor.constraint(equalTo: stories.view.safeAreaLayoutGuide.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: stories.view.safeAreaLayoutGuide.trailingAnchor)
        ])
        let title = UILabel()
        title.text = "Engadget"
        title.sizeToFit()
        stories.navigationItem.titleView = title
        let navigation = CompactPhoneNavigationController(rootViewController: root)
        let bar = navigation.navigationBar
        bar.isTranslucent = true
        bar.backgroundColor = theme
        bar.barTintColor = theme
        let expandedAppearance = UINavigationBarAppearance()
        expandedAppearance.configureWithOpaqueBackground()
        expandedAppearance.backgroundColor = theme
        let collapsedAppearance = UINavigationBarAppearance()
        collapsedAppearance.configureWithTransparentBackground()
        func useAppearance(_ appearance: UINavigationBarAppearance) {
            bar.standardAppearance = appearance
            bar.scrollEdgeAppearance = appearance
            bar.compactAppearance = appearance
            bar.compactScrollEdgeAppearance = appearance
        }
        useAppearance(expandedAppearance)
        navigation.pushViewController(stories, animated: false)
        let host = try HeaderDuoTestWindow(controller: navigation)
        defer { host.close() }
        guard Utilities.usesSystemVerticalBar(navigation.traitCollection),
              navigation.traitCollection.horizontalSizeClass == .compact else {
            throw XCTSkip("Requires closed Duo with a native vertical bar")
        }
        table.reloadData()
        host.window.layoutIfNeeded()
        let expandedTopOffset = table.contentOffset.y
        func capture(_ name: String, expected: UIColor) throws {
            let frame = bar.convert(bar.bounds, to: host.window)
            let point = CGPoint(x: table.convert(table.bounds, to: host.window).maxX - 24, y: frame.midY)
            XCTAssertTrue(table.convert(table.bounds, to: host.window).contains(point),
                          "The synthetic story surface must extend beneath the native title, as in the real collapsed list")
            let screenshot = UIGraphicsImageRenderer(bounds: host.window.bounds).image { _ in
                host.window.drawHierarchy(in: host.window.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: screenshot)
            attachment.name = "duo-native-title-surface-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
            let geometry = XCTAttachment(string: "\(name): offset=\(table.contentOffset), adjusted=\(table.adjustedContentInset), expandedOffset=\(expandedTopOffset), table=\(table.convert(table.bounds, to: host.window)), bar=\(frame), title=\(title.convert(title.bounds, to: host.window))")
            geometry.name = "duo-native-title-surface-geometry-\(name)"
            geometry.lifetime = .keepAlways
            add(geometry)
            let rgb = try sampledRGB(screenshot, at: point)
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            XCTAssertTrue(expected.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
            XCTAssertTrue(zip(rgb, [red, green, blue]).allSatisfy { abs($0.0 - $0.1) < 0.035 },
                          "\(name) must render the correct surface beneath the system title; actual RGB \(rgb)")
        }
        func scroll(to offset: CGFloat) async throws {
            table.setContentOffset(CGPoint(x: 0, y: offset), animated: true)
            let deadline = Date().addingTimeInterval(2)
            while abs(table.contentOffset.y - offset) > 0.5, Date() < deadline {
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            XCTAssertEqual(table.contentOffset.y, offset, accuracy: 0.5)
        }
        try capture("expanded", expected: theme)
        // StoryTitlesHeaderBarLayoutTests.swift models the observed native collapse using public appearance/title state, never private UIKit subview mutations.
        title.isHidden = true
        useAppearance(collapsedAppearance)
        try await scroll(to: 651)
        XCTAssertEqual(bar.backgroundColor?.cgColor.alpha ?? 0, 0,
                       "A fixed navigation UIView fill must not cover the stories after UIKit collapses its own title/background")
        try capture("collapsed", expected: storyColor)
        title.isHidden = false
        useAppearance(expandedAppearance)
        // StoryTitlesHeaderBarLayoutTests.swift returns to the expanded offset; the collapsed adjusted inset is zero and would stop before UIKit reveals the title.
        try await scroll(to: expandedTopOffset)
        func isTitleVisible() -> Bool {
            var ancestor: UIView? = title
            while let view = ancestor {
                if view.isHidden || (view.layer.presentation()?.opacity ?? view.layer.opacity) < 0.99 { return false }
                if view === host.window { break }
                ancestor = view.superview
            }
            let frame = title.convert(title.bounds, to: host.window)
            let barFrame = bar.convert(bar.bounds, to: host.window)
            return title.window === host.window && frame.height > 0 && frame.minY >= barFrame.minY && frame.maxY <= barFrame.maxY
        }
        let titleDeadline = Date().addingTimeInterval(2)
        while !isTitleVisible(), Date() < titleDeadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(isTitleVisible(), "Returning to the expanded top offset must reveal the actual native title before its theme is sampled")
        try capture("returned-to-top", expected: theme)
        XCTAssertTrue(title.isDescendant(of: bar))
        XCTAssertTrue(bar.backItem === root.navigationItem)

        title.isHidden = true
        useAppearance(collapsedAppearance)
        table.setContentOffset(CGPoint(x: 0, y: 651), animated: false)
        let reader = HeaderDuoRetainedReader()
        navigation.pushViewController(reader, animated: false)
        bar.backgroundColor = .clear
        host.window.layoutIfNeeded()
        XCTAssertEqual(bar.backgroundColor?.cgColor.alpha ?? 0, 0,
                       "A reader's explicit transparent title bar must remain transparent")
        navigation.popViewController(animated: false)
        try capture("collapsed-after-reader-return", expected: storyColor)
        withExtendedLifetime(rows) {}
    }

    func test_verticalStoryNavigationRestoresContainerWhenReaderOrHiddenBarTakesOver() throws {
        guard #available(iOS 27.1, *) else { throw XCTSkip("Requires Duo bars") }
        let navigation = CompactPhoneNavigationController(rootViewController: UIViewController())
        let host = try HeaderDuoTestWindow(controller: navigation)
        defer { host.close() }
        guard Utilities.usesSystemVerticalBar(navigation.traitCollection) else {
            throw XCTSkip("Requires a Duo pose with a system vertical bar")
        }
        let original = UIColor.purple
        let theme = UIColor.brown
        navigation.view.backgroundColor = original
        navigation.navigationBar.barTintColor = theme
        let stories = HeaderDuoStories()
        navigation.pushViewController(stories, animated: false)
        navigation.view.setNeedsLayout()
        host.window.layoutIfNeeded()
        XCTAssertEqual(navigation.view.backgroundColor, theme)

        let readerAppearance = UINavigationBarAppearance()
        readerAppearance.configureWithTransparentBackground()
        let readerBackgroundColor = readerAppearance.backgroundColor
        let readerBackgroundEffect = readerAppearance.backgroundEffect
        let readerBackgroundImage = readerAppearance.backgroundImage
        navigation.navigationBar.standardAppearance = readerAppearance
        navigation.navigationBar.backgroundColor = .clear
        navigation.pushViewController(HeaderDuoRetainedReader(), animated: false)
        navigation.view.setNeedsLayout()
        host.window.layoutIfNeeded()
        XCTAssertEqual(navigation.view.backgroundColor, original, "The story-list container fill must not carry into the reader")
        XCTAssertEqual(navigation.navigationBar.backgroundColor, .clear)
        XCTAssertEqual(navigation.navigationBar.standardAppearance.backgroundColor, readerBackgroundColor)
        XCTAssertEqual(navigation.navigationBar.standardAppearance.backgroundEffect, readerBackgroundEffect)
        XCTAssertEqual(navigation.navigationBar.standardAppearance.backgroundImage, readerBackgroundImage)

        navigation.popViewController(animated: false)
        navigation.view.setNeedsLayout()
        host.window.layoutIfNeeded()
        XCTAssertEqual(navigation.view.backgroundColor, theme)
        // StoryTitlesHeaderBarLayoutTests.swift models ThemeManager refreshing the outer color while the native story list owns the bar.
        navigation.navigationBar.backgroundColor = theme
        navigation.view.setNeedsLayout()
        host.window.layoutIfNeeded()
        XCTAssertEqual(navigation.navigationBar.backgroundColor?.cgColor.alpha ?? 0, 0,
                       "A theme refresh must not reintroduce the fixed collapsed-title overlay")
        navigation.setNavigationBarHidden(true, animated: false)
        navigation.view.setNeedsLayout()
        host.window.layoutIfNeeded()
        XCTAssertEqual(navigation.view.backgroundColor, original, "A hidden bar must relinquish its container fill")
        XCTAssertEqual(navigation.navigationBar.backgroundColor, theme,
                       "Leaving the managed native title must restore the prior outer fill")
    }

    func test_fullscreenTitlesOverlayRemovesOnlyTheOwningDuosRedundantStatusBand() throws {
        guard #available(iOS 27.1, *) else { throw XCTSkip("Requires Duo bars") }
        let app = NewsBlurAppDelegate()
        let detail = HeaderDuoFullscreenTitleOwner()
        detail.appDelegate = app
        app.detailViewController = detail
        let titles = HeaderDuoFullscreenTitleStories()
        titles.appDelegate = app
        let measured = HeaderDuoMeasuredSafeAreaView(frame: CGRect(x: 0, y: 58, width: 322, height: 611))
        measured.owner = titles
        measured.nativeSafeTop = 24
        titles.view = measured
        let navigation = HeaderDuoHorizontalBarNavigation(rootViewController: titles)
        let host = try HeaderDuoTestWindow(controller: navigation)
        defer {
            host.close()
            app.detailViewController = nil
        }
        guard Utilities.usesSystemVerticalBar(host.window.traitCollection), host.window.safeAreaInsets.top == 0 else {
            throw XCTSkip("Requires a Duo window whose status is in the side rail")
        }
        // StoryTitlesHeaderBarLayoutTests.swift reproduces live148b: horizontal primary traits, bar y24/h58, title root y58 and safeTop24.
        navigation.reportsHorizontalBarTraits = true
        XCTAssertFalse(Utilities.usesSystemVerticalBar(navigation.traitCollection))
        titles.view.frame = CGRect(x: 0, y: 58, width: 322, height: 611)
        navigation.navigationBar.frame = CGRect(x: 0, y: 24, width: 322, height: 58)
        let layout = VerticalNavigationTitleLayout()
        defer { layout.restore() }
        for _ in 0..<3 { layout.update(navigation: navigation, controller: titles, enabled: true) }
        XCTAssertEqual(navigation.navigationBar.frame.minY, 0, accuracy: 0.5)
        XCTAssertEqual(titles.additionalSafeAreaInsets.top, -24, accuracy: 0.5)
        XCTAssertEqual(measured.safeAreaInsets.top, 0, accuracy: 0.5,
                       "The overlay starts below its 58pt title; it must not reserve another horizontal status band")
        XCTAssertEqual(titles.view.convert(CGPoint(x: 0, y: measured.safeAreaInsets.top), to: host.window).y, 58, accuracy: 0.5)

        detail.fullscreen = false
        layout.update(navigation: navigation, controller: titles, enabled: true)
        XCTAssertEqual(navigation.navigationBar.frame.minY, 24, accuracy: 0.5,
                       "Unrelated horizontal navigation must retain its system positioning")
        XCTAssertEqual(titles.additionalSafeAreaInsets.top, 0, accuracy: 0.5)
        XCTAssertEqual(measured.safeAreaInsets.top, 24, accuracy: 0.5)
    }

    func test_verticalTitleStatusCompensationSurvivesNativeMinimization() throws {
        guard #available(iOS 27.1, *) else { throw XCTSkip("Requires Duo bars") }
        let controller = UIViewController()
        let measuredView = HeaderDuoMeasuredSafeAreaView(frame: CGRect(x: 0, y: 0, width: 951, height: 669))
        measuredView.owner = controller
        controller.view = measuredView
        controller.edgesForExtendedLayout = .all
        let title = UILabel()
        title.text = "Feeds · Engadget"
        title.sizeToFit()
        controller.navigationItem.titleView = title
        let navigation = UINavigationController(rootViewController: controller)
        navigation.navigationBar.isTranslucent = true
        let host = try HeaderDuoTestWindow(controller: navigation)
        defer { host.close() }
        guard Utilities.usesSystemVerticalBar(navigation.traitCollection),
              navigation.traitCollection.horizontalSizeClass == .regular,
              host.window.safeAreaInsets.top == 0 else {
            throw XCTSkip("Requires the measured expanded Duo configuration with status in the side rail")
        }
        let layout = VerticalNavigationTitleLayout()
        defer { layout.restore() }
        let bar = navigation.navigationBar
        // StoryTitlesHeaderBarLayoutTests.swift replays gap95's public geometry: after initial correction, the outer bar remains 58 while native safe top changes 58→24→58.
        // No private UIKit title views are mutated; our own title's visibility and measured safe area supply the native transition's inputs.
        for originalPadding in [CGFloat(0), CGFloat(6)] {
            controller.additionalSafeAreaInsets.top = originalPadding
            measuredView.nativeSafeTop = 82
            controller.view.frame = navigation.view.bounds
            bar.frame = CGRect(x: 0, y: 24, width: navigation.view.bounds.width, height: 58)
            // StoryTitlesHeaderBarLayoutTests.swift reproduces layout96's startup fade: an onscreen title at alpha0 is not a minimized title.
            title.alpha = 0
            layout.update(navigation: navigation, controller: controller, enabled: true, titleContent: title)
            XCTAssertEqual(bar.frame.minY, 0, accuracy: 0.5)
            XCTAssertEqual(controller.additionalSafeAreaInsets.top, originalPadding - 24, accuracy: 0.5,
                           "A startup fade must remove only the measured status offset, not all 82pt of native title space")
            XCTAssertEqual(measuredView.safeAreaInsets.top, 58 + originalPadding, accuracy: 0.5,
                           "The title that is fading onscreen still reserves its normal height")
            title.alpha = 1
            measuredView.nativeSafeTop = 58
            for _ in 0..<3 { layout.update(navigation: navigation, controller: controller, enabled: true, titleContent: title) }
            XCTAssertEqual(controller.additionalSafeAreaInsets.top, originalPadding, accuracy: 0.5,
                           "The settled visible title already excludes the status offset, as measured in gap95")
            XCTAssertEqual(measuredView.safeAreaInsets.top, 58 + originalPadding, accuracy: 0.5)

            for _ in 0..<2 {
                measuredView.nativeSafeTop = 24
                title.transform = CGAffineTransform(translationX: 0, y: -58)
                title.alpha = 0
                for _ in 0..<3 { layout.update(navigation: navigation, controller: controller, enabled: true, titleContent: title) }
                XCTAssertEqual(bar.frame.height, 58, accuracy: 0.5,
                               "The native outer frame stays full-height while its own title content minimizes")
                XCTAssertEqual(controller.additionalSafeAreaInsets.top, originalPadding - 24, accuracy: 0.5,
                               "Native minimization must compensate the status inset that remains after the title disappears")
                XCTAssertEqual(measuredView.safeAreaInsets.top, originalPadding, accuracy: 0.5,
                               "The scrolled story column must reach the protected top without a 24pt status strip")

                measuredView.nativeSafeTop = 58
                title.transform = .identity
                title.alpha = 1
                for _ in 0..<3 { layout.update(navigation: navigation, controller: controller, enabled: true, titleContent: title) }
                XCTAssertEqual(controller.additionalSafeAreaInsets.top, originalPadding, accuracy: 0.5)
                XCTAssertEqual(measuredView.safeAreaInsets.top, 58 + originalPadding, accuracy: 0.5,
                               "Reverse scrolling restores space for the real title without adding the old status band")
            }
            layout.restore()
            XCTAssertEqual(controller.additionalSafeAreaInsets.top, originalPadding, accuracy: 0.5,
                           "Leaving the vertical title must restore preexisting app padding")
        }
    }

    func test_expandedSharedTitleStartsAtProtectedTopWithoutEmptyBand() throws {
        guard #available(iOS 27.1, *) else { throw XCTSkip("Requires Duo bars") }
        let app = NewsBlurAppDelegate()
        app.storiesCollection = StoriesCollection()
        let detail = HeaderDuoSharedTitleDetail()
        detail.appDelegate = app
        detail.isCompact = false
        app.detailViewController = detail

        let rows = HeaderDuoGeometryRows()
        let table = UITableView(frame: .zero, style: .plain)
        table.dataSource = rows
        table.rowHeight = 72
        table.translatesAutoresizingMaskIntoConstraints = false
        let reader = UIView()
        reader.backgroundColor = .secondarySystemBackground
        reader.translatesAutoresizingMaskIntoConstraints = false
        detail.view.addSubview(table)
        detail.view.addSubview(reader)
        // StoryTitlesHeaderBarLayoutTests.swift mirrors MainInterface.storyboard's two columns below Detail's shared safe-area top.
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: detail.view.safeAreaLayoutGuide.topAnchor),
            table.leadingAnchor.constraint(equalTo: detail.view.safeAreaLayoutGuide.leadingAnchor),
            table.widthAnchor.constraint(equalTo: detail.view.widthAnchor, multiplier: 0.5),
            table.bottomAnchor.constraint(equalTo: detail.view.bottomAnchor),
            reader.topAnchor.constraint(equalTo: detail.view.safeAreaLayoutGuide.topAnchor),
            reader.leadingAnchor.constraint(equalTo: table.trailingAnchor),
            reader.trailingAnchor.constraint(equalTo: detail.view.safeAreaLayoutGuide.trailingAnchor),
            reader.bottomAnchor.constraint(equalTo: detail.view.bottomAnchor)
        ])
        let title = UILabel()
        title.text = "All Site Stories"
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.sizeToFit()
        detail.navigationItem.titleView = title
        let readerAction = UIBarButtonItem(barButtonSystemItem: .action, target: nil, action: nil)
        detail.toolbarItems = [readerAction]
        let navigation = DetailNavigationController(rootViewController: detail)
        navigation.navigationBar.isTranslucent = true
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        navigation.navigationBar.standardAppearance = appearance
        navigation.navigationBar.scrollEdgeAppearance = appearance
        navigation.navigationBar.compactAppearance = appearance
        navigation.navigationBar.backgroundColor = .clear
        navigation.setToolbarHidden(false, animated: false)
        let host = try HeaderDuoTestWindow(controller: navigation)
        defer { host.close() }
        guard Utilities.usesSystemVerticalBar(navigation.traitCollection),
              navigation.traitCollection.horizontalSizeClass == .regular else {
            throw XCTSkip("Requires expanded Duo with a native vertical bar")
        }
        table.reloadData()
        host.window.layoutIfNeeded()
        table.setContentOffset(CGPoint(x: 0, y: -table.adjustedContentInset.top), animated: false)

        for name in ["All Site Stories", "Daily Briefing"] {
            title.text = name
            title.sizeToFit()
            navigation.navigationBar.setNeedsLayout()
            navigation.view.setNeedsLayout()
            host.window.layoutIfNeeded()
            let barFrame = navigation.navigationBar.convert(navigation.navigationBar.bounds, to: host.window)
            let titleFrame = title.convert(title.bounds, to: host.window)
            let rowFrame = table.convert(table.rectForRow(at: IndexPath(row: 0, section: 0)), to: host.window)
            let readerFrame = reader.convert(reader.bounds, to: host.window)
            let protectedTop = host.window.bounds.minY + host.window.safeAreaInsets.top
            let geometry = XCTAttachment(string: "title=\(name), window=\(host.window.bounds), safe=\(host.window.safeAreaInsets)\nnav=\(barFrame), title=\(titleFrame), firstRow=\(rowFrame), reader=\(readerFrame)\ndetail=\(detail.view.frame), safe=\(detail.view.safeAreaInsets), additional=\(detail.additionalSafeAreaInsets), tableAdjusted=\(table.adjustedContentInset)")
            geometry.name = "duo-expanded-shared-title-geometry-\(name)"
            geometry.lifetime = .keepAlways
            add(geometry)
            let screenshot = UIGraphicsImageRenderer(bounds: host.window.bounds).image { _ in
                host.window.drawHierarchy(in: host.window.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: screenshot)
            attachment.name = "duo-expanded-shared-title-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)

            XCTAssertEqual(barFrame.minY, protectedTop, accuracy: 1,
                           "Expanded Duo must not retain a horizontal status-band offset above its shared title")
            XCTAssertEqual(rowFrame.minY, protectedTop + barFrame.height, accuracy: 1)
            XCTAssertEqual(readerFrame.minY, rowFrame.minY, accuracy: 1,
                           "Both expanded columns must begin below the same visible native title")
            XCTAssertTrue(title.isDescendant(of: navigation.navigationBar))
            XCTAssertFalse(title.isHidden)
            XCTAssertGreaterThan(titleFrame.height, 0)
            let pixel = 1 / max(1, host.window.traitCollection.displayScale)
            XCTAssertGreaterThanOrEqual(rowFrame.minY + pixel, titleFrame.maxY)
            XCTAssertTrue(detail.feedDetailNavigationItem === detail.storiesNavigationItem)
            XCTAssertTrue(detail.toolbarItems?.first === readerAction,
                          "The shared title must leave reader ownership of the native side actions intact")
            XCTAssertEqual(navigation.navigationBar.standardAppearance.backgroundColor, appearance.backgroundColor)
            XCTAssertEqual(navigation.navigationBar.standardAppearance.backgroundEffect, appearance.backgroundEffect)
        }

        detail.simulatesCompact = true
        navigation.view.setNeedsLayout()
        host.window.layoutIfNeeded()
        XCTAssertEqual(detail.additionalSafeAreaInsets.top, 0, accuracy: 0.5,
                       "Folding to the compact navigation stack must release the shared Detail correction")
        detail.simulatesCompact = false
        navigation.view.setNeedsLayout()
        host.window.layoutIfNeeded()
        XCTAssertEqual(navigation.navigationBar.convert(navigation.navigationBar.bounds, to: host.window).minY,
                       host.window.safeAreaInsets.top, accuracy: 1)

        detail.simulatesDiscovery = true
        navigation.view.setNeedsLayout()
        host.window.layoutIfNeeded()
        XCTAssertEqual(detail.additionalSafeAreaInsets.top, 0, accuracy: 0.5,
                       "Discover must receive the shared Detail's original inset")
        detail.simulatesDiscovery = false
        navigation.view.setNeedsLayout()
        host.window.layoutIfNeeded()

        navigation.setNavigationBarHidden(true, animated: false)
        navigation.view.setNeedsLayout()
        host.window.layoutIfNeeded()
        XCTAssertEqual(detail.additionalSafeAreaInsets.top, 0, accuracy: 0.5,
                       "A hidden native title must release the correction")
        navigation.setNavigationBarHidden(false, animated: false)
        navigation.view.setNeedsLayout()
        host.window.layoutIfNeeded()

        let other = UIViewController()
        navigation.pushViewController(other, animated: false)
        host.window.layoutIfNeeded()
        XCTAssertEqual(detail.additionalSafeAreaInsets.top, 0, accuracy: 0.5,
                       "A new navigation owner must not retain the shared Detail's inset correction")
        XCTAssertEqual(other.additionalSafeAreaInsets.top, 0, accuracy: 0.5)
        withExtendedLifetime(rows) {}
    }

    func test_expandedDuoFeedsButtonBesideLiveTitlePreservesGearAndReaderActions() throws {
        guard #available(iOS 27.1, *) else { throw XCTSkip("Requires Duo bars") }
        let app = NewsBlurAppDelegate()
        app.storiesCollection = StoriesCollection()
        let split = HeaderDuoFeedReturnSplit(style: .doubleColumn)
        split.view.frame = CGRect(x: 0, y: 0, width: 951, height: 669)
        app.splitViewController = split
        let detail = HeaderDuoSharedTitleDetail()
        detail.appDelegate = app
        detail.isCompact = false
        app.detailViewController = detail
        let stories = HeaderDuoStories()
        stories.fixtureApp = app
        stories.appDelegate = app
        // StoryTitlesHeaderBarLayoutTests.swift reproduces UIBarButtonItem+Image.m's real custom Settings button, which remains in the horizontal title bar.
        let settingsButton = UIButton(type: .custom)
        settingsButton.setImage(Utilities.imageNamed("settings", sized: 30)?.withRenderingMode(.alwaysTemplate), for: .normal)
        settingsButton.accessibilityLabel = "Settings"
        stories.settingsBarButton = UIBarButtonItem(customView: settingsButton)
        detail.feedDetailViewController = stories
        stories.updateSidebarButton(for: .secondaryOnly)
        let gear = try XCTUnwrap(stories.settingsBarButton)
        XCTAssertTrue(detail.navigationItem.leftBarButtonItems?.contains { $0 === gear } == true)
        XCTAssertTrue(detail.navigationItem.leftItemsSupplementBackButton)
        let readerItem = UIBarButtonItem(title: "Reader action", style: .plain, target: nil, action: nil)
        detail.toolbarItems = [readerItem]
        let sourceTitle = UILabel()
        sourceTitle.text = "All Site Stories"
        sourceTitle.font = .systemFont(ofSize: 17, weight: .semibold)
        sourceTitle.lineBreakMode = .byTruncatingTail
        sourceTitle.sizeToFit()
        detail.navigationItem.titleView = sourceTitle
        // StoryTitlesHeaderBarLayoutTests.swift measures the heading against its actual left-hand story column, not the combined reader width.
        detail.loadViewIfNeeded()
        detail.addChild(stories)
        stories.view.translatesAutoresizingMaskIntoConstraints = false
        detail.view.addSubview(stories.view)
        NSLayoutConstraint.activate([
            stories.view.leadingAnchor.constraint(equalTo: detail.view.leadingAnchor),
            stories.view.topAnchor.constraint(equalTo: detail.view.topAnchor),
            stories.view.bottomAnchor.constraint(equalTo: detail.view.bottomAnchor),
            stories.view.widthAnchor.constraint(equalTo: detail.view.widthAnchor, multiplier: 0.5)
        ])
        stories.didMove(toParent: detail)
        let navigation = DetailNavigationController(rootViewController: detail)
        let host = try HeaderDuoTestWindow(controller: navigation)
        defer {
            host.close()
            stories.willMove(toParent: nil)
            stories.view.removeFromSuperview()
            stories.removeFromParent()
            detail.feedDetailViewController = nil
            // StoryTitlesHeaderBarLayoutTests.swift breaks reverse ownership without invalidating dependencies of queued UIKit layout callbacks.
            app.detailViewController = nil
            app.splitViewController = nil
        }
        guard UIDevice.current.userInterfaceIdiom == .phone,
              navigation.traitCollection.horizontalSizeClass == .regular else {
            throw XCTSkip("Requires an expanded regular-width phone, with either toolbar orientation")
        }
        func settleTitle() {
            navigation.view.setNeedsLayout()
            host.window.layoutIfNeeded()
            navigation.navigationBar.layoutIfNeeded()
        }
        func descendants(_ view: UIView) -> [UIView] {
            [view] + view.subviews.flatMap(descendants)
        }
        func leadingHeading() throws -> UIView {
            try XCTUnwrap(detail.navigationItem.leftBarButtonItems?.compactMap(\.customView).first {
                descendants($0).contains { $0.accessibilityIdentifier == "expanded-feeds-back" }
            }, "Feeds and the live title must be managed as a native leading item")
        }
        settleTitle()
        let title = try leadingHeading()
        let button = try XCTUnwrap(descendants(title).first { $0.accessibilityIdentifier == "expanded-feeds-back" } as? UIButton,
                                   "Expanded Duo needs a visible Feeds control beside its current title, not only in the system rail")
        XCTAssertEqual(button.accessibilityLabel, "Feeds")
        XCTAssertTrue(button.isEnabled)
        XCTAssertTrue(button.isUserInteractionEnabled)
        XCTAssertFalse(button.isHidden)
        XCTAssertTrue(sourceTitle.isDescendant(of: title), "Preserve the actual dynamic title view, including its icons and styling")
        let barFrame = navigation.navigationBar.convert(navigation.navigationBar.bounds, to: host.window)
        let buttonFrame = button.convert(button.bounds, to: host.window)
        let sourceFrame = sourceTitle.convert(sourceTitle.bounds, to: host.window)
        let storyColumnFrame = stories.view.convert(stories.view.bounds, to: host.window)
        XCTAssertGreaterThan(storyColumnFrame.width, 250)
        XCTAssertLessThanOrEqual(buttonFrame.minX, storyColumnFrame.minX + 32,
                                "Feeds must start at the left edge of the story-list heading, not in the centered shared title above the reader")
        XCTAssertLessThanOrEqual(sourceFrame.maxX, storyColumnFrame.maxX,
                                "The current feed title must stay over its story list rather than extend into the reader heading")
        XCTAssertEqual(sourceFrame.midX, storyColumnFrame.midX, accuracy: 1,
                       "The feed/source title must be centered within its story-list column")
        XCTAssertGreaterThanOrEqual(buttonFrame.width, 44)
        XCTAssertGreaterThanOrEqual(buttonFrame.height, 44)
        XCTAssertGreaterThanOrEqual(buttonFrame.minY, barFrame.minY - 1)
        XCTAssertLessThanOrEqual(buttonFrame.maxY, barFrame.maxY + 1)
        XCTAssertLessThanOrEqual(buttonFrame.maxX, sourceFrame.minX)
        XCTAssertEqual(buttonFrame.midY, sourceFrame.midY, accuracy: 1)
        let gearFrame = settingsButton.convert(settingsButton.bounds, to: host.window)
        XCTAssertGreaterThan(gearFrame.width, 0)
        XCTAssertGreaterThanOrEqual(gearFrame.maxX, storyColumnFrame.maxX - 32,
                                    "Settings must be at the right edge of the story-list heading")
        XCTAssertLessThanOrEqual(gearFrame.maxX, storyColumnFrame.maxX - 8,
                                 "Settings must retain a usable inset from the column edge")
        XCTAssertFalse(gearFrame.intersects(buttonFrame), "The title action must not cover Settings")
        XCTAssertFalse(gearFrame.intersects(sourceFrame), "The live source title must not cover Settings")
        XCTAssertTrue(host.window.hitTest(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY), with: nil)?.isDescendant(of: button) == true,
                      "The rendered title-bar button must receive touches")
        XCTAssertNil(detail.navigationItem.backAction, "Do not duplicate the title action with a synthesized rail Back")
        XCTAssertTrue(detail.navigationItem.leftBarButtonItems?.contains { $0 === gear } == true)
        XCTAssertTrue(detail.toolbarItems?.first === readerItem)
        button.sendActions(for: .touchUpInside)
        XCTAssertFalse(split.isFeedsListHidden)
        XCTAssertEqual(split.shownColumns, [.primary])
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(split.shownColumns, [.primary, .primary], "Feeds must reveal, not toggle, the sidebar")

        sourceTitle.text = "A long folder title that must truncate without hiding the Feeds return control"
        settleTitle()
        XCTAssertTrue(sourceTitle.isDescendant(of: title))
        XCTAssertEqual(sourceTitle.lineBreakMode, .byTruncatingTail)
        XCTAssertGreaterThan(sourceTitle.bounds.width, 0)
        XCTAssertLessThanOrEqual(sourceTitle.convert(sourceTitle.bounds, to: host.window).maxX, barFrame.maxX)
        XCTAssertGreaterThanOrEqual(button.bounds.width, 44)
        let longTitleFrame = sourceTitle.convert(sourceTitle.bounds, to: host.window)
        let longButtonFrame = button.convert(button.bounds, to: host.window)
        let longGearFrame = settingsButton.convert(settingsButton.bounds, to: host.window)
        XCTAssertLessThanOrEqual(longButtonFrame.minX, storyColumnFrame.minX + 32,
                                "Long folder names must not move the Feeds action away from the leading edge")
        XCTAssertLessThanOrEqual(longTitleFrame.maxX, storyColumnFrame.maxX,
                                "Long folder names must truncate within the story-list column")
        XCTAssertEqual(longTitleFrame.midX, storyColumnFrame.midX, accuracy: 1,
                       "Truncation must preserve the source title's column-centered alignment")
        XCTAssertGreaterThanOrEqual(longGearFrame.maxX, storyColumnFrame.maxX - 32)
        XCTAssertLessThanOrEqual(longGearFrame.maxX, storyColumnFrame.maxX - 8)
        XCTAssertFalse(longGearFrame.intersects(longTitleFrame), "UIKit must constrain long titles before they overlap Settings")
        XCTAssertFalse(longGearFrame.intersects(longButtonFrame))
        let longScreenshot = UIGraphicsImageRenderer(bounds: host.window.bounds).image { _ in
            host.window.drawHierarchy(in: host.window.bounds, afterScreenUpdates: true)
        }
        let longAttachment = XCTAttachment(image: longScreenshot)
        longAttachment.name = "duo-expanded-feeds-long-title-with-custom-gear"
        longAttachment.lifetime = .keepAlways
        add(longAttachment)
        let replacement = UILabel()
        replacement.text = "Daily Briefing"
        replacement.sizeToFit()
        detail.navigationItem.titleView = replacement
        settleTitle()
        XCTAssertTrue(replacement.isDescendant(of: try leadingHeading()),
                      "A replacement title must become the live title without retaining the old source")
        XCTAssertNil(sourceTitle.window)
        let screenshot = UIGraphicsImageRenderer(bounds: host.window.bounds).image { _ in
            host.window.drawHierarchy(in: host.window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: screenshot)
        attachment.name = "duo-expanded-feeds-beside-title-with-gear"
        attachment.lifetime = .keepAlways
        add(attachment)

        for mode in ["compact", "discover", "ipad", "hidden"] {
            detail.simulatesCompact = mode == "compact"
            detail.simulatesDiscovery = mode == "discover"
            detail.simulatesPhone = mode != "ipad"
            navigation.setNavigationBarHidden(mode == "hidden", animated: false)
            settleTitle()
            XCTAssertTrue(detail.navigationItem.titleView === replacement, "Restore the current source title for \(mode)")
            XCTAssertFalse(detail.navigationItem.leftBarButtonItems?.compactMap(\.customView).contains {
                descendants($0).contains { $0.accessibilityIdentifier == "expanded-feeds-back" }
            } == true, "Remove only the Duo heading when \(mode) takes ownership")
            XCTAssertTrue(detail.navigationItem.leftBarButtonItems?.contains { $0 === gear } == true)
            XCTAssertTrue(detail.toolbarItems?.first === readerItem)
            detail.simulatesCompact = false
            detail.simulatesDiscovery = false
            detail.simulatesPhone = true
            navigation.setNavigationBarHidden(false, animated: false)
            settleTitle()
            let restoredTitle = try leadingHeading()
            XCTAssertTrue(descendants(restoredTitle).contains { $0.accessibilityIdentifier == "expanded-feeds-back" },
                          "Expanded Feeds must return after \(mode), even when the system toolbar is horizontal")
            XCTAssertTrue(replacement.isDescendant(of: restoredTitle))
        }
    }

    func test_expandedDuoFeedsTitleTracksPlainTitleAndRestoresDiscoverOwnership() throws {
        guard #available(iOS 27.1, *) else { throw XCTSkip("Requires Duo bars") }
        let app = NewsBlurAppDelegate()
        app.storiesCollection = StoriesCollection()
        let detail = HeaderDuoSharedTitleDetail()
        detail.appDelegate = app
        detail.isCompact = false
        detail.navigationItem.title = "All Site Stories"
        app.detailViewController = detail
        let original = UIAction(title: "Previous source") { _ in }
        detail.navigationItem.backAction = original
        let navigation = DetailNavigationController(rootViewController: detail)
        let host = try HeaderDuoTestWindow(controller: navigation)
        defer {
            host.close()
            // StoryTitlesHeaderBarLayoutTests.swift leaves the detached controller's app valid until UIKit releases it.
            app.detailViewController = nil
        }
        guard UIDevice.current.userInterfaceIdiom == .phone,
              navigation.traitCollection.horizontalSizeClass == .regular else {
            throw XCTSkip("Requires an expanded regular-width phone, with either toolbar orientation")
        }
        func descendants(_ view: UIView) -> [UIView] {
            [view] + view.subviews.flatMap(descendants)
        }
        func leadingHeading() throws -> UIView {
            try XCTUnwrap(detail.navigationItem.leftBarButtonItems?.compactMap(\.customView).first {
                descendants($0).contains { $0.accessibilityIdentifier == "expanded-feeds-back" }
            }, "Plain titles also belong beside Feeds in the native leading item")
        }
        navigation.view.setNeedsLayout()
        host.window.layoutIfNeeded()
        let title = try leadingHeading()
        XCTAssertTrue(descendants(title).contains { $0.accessibilityIdentifier == "expanded-feeds-back" })
        XCTAssertTrue(descendants(title).contains { ($0 as? UILabel)?.text == "All Site Stories" })
        XCTAssertEqual(detail.navigationItem.backAction?.identifier, original.identifier,
                       "Title navigation must preserve an existing native Back action")
        detail.navigationItem.title = "Daily Briefing"
        navigation.view.setNeedsLayout()
        host.window.layoutIfNeeded()
        XCTAssertTrue(descendants(title).contains { ($0 as? UILabel)?.text == "Daily Briefing" })
        XCTAssertFalse(descendants(title).contains { ($0 as? UILabel)?.text == "All Site Stories" })
        detail.simulatesDiscovery = true
        navigation.view.setNeedsLayout()
        host.window.layoutIfNeeded()
        XCTAssertNil(detail.navigationItem.titleView)
        XCTAssertEqual(detail.navigationItem.title, "Daily Briefing")
        XCTAssertEqual(detail.navigationItem.backAction?.identifier, original.identifier)
        detail.simulatesDiscovery = false
        navigation.view.setNeedsLayout()
        host.window.layoutIfNeeded()
        let restoredTitle = try leadingHeading()
        XCTAssertTrue(descendants(restoredTitle).contains { $0.accessibilityIdentifier == "expanded-feeds-back" })
        XCTAssertTrue(descendants(restoredTitle).contains { ($0 as? UILabel)?.text == "Daily Briefing" })
        XCTAssertEqual(detail.navigationItem.backAction?.identifier, original.identifier)
    }

    func test_expandedTitleHeaderDefersRoutingUntilCurrentTableIsCommitted() async throws {
        guard #available(iOS 27.1, *) else { throw XCTSkip("Requires Duo header minimization") }
        let app = NewsBlurAppDelegate()
        app.storiesCollection = StoriesCollection()
        let detail = HeaderDuoSharedTitleDetail()
        detail.recordsScrollSources = true
        detail.appDelegate = app
        app.detailViewController = detail
        let previous = UIScrollView()
        detail.setContentScrollView(previous, for: .top)
        let stories = HeaderDuoStories()
        stories.fixtureApp = app
        stories.appDelegate = app
        detail.feedDetailViewController = stories
        detail.addChild(stories)
        detail.view.addSubview(stories.view)
        stories.didMove(toParent: detail)
        let rows = HeaderDuoGeometryRows()
        rows.sectionCount = 0
        let table = HeaderDuoUpdatingTable(frame: stories.view.bounds)
        table.dataSource = rows
        stories.view.addSubview(table)
        stories.storyTitlesTable = table
        let navigation = DetailNavigationController(rootViewController: detail)
        let host = try HeaderDuoTestWindow(controller: navigation)
        defer {
            host.close()
            stories.willMove(toParent: nil)
            stories.view.removeFromSuperview()
            stories.removeFromParent()
            detail.feedDetailViewController = nil
            app.detailViewController = nil
        }
        func layoutAndDrain() async {
            navigation.view.setNeedsLayout()
            host.window.layoutIfNeeded()
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
        }
        await layoutAndDrain()
        XCTAssertTrue(detail.contentScrollView(for: .top) === previous,
                      "An empty startup table must not attach while UIKit still has old separator state")
        rows.sectionCount = 1
        table.reloadData()
        table.layoutIfNeeded()
        table.simulatesUncommittedUpdates = true
        await layoutAndDrain()
        XCTAssertTrue(detail.contentScrollView(for: .top) === previous)
        table.simulatesUncommittedUpdates = false
        table.isHidden = true
        await layoutAndDrain()
        XCTAssertTrue(detail.contentScrollView(for: .top) === previous)
        table.isHidden = false
        navigation.view.setNeedsLayout()
        host.window.layoutIfNeeded()
        XCTAssertTrue(detail.contentScrollView(for: .top) === previous,
                      "Native source attachment must never run from the parent's layout callback")
        await layoutAndDrain()
        XCTAssertTrue(detail.contentScrollView(for: .top) === table)

        table.simulatesUncommittedUpdates = true
        detail.simulatesDiscovery = true
        await layoutAndDrain()
        XCTAssertTrue(detail.contentScrollView(for: .top) === table,
                      "Detaching an observer must also wait for the old table to finish its update")
        table.simulatesUncommittedUpdates = false
        await layoutAndDrain()
        XCTAssertTrue(detail.contentScrollView(for: .top) === previous)

        detail.simulatesDiscovery = false
        navigation.view.setNeedsLayout()
        host.window.layoutIfNeeded()
        detail.simulatesDiscovery = true
        await layoutAndDrain()
        XCTAssertTrue(detail.contentScrollView(for: .top) === previous,
                      "A queued bind must revalidate its owner after Discover replaces the list")
        withExtendedLifetime(rows) {}
    }

    func test_expandedTitleHeaderObservesOnlyStoriesAndRestoresPreviousScrollSource() async throws {
        guard #available(iOS 27.1, *) else { throw XCTSkip("Requires Duo header minimization") }
        let app = NewsBlurAppDelegate()
        app.storiesCollection = StoriesCollection()
        let detail = HeaderDuoSharedTitleDetail()
        detail.appDelegate = app
        app.detailViewController = detail
        detail.navigationItem.title = "All Site Stories"
        let previousScrollSource = UIScrollView()
        detail.setContentScrollView(previousScrollSource, for: .top)
        let stories = HeaderDuoStories()
        stories.fixtureApp = app
        stories.appDelegate = app
        detail.feedDetailViewController = stories
        detail.addChild(stories)
        detail.view.addSubview(stories.view)
        stories.didMove(toParent: detail)
        let table = UITableView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let rows = HeaderDuoGeometryRows()
        table.dataSource = rows
        stories.view.addSubview(table)
        stories.storyTitlesTable = table
        let article = UIScrollView(frame: CGRect(x: 400, y: 0, width: 400, height: 600))
        article.contentSize.height = 2400
        detail.view.addSubview(article)
        let navigation = DetailNavigationController(rootViewController: detail)
        let host = try HeaderDuoTestWindow(controller: navigation)
        defer {
            host.close()
            stories.willMove(toParent: nil)
            stories.view.removeFromSuperview()
            stories.removeFromParent()
            detail.feedDetailViewController = nil
            // StoryTitlesHeaderBarLayoutTests.swift breaks reverse ownership while deferred layout still has valid dependencies.
            app.detailViewController = nil
        }
        func layout() async {
            navigation.view.setNeedsLayout()
            host.window.layoutIfNeeded()
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
        }
        await layout()
        XCTAssertTrue(detail.contentScrollView(for: .top) === table,
                      "The expanded Feeds/title header must explicitly observe the story-title list")
        article.setContentOffset(CGPoint(x: 0, y: 400), animated: false)
        await layout()
        XCTAssertTrue(detail.contentScrollView(for: .top) === table,
                      "Article scrolling must not claim the independent story-title header")

        let replacementTable = UITableView(frame: table.frame)
        replacementTable.dataSource = rows
        stories.view.addSubview(replacementTable)
        stories.storyTitlesTable = replacementTable
        await layout()
        XCTAssertTrue(detail.contentScrollView(for: .top) === replacementTable,
                      "The header must follow its current list rather than retain a replaced scroll view")

        for mode in ["compact", "discover", "ipad"] {
            detail.simulatesCompact = mode == "compact"
            detail.simulatesDiscovery = mode == "discover"
            detail.simulatesPhone = mode != "ipad"
            await layout()
            XCTAssertTrue(detail.contentScrollView(for: .top) === previousScrollSource,
                          "Leaving expanded title ownership for \(mode) must restore the previous scroll source")
            detail.simulatesCompact = false
            detail.simulatesDiscovery = false
            detail.simulatesPhone = true
            await layout()
            XCTAssertTrue(detail.contentScrollView(for: .top) === replacementTable)
        }
        let newerOwnerScroll = UIScrollView()
        detail.setContentScrollView(newerOwnerScroll, for: .top)
        detail.simulatesDiscovery = true
        await layout()
        XCTAssertTrue(detail.contentScrollView(for: .top) === newerOwnerScroll,
                      "Restoration must preserve a scroll source explicitly installed by the next owner")
        withExtendedLifetime(rows) {}
    }

    func test_expandedEmbeddedStoryListKeepsItsFooterWhileReaderOwnsSystemBar() throws {
        guard #available(iOS 27.1, *) else { throw XCTSkip("Requires Duo bars") }
        let app = NewsBlurAppDelegate()
        let detail = HeaderDuoRegularDetail()
        detail.appDelegate = app
        detail.isCompact = false
        app.detailViewController = detail
        let collection = StoriesCollection()
        collection.activeFeed = ["id": 1, "feed_title": "Synthetic embedded feed"]
        app.storiesCollection = collection
        let container = UIViewController()
        let readerItem = UIBarButtonItem(title: "Reader action", style: .plain, target: nil, action: nil)
        container.toolbarItems = [readerItem]
        let navigation = UINavigationController(rootViewController: container)
        let host = try HeaderDuoTestWindow(controller: navigation)
        defer { host.close() }
        let stories = HeaderDuoStories()
        stories.appDelegate = app
        stories.storiesCollection = collection
        detail.feedDetailViewController = stories
        container.addChild(stories)
        stories.view.frame = container.view.bounds
        container.view.addSubview(stories.view)
        stories.didMove(toParent: container)
        let header = StoryTitlesHeaderBar()
        stories.storyTitlesHeaderBar = header
        header.setup(in: stories.view)
        host.window.layoutIfNeeded()
        guard Utilities.usesSystemVerticalBar(stories.traitCollection) else {
            throw XCTSkip("Requires Duo with a system vertical bar")
        }

        // StoryTitlesHeaderBarLayoutTests.swift models the regular reader's embedded story-list column, outside the navigation stack.
        stories.perform(Selector(("configureAdaptiveStoryToolbar")))
        host.window.layoutIfNeeded()

        XCTAssertFalse(header.pillBar.isHidden, "Embedded story-list actions must remain visible while the reader owns the native bar")
        XCTAssertFalse(header.usesSystemVerticalBar)
        XCTAssertTrue(stories.toolbarItems?.isEmpty ?? true)
        XCTAssertTrue(container.toolbarItems?.first === readerItem, "Story-list actions must not replace reader bar items")
    }

    func test_duoStoryListIncludesNativeSiteSettingsAndAnchorsItsMenuToThatItem() throws {
        guard #available(iOS 27.1, *) else { throw XCTSkip("Requires Duo bars") }
        let app = NewsBlurAppDelegate()
        let detail = HeaderDuoRegularDetail()
        detail.appDelegate = app
        detail.isCompact = true
        app.detailViewController = detail
        let collection = StoriesCollection()
        collection.activeFeed = ["id": 1, "feed_title": "Synthetic Duo feed"]
        app.storiesCollection = collection
        let stories = HeaderDuoStories()
        stories.appDelegate = app
        stories.storiesCollection = collection
        stories.settingsBarButton = UIBarButtonItem(customView: UIButton(type: .custom))
        detail.feedDetailViewController = stories
        let navigation = HeaderDuoMenuNavigation(rootViewController: stories)
        app.feedsNavigationController = navigation
        let host = try HeaderDuoTestWindow(controller: navigation)
        defer { host.close() }
        let header = StoryTitlesHeaderBar()
        stories.storyTitlesHeaderBar = header
        header.setup(in: stories.view)
        host.window.layoutIfNeeded()
        guard Utilities.usesSystemVerticalBar(stories.traitCollection) else {
            throw XCTSkip("Requires Duo with a system vertical bar")
        }
        stories.perform(Selector(("configureAdaptiveStoryToolbar")))
        let items = (stories.toolbarItems ?? []) + (stories.navigationItem.leftBarButtonItems ?? []) + (stories.navigationItem.rightBarButtonItems ?? [])
        let settings = try XCTUnwrap(items.first { $0.accessibilityIdentifier == "story-list-settings" }, "Site Settings must be a visible system item, not a hidden custom navigation view")
        XCTAssertNil(settings.customView)
        XCTAssertEqual(settings.action, #selector(FeedDetailObjCViewController.doOpenSettingsMenu(_:)))

        // StoryTitlesHeaderBarLayoutTests.swift opens only the synthetic menu and never selects a site mutation.
        stories.doOpenSettingsMenu(settings)
        let presented = try XCTUnwrap(navigation.capturedPresentation)
        XCTAssertTrue(presented.popoverPresentationController?.barButtonItem === settings, "The menu must use the visible native settings item as its anchor")
    }

    func test_retainedReaderLayoutDoesNotUnhideAnotherControllersNavigationBar() {
        let app = NewsBlurAppDelegate()
        let detail = HeaderDuoRegularDetail()
        detail.appDelegate = app
        detail.isCompact = true
        app.detailViewController = detail
        let collection = StoriesCollection()
        collection.activeFeed = ["id": 1, "feed_title": "Synthetic Duo feed"]
        app.storiesCollection = collection
        let reader = HeaderDuoRetainedReader()
        reader.appDelegate = app
        reader.storyToolbar = StoryToolbar()
        reader.traverseView = UIView()
        reader.toolbarScrollHandler = StoryToolbarScrollHandler()
        let current = UIViewController()
        let item = UIBarButtonItem(title: "Current owner", style: .plain, target: nil, action: nil)
        current.toolbarItems = [item]
        let navigation = UINavigationController(rootViewController: reader)
        navigation.setViewControllers([reader, current], animated: false)
        navigation.loadViewIfNeeded()
        navigation.setNavigationBarHidden(true, animated: false)

        // StoryTitlesHeaderBarLayoutTests.swift models a late safe-area/layout callback after feeds or Discover became topmost.
        reader.perform(Selector(("updateReaderToolbarPresentation")))

        XCTAssertTrue(navigation.topViewController === current)
        XCTAssertTrue(navigation.isNavigationBarHidden, "An offscreen reader must not undo the current controller's navigation-bar choice")
        XCTAssertTrue(current.toolbarItems?.first === item)
    }

    func test_retainedReaderFoldPreservesVisibleControllersBackGesture() throws {
        let preferences = UserDefaults.standard
        let originalSwipe = preferences.object(forKey: "story_detail_swipe_left_edge")
        let originalOrientation = preferences.object(forKey: "scroll_stories_horizontally")
        defer {
            preferences.set(originalSwipe, forKey: "story_detail_swipe_left_edge")
            preferences.set(originalOrientation, forKey: "scroll_stories_horizontally")
        }
        preferences.set("none", forKey: "story_detail_swipe_left_edge")
        preferences.set(false, forKey: "scroll_stories_horizontally")

        let app = NewsBlurAppDelegate()
        let detail = HeaderDuoRegularDetail()
        detail.appDelegate = app
        detail.isCompact = true
        app.detailViewController = detail
        let collection = StoriesCollection()
        collection.activeFeed = ["id": 1, "feed_title": "Synthetic Duo feed"]
        app.storiesCollection = collection
        let reader = HeaderDuoRetainedReader()
        reader.appDelegate = app
        reader.storyToolbar = StoryToolbar()
        reader.traverseView = UIView()
        reader.toolbarScrollHandler = StoryToolbarScrollHandler()
        let navigation = UINavigationController(rootViewController: reader)
        navigation.loadViewIfNeeded()
        reader.perform(Selector(("updateReaderToolbarPresentation")))
        let gesture = try XCTUnwrap(navigation.interactivePopGestureRecognizer)
        XCTAssertFalse(gesture.isEnabled, "The reader initially applies its own disabled edge-swipe preference")

        let current = UIViewController()
        navigation.setViewControllers([reader, current], animated: false)
        gesture.isEnabled = true

        // StoryTitlesHeaderBarLayoutTests.swift models a fold callback reaching the retained reader below a newer screen.
        reader.verticalToolbar = false
        reader.perform(Selector(("updateReaderToolbarPresentation")))

        XCTAssertTrue(navigation.topViewController === current)
        XCTAssertTrue(gesture.isEnabled, "An offscreen reader must preserve the visible controller's Back gesture")

        reader.perform(Selector(("updatePopGestureForScrollOrientation")))
        XCTAssertTrue(gesture.isEnabled, "A retained reader's preference-change callback must also preserve the current gesture")

        navigation.setViewControllers([reader], animated: false)
        reader.perform(Selector(("updatePopGestureForScrollOrientation")))
        XCTAssertFalse(gesture.isEnabled, "The visible reader must still apply its own edge-swipe preference")
    }

    func test_narrowSidebarShortensFilterBeforeCompressingDiscover() throws {
        let (bar, parent) = makeBar(width: 320)
        // StoryTitlesHeaderBarLayoutTests.swift hosts glass in a window before checking its event routing.
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        controller.view.addSubview(parent)
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previousWindow?.makeKey() }
        window.layoutIfNeeded()
        // StoryTitlesHeaderBarLayoutTests.swift gives this synthetic sidebar 320 usable points even when the phone remains in landscape.
        parent.frame.origin = controller.view.safeAreaLayoutGuide.layoutFrame.origin
        settle(bar, parent: parent)
        attach(bar, name: "header-narrow-unread")

        XCTAssertEqual(bar.headerContainer.safeAreaLayoutGuide.layoutFrame.width, 320, accuracy: 0.5)
        XCTAssertEqual(title(of: bar.optionsPill), "UNREAD")
        XCTAssertGreaterThanOrEqual(bar.discoverPill.bounds.width, 40)
        assertVisibleControlsFit(bar)
        let center = bar.discoverPill.convert(CGPoint(x: bar.discoverPill.bounds.midX, y: bar.discoverPill.bounds.midY), to: parent)
        let hit = parent.hitTest(center, with: nil)
        XCTAssertTrue(hit === bar.discoverPill || hit?.isDescendant(of: bar.discoverPill) == true,
                      "Discover must receive touches through its glass group, got \(String(describing: hit))")
    }

    func test_wideSidebarKeepsFilterAndSortOrder() {
        let (bar, parent) = makeBar(width: 600)
        withExtendedLifetime(parent) {
            XCTAssertEqual(title(of: bar.optionsPill), "UNREAD · NEWEST")
            XCTAssertGreaterThanOrEqual(bar.discoverPill.bounds.width, 40)
            assertVisibleControlsFit(bar)
        }
    }

    func test_resizingRestoresSortLabelAndNeverCollapsesActions() {
        let (bar, parent) = makeBar(width: 600)
        for width: CGFloat in [320, 600, 320, 600, 320] {
            parent.frame.size.width = width
            settle(bar, parent: parent)
            XCTAssertEqual(title(of: bar.optionsPill), width == 320 ? "UNREAD" : "UNREAD · NEWEST")
            XCTAssertGreaterThanOrEqual(bar.discoverPill.bounds.width, 40)
            assertVisibleControlsFit(bar)
        }
    }

    func test_phoneWidthKeepsFullSortAndFilterAcrossPreferenceUpdates() {
        let (bar, parent) = makeBar(width: 390)
        for width: CGFloat in [300, 320, 321, 340, 360, 375, 390, 450, 600, 320] {
            parent.frame.size.width = width
            for filter in ["all", "unread"] {
                for order in ["oldest", "newest"] {
                    bar.updateOptionsPill(order: order, readFilter: filter)
                    settle(bar, parent: parent)
                    let fullTitle = "\(filter.uppercased()) · \(order.uppercased())"
                    XCTAssertEqual(bar.optionsPill.accessibilityLabel, fullTitle)
                    if let visibleTitle = title(of: bar.optionsPill), !visibleTitle.isEmpty {
                        XCTAssertTrue([filter.uppercased(), fullTitle].contains(visibleTitle))
                        if let label = bar.optionsPill.titleLabel {
                            XCTAssertEqual(displayedText(of: bar.optionsPill), visibleTitle)
                            XCTAssertGreaterThanOrEqual(label.bounds.width, label.intrinsicContentSize.width - 0.5,
                                                       "The displayed filter must fit without clipping at width \(width)")
                            let labelFrame = label.convert(label.bounds, to: bar.optionsPill)
                            XCTAssertGreaterThanOrEqual(labelFrame.minX, -0.5)
                            XCTAssertLessThanOrEqual(labelFrame.maxX, bar.optionsPill.bounds.width + 0.5)
                        } else {
                            XCTFail("A configured filter title must have a rendered label")
                        }
                    } else {
                        // StoryTitlesHeaderBarLayoutTests.swift accepts the narrow-pane chevron instead of wrapped filter text.
                        XCTAssertNotNil(bar.optionsPill.configuration?.image ?? bar.optionsPill.image(for: .normal))
                        XCTAssertGreaterThanOrEqual(bar.optionsPill.bounds.width, 44)
                        XCTAssertNil(displayedText(of: bar.optionsPill),
                                     "Icon-only mode must not leave stale filter text visible at width \(width)")
                    }
                    if width >= 390 { XCTAssertEqual(title(of: bar.optionsPill), fullTitle) }
                    XCTAssertEqual(bar.optionsPill.titleLabel?.numberOfLines, 1)
                    XCTAssertGreaterThanOrEqual(bar.discoverPill.bounds.width, 40)
                    assertVisibleControlsFit(bar)
                }
            }
        }
    }

    func test_hiddenDiscoverAndMarkReadReleaseTheirWidthForTheSortLabel() {
        let (bar, parent) = makeBar(width: 360)
        XCTAssertEqual(title(of: bar.optionsPill), "UNREAD")
        bar.updateDiscoverVisibility(isRiver: true, isEverything: true, isSocial: false, isSaved: false, isRead: false, isWidget: false, isInfrequent: false)
        settle(bar, parent: parent)
        XCTAssertTrue(bar.discoverPill.isHidden)
        XCTAssertEqual(title(of: bar.optionsPill), "UNREAD · NEWEST")
        assertVisibleControlsFit(bar)

        bar.markReadContainer.isHidden = true
        bar.updateDiscoverVisibility(isRiver: true, isEverything: false, isSocial: false, isSaved: false, isRead: false, isWidget: false, isInfrequent: false)
        settle(bar, parent: parent)
        XCTAssertEqual(title(of: bar.optionsPill), "UNREAD · NEWEST")
        XCTAssertGreaterThanOrEqual(bar.discoverPill.bounds.width, 40)
        assertVisibleControlsFit(bar)
    }

    func test_dailyBriefingRetainsItsSettingsIconAndRestoresTheWideLabel() {
        let (bar, parent) = makeBar(width: 320)
        bar.setDailyBriefingMode(true)
        for width: CGFloat in [320, 600, 320] {
            parent.frame.size.width = width
            settle(bar, parent: parent)
            XCTAssertEqual(bar.discoverPill.accessibilityLabel, "Daily Briefing Settings")
            XCTAssertEqual(title(of: bar.optionsPill), width == 320 ? "UNREAD" : "UNREAD · NEWEST")
            XCTAssertEqual(title(of: bar.discoverPill), width == 320 ? nil : "BRIEFING SETTINGS")
            XCTAssertGreaterThanOrEqual(bar.discoverPill.bounds.width, 40)
            assertVisibleControlsFit(bar)
        }
        bar.setDailyBriefingMode(false)
        settle(bar, parent: parent)
        XCTAssertEqual(bar.discoverPill.accessibilityLabel, "Related Sites")
    }

    func test_faviconsSurviveStableLayoutWithoutRecreatingViewsOrSchedulingLayout() {
        let (bar, parent) = makeBar(width: 600)
        let icon = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
        bar.updateDiscoverPill(favicons: Array(repeating: icon, count: 5))
        settle(bar, parent: parent)
        let images = bar.discoverPill.subviews.compactMap { $0 as? UIImageView }.filter { $0.image === icon }
        XCTAssertEqual(images.count, 5)
        let originalFrames = images.map(\.frame)
        var layoutCallbacks = 0
        let originalCallback = bar.headerContainer.onBoundsChange
        bar.headerContainer.onBoundsChange = { layoutCallbacks += 1; originalCallback?() }
        for _ in 0..<20 {
            bar.relayoutPills()
            bar.headerContainer.layoutIfNeeded()
        }
        XCTAssertEqual(layoutCallbacks, 0)
        XCTAssertEqual(images.map(\.frame), originalFrames)
        XCTAssertTrue(images.allSatisfy { $0.superview === bar.discoverPill })
        parent.frame.size.width = 320
        settle(bar, parent: parent)
        XCTAssertEqual(title(of: bar.optionsPill), "UNREAD")
        XCTAssertGreaterThanOrEqual(bar.discoverPill.bounds.width, 40)
        assertVisibleControlsFit(bar)
        parent.frame.size.width = 600
        settle(bar, parent: parent)
        XCTAssertEqual(bar.discoverPill.subviews.compactMap { $0 as? UIImageView }.filter { $0.image === icon }.count, 5)
    }

    func test_activeSearchColorsAndIndependentMarkActionsSurviveResizing() {
        let (bar, parent) = makeBar(width: 600)
        UIView.performWithoutAnimation { bar.setSearchActive(true) }
        let background = bar.searchPill.backgroundColor
        let foreground = bar.searchPill.tintColor
        let expandMenu = bar.markReadExpandButton.menu
        let mainMenu = bar.markReadPill.menu
        #if targetEnvironment(macCatalyst)
        XCTAssertNotNil(expandMenu)
        XCTAssertNotNil(mainMenu)
        let expandActions = expandMenu?.children.compactMap { $0 as? UIAction } ?? []
        let mainActions = mainMenu?.children.compactMap { $0 as? UIAction } ?? []
        XCTAssertEqual(mainActions.map(\.title), expandActions.map(\.title))
        XCTAssertEqual(mainActions.map(\.identifier), expandActions.map(\.identifier))
        #else
        // StoryTitlesHeaderBarLayoutTests.swift keeps iOS popovers detached from the interactive glass.
        XCTAssertNil(expandMenu)
        XCTAssertNil(mainMenu)
        XCTAssertTrue(bar.markReadPill.gestureRecognizers?.contains { $0 is UILongPressGestureRecognizer } == true)
        XCTAssertTrue(bar.markReadExpandButton.actions(forTarget: bar, forControlEvent: .touchUpInside)?.contains("handleMarkReadExpand") == true)
        #endif
        var mainTaps = 0
        bar.markReadTapHandler = { mainTaps += 1 }
        for width: CGFloat in [320, 600, 320] {
            parent.frame.size.width = width
            settle(bar, parent: parent)
            XCTAssertEqual(bar.searchPill.backgroundColor, background)
            XCTAssertEqual(bar.searchPill.tintColor, foreground)
            XCTAssertTrue(bar.isSearchActive)
            XCTAssertFalse(bar.searchContainer.isHidden)
            #if targetEnvironment(macCatalyst)
            // StoryTitlesHeaderBarLayoutTests.swift allows UIKit to copy a menu when assigning it to separate buttons.
            XCTAssertTrue(bar.markReadExpandButton.menu === expandMenu)
            XCTAssertTrue(bar.markReadPill.menu === mainMenu)
            XCTAssertTrue(bar.markReadExpandButton.showsMenuAsPrimaryAction)
            #else
            XCTAssertNil(bar.markReadExpandButton.menu)
            XCTAssertNil(bar.markReadPill.menu)
            XCTAssertFalse(bar.markReadExpandButton.showsMenuAsPrimaryAction)
            #endif
            // StoryTitlesHeaderBarLayoutTests.swift permits compound width to shrink while preserving the main target.
            XCTAssertGreaterThanOrEqual(bar.markReadPill.bounds.width, 52)
            XCTAssertLessThanOrEqual(bar.markReadContainer.bounds.width, 98.5)
            if width == 600 {
                XCTAssertEqual(bar.markReadContainer.bounds.width, 98, accuracy: 1 / max(1, bar.markReadContainer.traitCollection.displayScale))
            }
            XCTAssertEqual(bar.markReadExpandButton.frame.width, 26, accuracy: 0.01)
            XCTAssertEqual(bar.markReadPill.frame.maxX, bar.markReadContainer.bounds.width,
                           accuracy: 1 / max(1, bar.markReadContainer.traitCollection.displayScale))
            XCTAssertGreaterThan(bar.markReadPill.frame.minX, bar.markReadExpandButton.frame.maxX)
            XCTAssertLessThanOrEqual(bar.markReadPill.frame.minX - bar.markReadExpandButton.frame.maxX, 1)
            assertVisibleControlsFit(bar)
        }
        // StoryTitlesHeaderBarLayoutTests.swift invokes only this synthetic header's closure, never an account mark-all action.
        bar.markReadPill.sendActions(for: .touchUpInside)
        XCTAssertEqual(mainTaps, 1)
    }

    private func makeBar(width: CGFloat) -> (StoryTitlesHeaderBar, UIView) {
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 100))
        let bar = StoryTitlesHeaderBar()
        bar.setup(in: parent)
        bar.updateOptionsPill(order: "newest", readFilter: "unread")
        bar.updateDiscoverVisibility(isRiver: true, isEverything: false, isSocial: false, isSaved: false, isRead: false, isWidget: false, isInfrequent: false)
        settle(bar, parent: parent)
        return (bar, parent)
    }

    private func sampledRGB(_ image: UIImage, at point: CGPoint) throws -> [CGFloat] {
        let source = try XCTUnwrap(image.cgImage)
        let pixel = try XCTUnwrap(source.cropping(to: CGRect(x: point.x * image.scale, y: point.y * image.scale,
                                                            width: 1, height: 1)))
        var bytes = [UInt8](repeating: 0, count: 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                                 space: CGColorSpaceCreateDeviceRGB(),
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return bytes.prefix(3).map { CGFloat($0) / 255 }
    }

    private func settle(_ bar: StoryTitlesHeaderBar, parent: UIView) {
        // StoryTitlesHeaderBarLayoutTests.swift lets the real bounds callback and stack constraints settle after rotation.
        for _ in 0..<4 {
            parent.setNeedsLayout()
            parent.layoutIfNeeded()
            bar.relayoutPills()
            bar.headerContainer.layoutIfNeeded()
        }
    }

    private func title(of button: UIButton) -> String? {
        // StoryTitlesHeaderBarLayoutTests.swift does not fall back to cached legacy text when a configuration intentionally hides its title.
        if let configuration = button.configuration { return configuration.title }
        return button.title(for: .normal)
    }

    private func displayedText(of button: UIButton) -> String? {
        guard let label = button.titleLabel,
              let text = label.attributedText?.string ?? label.text,
              !text.isEmpty,
              label.bounds.width > 0, label.bounds.height > 0 else { return nil }
        var ancestor: UIView? = label
        while let view = ancestor {
            if view.isHidden || view.alpha <= 0.01 { return nil }
            if view === button { break }
            ancestor = view.superview
        }
        let visibleFrame = label.convert(label.bounds, to: button).intersection(button.bounds)
        return visibleFrame.isNull || visibleFrame.isEmpty ? nil : text
    }

    private func assertVisibleControlsFit(_ bar: StoryTitlesHeaderBar, file: StaticString = #filePath, line: UInt = #line) {
        let controls: [UIView] = [bar.discoverPill, bar.optionsPill, bar.searchPill, bar.markReadContainer]
        var previousRight: CGFloat = 0
        for control in controls where !control.isHidden {
            let rect = control.convert(control.bounds, to: bar.headerContainer)
            XCTAssertGreaterThanOrEqual(rect.minX, previousRight, file: file, line: line)
            XCTAssertLessThanOrEqual(rect.maxX, bar.headerContainer.bounds.width, file: file, line: line)
            XCTAssertGreaterThan(rect.width, 0, file: file, line: line)
            previousRight = rect.maxX
        }
        if !bar.searchPill.isHidden { XCTAssertGreaterThanOrEqual(bar.searchPill.bounds.width, 36, file: file, line: line) }
        if !bar.markReadContainer.isHidden {
            XCTAssertGreaterThanOrEqual(bar.markReadPill.bounds.width, 52, file: file, line: line)
            XCTAssertGreaterThanOrEqual(bar.markReadExpandButton.bounds.width, 26, file: file, line: line)
        }
    }

    private func attach(_ bar: StoryTitlesHeaderBar, name: String) {
        func display(_ layer: CALayer) {
            layer.displayIfNeeded()
            layer.sublayers?.forEach(display)
        }
        display(bar.headerContainer.layer)
        let image = UIGraphicsImageRenderer(bounds: bar.headerContainer.bounds).image { bar.headerContainer.layer.render(in: $0.cgContext) }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor private final class HeaderDuoTestWindow {
    let window: UIWindow
    let controller: UIViewController
    private weak var previousKeyWindow: UIWindow?

    init(controller: UIViewController = UIViewController()) throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        self.controller = controller
        window = UIWindow(windowScene: scene)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
    }

    func close() {
        window.isHidden = true
        previousKeyWindow?.makeKey()
    }
}

@MainActor private class HeaderDuoRegularHeightDetail: DetailViewController {
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        // StoryTitlesHeaderBarLayoutTests.swift models the inner display independently of the simulator host's traits.
        traitOverrides.verticalSizeClass = .regular
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        traitOverrides.verticalSizeClass = .regular
    }
}

@MainActor private final class HeaderDuoRegularDetail: HeaderDuoRegularHeightDetail {
    override var isPhone: Bool { true }
    override var storyTitlesInGrid: Bool { true }
    override var areStoryTitlesCollapsed: Bool { false }
    override func addDiscoverPreviewBackButton() {}
}

@MainActor private final class HeaderPadGridDetail: DetailViewController {
    override var isPhone: Bool { false }
    override var storyTitlesInGrid: Bool { true }
    override var areStoryTitlesCollapsed: Bool { false }
    override func addDiscoverPreviewBackButton() {}
}

@MainActor private final class HeaderDuoTiledSidebarDetail: HeaderDuoRegularHeightDetail {
    var simulatesPhone = true
    var simulatesCollapsedTitles = true
    override var isPhone: Bool { simulatesPhone }
    override var storyTitlesOnLeft: Bool { true }
    override var areStoryTitlesCollapsed: Bool { simulatesCollapsedTitles }
    override func addDiscoverPreviewBackButton() {}
}

@MainActor private final class HeaderDuoStories: FeedDetailViewController {
    var fixtureApp: NewsBlurAppDelegate?
    override var appDelegate: NewsBlurAppDelegate! {
        get { super.appDelegate }
        set { super.appDelegate = fixtureApp ?? newValue }
    }
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 640, height: 440)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
}

@MainActor private final class HeaderUnselectedSourceStories: FeedDetailViewController {
    override var isPhone: Bool { appDelegate?.detailViewController?.isPhone ?? false }
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 475, height: 669)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillDisappear(_ animated: Bool) {}
    override func viewDidDisappear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
}

@MainActor private final class HeaderDuoGeometryRows: NSObject, UITableViewDataSource {
    var backgroundColor: UIColor?
    var rowCount = 12
    var sectionCount = 1
    func numberOfSections(in tableView: UITableView) -> Int { sectionCount }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rowCount }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = "Story \(indexPath.row + 1)"
        if let backgroundColor { cell.backgroundColor = backgroundColor }
        return cell
    }
}

@MainActor private final class HeaderDuoUpdatingTable: UITableView {
    var simulatesUncommittedUpdates = false
    override var hasUncommittedUpdates: Bool { simulatesUncommittedUpdates || super.hasUncommittedUpdates }
}

@MainActor private final class HeaderDuoFullscreenTitleOwner: DetailViewController {
    var fullscreen = true
    override var isDuoFullscreenReader: Bool { fullscreen }
}

@MainActor private final class HeaderDuoFullscreenTitleStories: FeedDetailViewController {
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillDisappear(_ animated: Bool) {}
    override func viewDidDisappear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
}

@MainActor private final class HeaderDuoHorizontalBarNavigation: UINavigationController {
    var reportsHorizontalBarTraits = false
    override var traitCollection: UITraitCollection {
        reportsHorizontalBarTraits ? UITraitCollection(traitsFrom: [UITraitCollection(userInterfaceIdiom: .phone),
            UITraitCollection(horizontalSizeClass: .compact), UITraitCollection(verticalSizeClass: .regular)]) : super.traitCollection
    }
}

@MainActor private final class HeaderDuoMeasuredSafeAreaView: UIView {
    weak var owner: UIViewController?
    var nativeSafeTop: CGFloat = 82
    override var safeAreaInsets: UIEdgeInsets {
        var insets = super.safeAreaInsets
        insets.top = max(0, nativeSafeTop + (owner?.additionalSafeAreaInsets.top ?? 0))
        return insets
    }
}

@MainActor private final class HeaderDuoSharedTitleDetail: DetailViewController {
    var recordsScrollSources = false
    private var recordedScrollSource: UIScrollView?
    override func setContentScrollView(_ scrollView: UIScrollView?, for edge: NSDirectionalRectEdge) {
        if recordsScrollSources && edge == .top {
            recordedScrollSource = scrollView
        } else {
            super.setContentScrollView(scrollView, for: edge)
        }
    }
    override func contentScrollView(for edge: NSDirectionalRectEdge) -> UIScrollView? {
        recordsScrollSources && edge == .top ? recordedScrollSource : super.contentScrollView(for: edge)
    }
    var simulatesPhone = true
    var simulatesCompact = false
    var simulatesDiscovery = false
    override var isPhone: Bool { simulatesPhone }
    override var isPhoneOrCompact: Bool { simulatesCompact }
    override var isDiscoverSitesVisible: Bool { simulatesDiscovery }
    override var storyTitlesOnLeft: Bool { false }
    override var hasVisibleStoryForSidebarLayout: Bool { false }
    override var behaviorString: String { "tile" }
    override var feedsWidth: CGFloat {
        get { 320 }
        set {}
    }
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 951, height: 669)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    // StoryTitlesHeaderBarLayoutTests.swift preserves Detail's real layout callback while excluding account loading and preferences writes.
}

@MainActor private final class HeaderDuoFeedReturnSplit: SplitViewController {
    private var primaryVisible = false
    var shownColumns: [UISplitViewController.Column] = []
    override var displayMode: UISplitViewController.DisplayMode { primaryVisible ? .oneOverSecondary : .secondaryOnly }
    override func show(_ column: UISplitViewController.Column) {
        shownColumns.append(column)
        if column == .primary { primaryVisible = true }
    }
}

@MainActor private final class HeaderDuoMenuNavigation: UINavigationController {
    var capturedPresentation: UIViewController?
    var capturedShownController: UIViewController?
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        // StoryTitlesHeaderBarLayoutTests.swift records the built menu without opening UI or invoking account actions.
        capturedPresentation = viewControllerToPresent
        completion?()
    }
    override func show(_ vc: UIViewController, sender: Any?) {
        capturedShownController = vc
    }
}

@MainActor private final class HeaderDuoRetainedReader: StoryPagesViewController {
    var verticalToolbar = true
    override var usesVerticalReaderToolbar: Bool { verticalToolbar }
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 440, height: 640)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
    override func viewSafeAreaInsetsDidChange() {}
    override func updateStoryTitleNavigationButtons() {}
    override func updateStatusBarState() {}
    override func setNextPreviousButtons() {}
}
