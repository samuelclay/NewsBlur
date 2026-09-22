import XCTest
import UIKit

@testable import NewsBlur

@MainActor final class Test_StoryKeyboardScroll: XCTestCase {
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

@MainActor private final class KeyboardScrollPageProbe: StoryDetailViewController {
    var pageDownCount = 0
    var pageUpCount = 0
    var lastSender: AnyObject?

    override func scrollPageDown(_ sender: Any!) {
        pageDownCount += 1
        lastSender = sender as AnyObject?
    }

    override func scrollPageUp(_ sender: Any!) {
        pageUpCount += 1
        lastSender = sender as AnyObject?
    }
}
