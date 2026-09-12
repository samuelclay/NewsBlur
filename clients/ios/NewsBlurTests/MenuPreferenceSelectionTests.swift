import XCTest
import UIKit

@testable import NewsBlur

@MainActor final class Test_MenuPreferenceSelection: XCTestCase {
    private let key = "default_mark_read_filter"
    private let values = ["scroll", "selection", "after1", "after2", "after3", "after5", "after10", "after30", "after60", "manually"]
    private var savedValue: Any?

    override func setUp() {
        super.setUp()
        let bundleID = Bundle(for: NewsBlurAppDelegate.self).bundleIdentifier!
        savedValue = UserDefaults.standard.persistentDomain(forName: bundleID)?[key]
        UserDefaults.standard.set("scroll", forKey: key)
    }

    override func tearDown() {
        if let savedValue {
            UserDefaults.standard.set(savedValue, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
        savedValue = nil
        super.tearDown()
    }

    func test_selectionMovesCheckmarkWithoutClosingMenu() throws {
        let fixture = try makeMenu()
        let menu = fixture.menu
        let table = try XCTUnwrap(menu.menuTableView)
        let originalCell = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 0, section: 0)))
        let selectedCell = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 1, section: 0)))
        XCTAssertEqual(originalCell.accessoryType, .checkmark)

        select(1, in: menu)

        XCTAssertEqual(UserDefaults.standard.string(forKey: key), "selection")
        XCTAssertEqual(menu.checkedRow, 1)
        XCTAssertEqual(originalCell.accessoryType, .none)
        XCTAssertEqual(selectedCell.accessoryType, .checkmark)
        XCTAssertTrue(fixture.navigation.topViewController === menu)
        XCTAssertFalse(FeedDetailObjCViewController().isMarkReadOnScroll)
    }

    func test_everyTimingOptionUpdatesVisibleSelectionAndReadPolicy() throws {
        let fixture = try makeMenu()
        let reader = FeedDetailObjCViewController()
        for index in [1, 9, 2, 3, 4, 5, 6, 7, 8, 0, 0] {
            select(index, in: fixture.menu)
            XCTAssertEqual(UserDefaults.standard.string(forKey: key), values[index])
            XCTAssertEqual(fixture.menu.checkedRow, index)
            for row in values.indices {
                let cell = fixture.menu.tableView(fixture.menu.menuTableView, cellForRowAt: IndexPath(row: row, section: 0))
                XCTAssertEqual(cell.accessoryType, row == index ? .checkmark : .none)
            }
            XCTAssertEqual(reader.isMarkReadOnScroll, index == 0)
            XCTAssertEqual(reader.isMarkReadManually, index == 9)
            XCTAssertEqual(reader.markReadAfterInterval, Double(values[index].dropFirst(5)) ?? 0)
        }
    }

    func test_reopeningMenuKeepsNewSelection() throws {
        let fixture = try makeMenu()
        select(1, in: fixture.menu)
        let reopened = try makeMenu()
        XCTAssertEqual(reopened.menu.checkedRow, 1)
    }

    func test_actionMenuRunsHandlerWithoutAddingCheckmark() {
        let menu = MenuViewController()
        var calls = 0
        menu.addTitle("Action", iconName: "menu_icn_markread.png", selectionShouldDismiss: false) {
            calls += 1
        }
        menu.loadViewIfNeeded()
        select(0, in: menu)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(menu.checkedRow, -1)
        XCTAssertEqual(menu.tableView(menu.menuTableView, cellForRowAt: IndexPath(row: 0, section: 0)).accessoryType, .none)
    }

    func test_submenuCanSelectFromUnknownStoredValue() throws {
        UserDefaults.standard.set("unknown", forKey: key)
        let fixture = try makeMenu()
        XCTAssertEqual(fixture.menu.checkedRow, -1)
        select(1, in: fixture.menu)
        XCTAssertEqual(fixture.menu.checkedRow, 1)
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), "selection")
    }

    func test_submenuDoesNotRetainItselfAfterNavigationEnds() throws {
        weak var releasedMenu: MenuViewController?
        autoreleasepool {
            do {
                let fixture = try makeMenu()
                releasedMenu = fixture.menu
                select(1, in: fixture.menu)
                fixture.navigation.setViewControllers([], animated: false)
            } catch {
                XCTFail("MenuPreferenceSelectionTests.swift could not create its menu: \(error)")
            }
        }
        XCTAssertNil(releasedMenu)
    }

    #if targetEnvironment(macCatalyst)
    func test_catalystSettingsPopoverRetainsTheActualNativeToolbarAnchorAtDifferentWidths() throws {
        let fixture = makeAnchorFixture()
        defer { fixture.app.feedsNavigationController = nil; fixture.navigation.capturedPresentation = nil }
        let toolbar = NSToolbar(identifier: "MenuPreferenceSelectionTests")
        let item = try XCTUnwrap(ToolbarDelegate().toolbar(toolbar, itemForItemIdentifier: .feedDetailSettings, willBeInsertedIntoToolbar: false))
        let action = try XCTUnwrap(item.action)
        XCTAssertTrue(fixture.reader.responds(to: action))
        for width: CGFloat in [340, 700, 1100, 340] {
            fixture.navigation.view.frame.size.width = width
            fixture.reader.perform(action, with: item)
            let presentation = try XCTUnwrap(fixture.navigation.capturedPresentation)
            let popover = try XCTUnwrap(presentation.popoverPresentationController)
            XCTAssertEqual(presentation.modalPresentationStyle, .popover)
            XCTAssertTrue(popover.sourceItem === item, "MenuPreferenceSelectionTests.swift must retain the real toolbar source as its position changes with the window")
        }
    }

    func test_catalystSettingsPopoverAnchorsToTheActualViewSenderAfterItMoves() throws {
        let fixture = makeAnchorFixture()
        defer { fixture.app.feedsNavigationController = nil; fixture.navigation.capturedPresentation = nil }
        let button = UIButton(type: .custom)
        fixture.reader.view.addSubview(button)
        for origin in [CGPoint(x: 18, y: 24), CGPoint(x: 245, y: 62), CGPoint(x: 80, y: 30)] {
            button.frame = CGRect(origin: origin, size: CGSize(width: 28, height: 28))
            fixture.reader.openSettingsMenu(button)
            let presentation = try XCTUnwrap(fixture.navigation.capturedPresentation)
            let popover = try XCTUnwrap(presentation.popoverPresentationController)
            XCTAssertTrue(popover.sourceView === button)
            XCTAssertTrue(popover.sourceRect.isNull || popover.sourceRect == button.bounds)
        }
    }

    private func makeAnchorFixture() -> (app: MenuAnchorAppDelegate, reader: MenuAnchorFeedController, navigation: MenuAnchorNavigationController) {
        let app = MenuAnchorAppDelegate()
        let reader = MenuAnchorFeedController()
        app.testFeed = reader
        reader.appDelegate = app
        let collection = StoriesCollection()
        collection.isRiverView = true
        collection.activeFolder = "everything"
        app.storiesCollection = collection
        reader.storiesCollection = collection
        let navigation = MenuAnchorNavigationController(rootViewController: reader)
        app.feedsNavigationController = navigation
        navigation.loadViewIfNeeded()
        reader.loadViewIfNeeded()
        return (app, reader, navigation)
    }
    #endif

    private func select(_ row: Int, in menu: MenuViewController) {
        menu.tableView(menu.menuTableView, didSelectRowAt: IndexPath(row: row, section: 0))
        menu.view.layoutIfNeeded()
    }

    private func makeMenu() throws -> (navigation: MenuTestNavigationController, menu: MenuViewController) {
        let root = MenuViewController()
        root.addTitle("Mark story read…", iconName: "menu_icn_markread.png", iconColor: .gray,
                      submenuTitles: ["On scroll or selection", "Only on selection", "After 1 second", "After 2 seconds", "After 3 seconds", "After 5 seconds", "After 10 seconds", "After 30 seconds", "After 60 seconds", "Manually"],
                      values: values, overrideSelectedValue: nil, defaultValue: "scroll", preferenceKey: key,
                      selectionShouldDismiss: false) { _ in }
        let navigation = MenuTestNavigationController(rootViewController: root)
        navigation.loadViewIfNeeded()
        root.loadViewIfNeeded()
        select(0, in: root)
        let menu = try XCTUnwrap(navigation.topViewController as? MenuViewController)
        XCTAssertFalse(menu === root)
        menu.loadViewIfNeeded()
        menu.view.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        menu.menuTableView.frame = menu.view.bounds
        menu.menuTableView.reloadData()
        menu.view.layoutIfNeeded()
        return (navigation, menu)
    }
}

@MainActor private final class MenuTestNavigationController: UINavigationController {
    override func show(_ vc: UIViewController, sender: Any?) {
        pushViewController(vc, animated: false)
    }
}

#if targetEnvironment(macCatalyst)
@MainActor private final class MenuAnchorAppDelegate: NewsBlurAppDelegate {
    weak var testFeed: MenuAnchorFeedController?
    override var feedDetailViewController: FeedDetailViewController! { testFeed }
}

@MainActor private final class MenuAnchorFeedController: FeedDetailViewController {
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 340, height: 600)) }
    override func viewDidLoad() {}
    override func viewWillAppear(_ animated: Bool) {}
    override func viewDidAppear(_ animated: Bool) {}
    override func viewWillLayoutSubviews() {}
}

@MainActor private final class MenuAnchorNavigationController: UINavigationController {
    var capturedPresentation: UIViewController?
    override func present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        // MenuPreferenceSelectionTests.swift observes real popover configuration without showing UI or using the live account.
        capturedPresentation = viewControllerToPresent
        completion?()
    }
}
#endif
