import XCTest
import UIKit
import WebKit

@testable import NewsBlur

@MainActor final class Test_StoryKeyboardScroll: XCTestCase {
    func test_spaceUsesWebDefaultAndConfiguredPercentageInBothDirections() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "space_scroll_spacing")
        defer { defaults.set(saved, forKey: "space_scroll_spacing") }
        defaults.removeObject(forKey: "space_scroll_spacing")
        let page = KeyboardGeometryPage()
        page.trackedScroll.contentOffset.y = 600
        page.scrollPageDown(nil)
        XCTAssertEqual(page.trackedScroll.contentOffset.y, 1000, accuracy: 0.1)
        defaults.set(20, forKey: "space_scroll_spacing")
        page.scrollPageUp(nil)
        XCTAssertEqual(page.trackedScroll.contentOffset.y, 800, accuracy: 0.1)
    }

    func test_spaceAtBottomUsesNextUnreadInsteadOfNextReadStory() {
        let page = KeyboardGeometryPage()
        let app = KeyboardRoutingApp()
        let pages = KeyboardRoutingPages()
        app.reader = pages
        page.appDelegate = app
        pages.currentPage = page
        page.trackedScroll.contentOffset.y = 4000
        page.scrollPageDown(nil)
        XCTAssertEqual(pages.nextUnreadCount, 1)
        XCTAssertEqual(pages.nextCount, 0)
    }

    func test_shiftSpaceAtTopOpensPreviousStoryLikeWeb() {
        let page = KeyboardGeometryPage()
        let app = KeyboardRoutingApp()
        let pages = KeyboardRoutingPages()
        app.reader = pages
        page.appDelegate = app
        pages.currentPage = page
        page.trackedScroll.contentInset.top = 80
        page.trackedScroll.contentOffset.y = -80
        page.scrollPageUp(nil)
        XCTAssertEqual(pages.previousCount, 1)
        XCTAssertEqual(pages.previousHistoryCount, 0)
    }

    func test_spaceUsesVisibleHeightAndIncludesBottomInsetInItsLimit() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "space_scroll_spacing")
        defer { defaults.set(saved, forKey: "space_scroll_spacing") }
        defaults.set(40, forKey: "space_scroll_spacing")
        let page = KeyboardGeometryPage()
        page.trackedScroll.contentInset = UIEdgeInsets(top: 80, left: 0, bottom: 20, right: 0)
        page.trackedScroll.contentOffset.y = 600
        page.scrollPageDown(nil)
        XCTAssertEqual(page.trackedScroll.contentOffset.y, 960, accuracy: 0.1)
        page.trackedScroll.contentOffset.y = 3950
        page.scrollPageDown(nil)
        XCTAssertEqual(page.trackedScroll.contentOffset.y, 4020, accuracy: 0.1)
    }

    func test_arrivingAtEitherBoundaryDoesNotSkipTheFinalScreen() {
        let page = KeyboardGeometryPage()
        let app = KeyboardRoutingApp()
        let pages = KeyboardRoutingPages()
        app.reader = pages
        page.appDelegate = app
        pages.currentPage = page
        page.trackedScroll.contentInset.top = 80
        page.trackedScroll.contentOffset.y = 3990
        page.scrollPageDown(nil)
        XCTAssertEqual(page.trackedScroll.contentOffset.y, 4000, accuracy: 0.1)
        XCTAssertEqual(pages.nextUnreadCount, 0)
        page.scrollPageDown(nil)
        XCTAssertEqual(pages.nextUnreadCount, 1)

        page.trackedScroll.contentOffset.y = -70
        page.scrollPageUp(nil)
        XCTAssertEqual(page.trackedScroll.contentOffset.y, -80, accuracy: 0.1)
        XCTAssertEqual(pages.previousCount, 0)
        page.scrollPageUp(nil)
        XCTAssertEqual(pages.previousCount, 1)
    }

    func test_spaceOnShortStoryAdvancesWithoutScrollingToANegativeBottom() {
        let page = KeyboardGeometryPage()
        let app = KeyboardRoutingApp()
        let pages = KeyboardRoutingPages()
        app.reader = pages
        page.appDelegate = app
        pages.currentPage = page
        page.trackedScroll.contentSize.height = 200
        page.scrollPageDown(nil)
        XCTAssertEqual(pages.nextUnreadCount, 1)
        XCTAssertEqual(page.trackedScroll.contentOffset.y, 0)
    }

    func test_fractionalBottomGeometryStillAdvancesToUnread() {
        let page = KeyboardGeometryPage()
        let app = KeyboardRoutingApp()
        let pages = KeyboardRoutingPages()
        app.reader = pages
        page.appDelegate = app
        pages.currentPage = page
        page.trackedScroll.contentInset.bottom = 40
        page.trackedScroll.contentSize.height = 5000.2
        page.trackedScroll.contentOffset.y = 4040
        page.scrollPageDown(nil)
        XCTAssertEqual(pages.nextUnreadCount, 1)
    }

    func test_emptyUnloadedPlaceholderAndAdjacentPagesCannotNavigate() {
        let page = KeyboardGeometryPage()
        let app = KeyboardRoutingApp()
        let pages = KeyboardRoutingPages()
        app.reader = pages
        page.appDelegate = app
        pages.currentPage = page
        page.trackedScroll.contentSize.height = 0
        page.scrollPageDown(nil)
        page.scrollPageUp(nil)
        page.trackedScroll.contentSize.height = 200
        page.hasStory = false
        page.scrollPageDown(nil)
        page.scrollPageUp(nil)
        page.hasStory = true
        page.pageIndex = -1
        page.scrollPageDown(nil)
        page.scrollPageUp(nil)
        page.pageIndex = 0
        pages.currentPage = KeyboardGeometryPage()
        page.scrollPageDown(nil)
        page.scrollPageUp(nil)
        XCTAssertEqual(pages.nextUnreadCount, 0)
        XCTAssertEqual(pages.previousCount, 0)
        XCTAssertEqual(page.trackedScroll.contentOffset.y, 0)
    }

    func test_invalidPagingPreferencesFallBackToWebDefault() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "space_scroll_spacing")
        defer { defaults.set(saved, forKey: "space_scroll_spacing") }
        let page = KeyboardGeometryPage()
        for invalid in [0, -10, 101, "invalid"] as [Any] {
            defaults.set(invalid, forKey: "space_scroll_spacing")
            page.trackedScroll.contentOffset.y = 600
            page.scrollPageDown(nil)
            XCTAssertEqual(page.trackedScroll.contentOffset.y, 1000, accuracy: 0.1)
        }
    }

    func test_readerShortcutsResolveWhenAnotherSplitPaneOwnsKeyboardFocus() throws {
        let pane = KeyboardPaneProbe()
        let app = KeyboardRoutingApp()
        let pages = KeyboardRoutingPages()
        app.reader = pages
        pane.appDelegate = app
        pane.loadViewIfNeeded()
        pane.storyVisible = true
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = pane
        pane.addChild(pages)
        pane.view.addSubview(pages.view)
        pages.didMove(toParent: pane)
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKey() }
        XCTAssertTrue(pane.becomeFirstResponder())

        for input in [UIKeyCommand.inputDownArrow, UIKeyCommand.inputUpArrow, "s"] {
            let command = try XCTUnwrap(pane.keyCommands?.first { $0.input == input && $0.modifierFlags.isEmpty },
                                       "A focused split pane must expose the visible reader's \(input) shortcut")
            let action = try XCTUnwrap(command.action)
            XCTAssertTrue(command.wantsPriorityOverSystemBehavior)
            XCTAssertTrue(pane.canPerformAction(action, withSender: command))
            XCTAssertTrue(pane.responds(to: action))
            XCTAssertTrue(pane.isFirstResponder)
            XCTAssertTrue(UIApplication.shared.sendAction(action, to: nil, from: command, for: nil))
        }
        XCTAssertEqual(pages.nextCount, 1)
        XCTAssertEqual(pages.previousCount, 1)
        XCTAssertEqual(pages.savedCount, 1)
    }

    func test_everyStoryShortcutResolvesWhenTheStoryListOwnsKeyboardFocus() throws {
        // Forum #13881: on the Mac, J and V beeped after clicking a story title because only the reader pane registered them.
        let pane = KeyboardPaneProbe()
        let app = KeyboardRoutingApp()
        let pages = KeyboardRoutingPages()
        let page = KeyboardScrollPageProbe()
        page.pageIndex = 0
        pages.currentPage = page
        app.reader = pages
        pane.appDelegate = app
        pane.loadViewIfNeeded()
        pane.storyVisible = true
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = pane
        pane.addChild(pages)
        pane.view.addSubview(pages.view)
        pages.didMove(toParent: pane)
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKey() }
        XCTAssertTrue(pane.becomeFirstResponder())

        for (input, flags) in Self.mirroredStoryShortcuts {
            let command = try XCTUnwrap(pane.keyCommands?.first { $0.input == input && $0.modifierFlags == flags },
                                       "A focused story list must expose the visible reader's \(input) shortcut")
            let action = try XCTUnwrap(command.action)
            XCTAssertTrue(command.wantsPriorityOverSystemBehavior)
            XCTAssertTrue(pane.canPerformAction(action, withSender: command), "\(input) should be enabled")
            XCTAssertTrue(UIApplication.shared.sendAction(action, to: nil, from: command, for: nil))
        }
        XCTAssertEqual(pages.nextCount, 1)
        XCTAssertEqual(pages.previousCount, 1)
        XCTAssertEqual(pages.nextUnreadCount, 1)
        XCTAssertEqual(pages.unreadToggleCount, 2)
        XCTAssertEqual(pages.originalCount, 2)
        XCTAssertEqual(pages.trainerCount, 1)
        XCTAssertEqual(pages.textViewCount, 1)
        XCTAssertEqual(page.pageDownCount, 1)
        XCTAssertEqual(page.pageUpCount, 1)
        XCTAssertEqual(page.commentCount, 1)
        XCTAssertEqual(page.shareCount, 1)
    }

    func test_mirroredStoryShortcutsLeaveSearchTypingAndHiddenReadersAlone() throws {
        let pane = KeyboardPaneProbe()
        let app = KeyboardRoutingApp()
        let pages = KeyboardRoutingPages()
        app.reader = pages
        pane.appDelegate = app
        pane.storyVisible = true
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = pane
        pane.addChild(pages)
        pane.view.addSubview(pages.view)
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKey() }
        let commands = Self.mirroredStoryShortcuts.compactMap { input, flags in
            pane.keyCommands?.first { $0.input == input && $0.modifierFlags == flags }
        }
        XCTAssertEqual(commands.count, Self.mirroredStoryShortcuts.count)
        let search = UISearchTextField(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        pane.view.addSubview(search)
        XCTAssertTrue(search.becomeFirstResponder())
        for command in commands { XCTAssertFalse(pane.canPerformAction(try XCTUnwrap(command.action), withSender: command)) }
        search.resignFirstResponder()
        for command in commands { XCTAssertTrue(pane.canPerformAction(try XCTUnwrap(command.action), withSender: command)) }
        pages.view.isHidden = true
        for command in commands { XCTAssertFalse(pane.canPerformAction(try XCTUnwrap(command.action), withSender: command)) }
        pages.view.isHidden = false
        pane.storyVisible = false
        for command in commands { XCTAssertFalse(pane.canPerformAction(try XCTUnwrap(command.action), withSender: command)) }
    }

    func test_storyListNextUnreadOpensTheFirstUnreadBeforeAStoryIsOpen() throws {
        let pane = KeyboardPaneProbe()
        let app = KeyboardRoutingApp()
        let pages = KeyboardRoutingPages()
        app.reader = pages
        app.storiesCollection = StoriesCollection()
        app.storiesCollection.storyLocationsCount = 3
        pane.appDelegate = app
        pane.feedVisible = true
        pane.loadViewIfNeeded()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = pane
        pane.addChild(pages)
        pane.view.addSubview(pages.view)
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKey() }
        XCTAssertTrue(pane.becomeFirstResponder())

        let opensFromTheList: Set<String> = ["j", "k", "n"]
        for (input, flags) in Self.mirroredStoryShortcuts {
            let command = try XCTUnwrap(pane.keyCommands?.first { $0.input == input && $0.modifierFlags == flags })
            let action = try XCTUnwrap(command.action)
            let expected = flags.isEmpty && opensFromTheList.contains(input)
            XCTAssertEqual(pane.canPerformAction(action, withSender: command), expected, "\(input) with no story open")
        }
        let next = try XCTUnwrap(pane.keyCommands?.first { $0.input == "n" && $0.modifierFlags.isEmpty })
        XCTAssertTrue(UIApplication.shared.sendAction(try XCTUnwrap(next.action), to: nil, from: next, for: nil))
        XCTAssertEqual(pages.nextUnreadCount, 1)

        app.storiesCollection.storyLocationsCount = 0
        XCTAssertFalse(pane.canPerformAction(try XCTUnwrap(next.action), withSender: next))
    }

    private static let mirroredStoryShortcuts: [(String, UIKeyModifierFlags)] = [
        ("j", []), ("k", []), ("n", []), ("u", []), ("m", []), ("o", []), ("v", []), ("t", []), ("\r", .shift),
        (" ", []), (" ", .shift), ("c", []), ("s", .shift),
    ]

    func test_storyPaneArrowsCanSelectTheFirstArticleBeforeOneIsOpen() throws {
        let pane = KeyboardPaneProbe()
        let app = KeyboardRoutingApp()
        app.reader = KeyboardRoutingPages()
        app.storiesCollection = StoriesCollection()
        app.storiesCollection.storyLocationsCount = 3
        pane.appDelegate = app
        pane.feedVisible = true
        pane.loadViewIfNeeded()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = pane
        pane.addChild(app.reader!)
        pane.view.addSubview(app.reader!.view)
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKey() }
        for input in [UIKeyCommand.inputDownArrow, UIKeyCommand.inputUpArrow] {
            let command = try XCTUnwrap(pane.keyCommands?.first { $0.input == input && $0.modifierFlags.isEmpty })
            XCTAssertTrue(pane.canPerformAction(try XCTUnwrap(command.action), withSender: command))
        }
        let save = try XCTUnwrap(pane.keyCommands?.first { $0.input == "s" && $0.modifierFlags.isEmpty })
        XCTAssertFalse(pane.canPerformAction(try XCTUnwrap(save.action), withSender: save))
    }

    func test_searchTypingAndDialogsKeepTheirKeyboardInput() throws {
        let pane = KeyboardPaneProbe()
        let app = KeyboardRoutingApp()
        let pages = KeyboardRoutingPages()
        app.reader = pages
        pane.appDelegate = app
        pane.storyVisible = true
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = pane
        pane.addChild(pages)
        pane.view.addSubview(pages.view)
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKey() }
        let search = UISearchTextField(frame: CGRect(x: 0, y: 0, width: 300, height: 44))
        pane.view.addSubview(search)
        XCTAssertTrue(search.becomeFirstResponder())
        let commands = (pane.keyCommands ?? []).filter { [UIKeyCommand.inputDownArrow, UIKeyCommand.inputUpArrow, "s"].contains($0.input ?? "") && $0.modifierFlags.isEmpty }
        XCTAssertEqual(commands.count, 3)
        for command in commands {
            XCTAssertFalse(pane.canPerformAction(try XCTUnwrap(command.action), withSender: command))
        }
        search.resignFirstResponder()
        for command in commands {
            XCTAssertTrue(pane.canPerformAction(try XCTUnwrap(command.action), withSender: command))
        }
        pane.modal = UIViewController()
        for command in commands {
            XCTAssertFalse(pane.canPerformAction(try XCTUnwrap(command.action), withSender: command))
        }
    }

    func test_hiddenCachedReaderDoesNotInterceptSidebarShortcuts() throws {
        let pane = KeyboardPaneProbe()
        let app = KeyboardRoutingApp()
        let pages = KeyboardRoutingPages()
        app.reader = pages
        pane.appDelegate = app
        pane.storyVisible = true
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = pane
        pane.addChild(pages)
        pane.view.addSubview(pages.view)
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKey() }
        let commands = (pane.keyCommands ?? []).filter { [UIKeyCommand.inputDownArrow, UIKeyCommand.inputUpArrow, "s"].contains($0.input ?? "") && $0.modifierFlags.isEmpty }
        for command in commands { XCTAssertTrue(pane.canPerformAction(try XCTUnwrap(command.action), withSender: command)) }
        pages.view.isHidden = true
        for command in commands { XCTAssertFalse(pane.canPerformAction(try XCTUnwrap(command.action), withSender: command)) }
        pages.view.isHidden = false
        pages.view.removeFromSuperview()
        for command in commands { XCTAssertFalse(pane.canPerformAction(try XCTUnwrap(command.action), withSender: command)) }
    }

    func test_optionArrowsKeepTheirExistingFeedNavigationCommands() throws {
        let storyboard = UIStoryboard(name: "MainInterface", bundle: Bundle(for: FeedsViewController.self))
        let pane = try XCTUnwrap(storyboard.instantiateViewController(withIdentifier: "FeedsViewController") as? FeedsViewController)
        pane.loadViewIfNeeded()
        for (input, selector) in [(UIKeyCommand.inputDownArrow, "selectNextFeed:"), (UIKeyCommand.inputUpArrow, "selectPreviousFeed:")] {
            let command = try XCTUnwrap(pane.keyCommands?.first { $0.input == input && $0.modifierFlags == .alternate })
            XCTAssertEqual(command.action, NSSelectorFromString(selector))
        }
    }

    func test_readerShortcutsDoNotInterceptSidebarNavigationWithoutAStory() throws {
        let pane = KeyboardPaneProbe()
        pane.loadViewIfNeeded()
        pane.storyVisible = false
        for input in [UIKeyCommand.inputDownArrow, UIKeyCommand.inputUpArrow, "s"] {
            let command = try XCTUnwrap(pane.keyCommands?.first { $0.input == input && $0.modifierFlags.isEmpty })
            XCTAssertFalse(pane.canPerformAction(try XCTUnwrap(command.action), withSender: command))
        }
    }

    func test_pageDownShortcutResolvesAndScrollsOnlyCurrentPage() {
        assertShortcutScrollsCurrentPage(up: false)
    }

    func test_pageUpShortcutResolvesAndScrollsOnlyCurrentPage() {
        assertShortcutScrollsCurrentPage(up: true)
    }

    func test_scrollShortcutsAreDisabledWithoutAnActiveStory() {
        let pages = StoryPagesViewController()
        let page = KeyboardScrollPageProbe()
        page.pageIndex = -1
        pages.currentPage = page

        for action in ["scrollPageDown:", "scrollPageUp:"] {
            XCTAssertFalse(pages.canPerformAction(NSSelectorFromString(action), withSender: nil))
        }
    }

    private func assertShortcutScrollsCurrentPage(up: Bool) {
        let pages = StoryPagesViewController()
        let page = KeyboardScrollPageProbe()
        page.pageIndex = 0
        let previous = KeyboardScrollPageProbe()
        let next = KeyboardScrollPageProbe()
        pages.currentPage = page
        pages.previousPage = previous
        pages.nextPage = next

        // StoryKeyboardScrollTests.swift exercises the selectors registered by StoryPagesObjCViewController.m without loading three web views.
        let action = NSSelectorFromString(up ? "scrollPageUp:" : "scrollPageDown:")
        let command = UIKeyCommand(input: " ", modifierFlags: up ? .shift : [], action: action)
        XCTAssertTrue(pages.canPerformAction(action, withSender: command))
        guard pages.responds(to: action) else {
            XCTFail("The enabled \(NSStringFromSelector(action)) keyboard action has no responder implementation")
            return
        }

        pages.perform(action, with: command)

        XCTAssertEqual(page.pageDownCount, up ? 0 : 1)
        XCTAssertEqual(page.pageUpCount, up ? 1 : 0)
        XCTAssertTrue(page.lastSender === command)
        XCTAssertEqual(previous.pageDownCount + previous.pageUpCount, 0)
        XCTAssertEqual(next.pageDownCount + next.pageUpCount, 0)
    }
}

@MainActor private final class KeyboardPaneProbe: FeedsViewController {
    var storyVisible = false
    var feedVisible = false
    var modal: UIViewController?
    override var isStoryShown: Bool { storyVisible }
    override var isFeedShown: Bool { feedVisible }
    override var presentedViewController: UIViewController? { modal }
    override func loadView() { view = UIView() }
    override func viewDidLoad() {
        // StoryKeyboardScrollTests.swift isolates shared keyboard registration from feed fetching and storyboard outlets.
        let selector = #selector(UIViewController.viewDidLoad)
        let implementation = class_getMethodImplementation(BaseViewController.self, selector)!
        typealias Call = @convention(c) (AnyObject, Selector) -> Void
        unsafeBitCast(implementation, to: Call.self)(self, selector)
    }
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
}

@MainActor private final class KeyboardRoutingApp: NewsBlurAppDelegate {
    var reader: StoryPagesViewController?
    override var storyPagesViewController: StoryPagesViewController! {
        get { reader }
        set { reader = newValue }
    }
}

@MainActor private final class KeyboardRoutingPages: StoryPagesViewController {
    var nextCount = 0
    var previousCount = 0
    var previousHistoryCount = 0
    var savedCount = 0
    var nextUnreadCount = 0
    var unreadToggleCount = 0
    var originalCount = 0
    var trainerCount = 0
    var textViewCount = 0
    override func loadView() { view = UIView(frame: CGRect(x: 400, y: 0, width: 400, height: 600)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
    override func changeToNextPage(_ sender: Any!) { nextCount += 1 }
    override func changeToPreviousPage(_ sender: Any!) { previousCount += 1 }
    override func doPreviousStory(_ sender: Any!) { previousCount += 1; previousHistoryCount += 1 }
    override func toggleStorySaved(_ sender: Any!) { savedCount += 1 }
    override func doNextUnreadStory(_ sender: Any!) { nextUnreadCount += 1 }
    override func toggleStoryUnread(_ sender: Any!) { unreadToggleCount += 1 }
    override func showOriginalSubview(_ sender: Any!) { originalCount += 1 }
    override func openStoryTrainerFromKeyboard(_ sender: Any!) { trainerCount += 1 }
    override func toggleTextView(_ sender: Any!) { textViewCount += 1 }
}

@MainActor private final class KeyboardGeometryPage: StoryDetailViewController {
    let trackedScroll = KeyboardGeometryScroll()
    init() {
        super.init(nibName: nil, bundle: nil)
        appDelegate = nil
        let web = KeyboardGeometryWeb(frame: .zero, configuration: WKWebViewConfiguration())
        web.trackedScroll = trackedScroll
        webView = web
        pageIndex = 0
        hasStory = true
        trackedScroll.frame = CGRect(x: 0, y: 0, width: 600, height: 1000)
        trackedScroll.contentSize = CGSize(width: 600, height: 5000)
    }
    required init?(coder: NSCoder) { super.init(coder: coder) }
    deinit {
        // StoryKeyboardScrollTests.swift does not install the production web view KVO observer.
        webView = nil
    }
}

@MainActor private final class KeyboardGeometryWeb: WKWebView {
    var trackedScroll = KeyboardGeometryScroll()
    override var scrollView: UIScrollView { trackedScroll }
}

@MainActor private final class KeyboardGeometryScroll: UIScrollView {
    override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        // StoryKeyboardScrollTests.swift captures the requested destination without a display animation.
        super.setContentOffset(contentOffset, animated: false)
    }
}

@MainActor private final class KeyboardScrollPageProbe: StoryDetailViewController {
    var pageDownCount = 0
    var pageUpCount = 0
    var commentCount = 0
    var shareCount = 0
    var lastSender: AnyObject?

    override func scrollPageDown(_ sender: Any!) {
        pageDownCount += 1
        lastSender = sender as AnyObject?
    }

    override func scrollPageUp(_ sender: Any!) {
        pageUpCount += 1
        lastSender = sender as AnyObject?
    }

    override func scrolltoComment() { commentCount += 1 }
    override func openShareDialog() { shareCount += 1 }
}
