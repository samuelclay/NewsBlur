import XCTest
import UIKit

@testable import NewsBlur

@MainActor final class Test_StoryTitlesHeaderBarLayout: XCTestCase {
    private var originalDiscoverDisplay: Any?

    override func setUp() {
        super.setUp()
        originalDiscoverDisplay = UserDefaults.standard.object(forKey: "discover_display")
        UserDefaults.standard.set("with_icons", forKey: "discover_display")
    }

    override func tearDown() {
        UserDefaults.standard.set(originalDiscoverDisplay, forKey: "discover_display")
        super.tearDown()
    }

    func test_narrowSidebarShortensFilterBeforeCompressingDiscover() {
        let (bar, parent) = makeBar(width: 320)
        attach(bar, name: "header-narrow-unread")

        XCTAssertEqual(title(of: bar.optionsPill), "UNREAD")
        XCTAssertGreaterThanOrEqual(bar.discoverPill.bounds.width, 40)
        assertVisibleControlsFit(bar)
        XCTAssertTrue(parent.hitTest(bar.discoverPill.convert(CGPoint(x: bar.discoverPill.bounds.midX, y: bar.discoverPill.bounds.midY), to: parent), with: nil) === bar.discoverPill)
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

    private func makeBar(width: CGFloat) -> (StoryTitlesHeaderBar, UIView) {
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 100))
        let bar = StoryTitlesHeaderBar()
        bar.setup(in: parent)
        bar.updateOptionsPill(order: "newest", readFilter: "unread")
        bar.updateDiscoverVisibility(isRiver: true, isEverything: false, isSocial: false, isSaved: false, isRead: false, isWidget: false, isInfrequent: false)
        settle(bar, parent: parent)
        return (bar, parent)
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
        button.configuration?.title ?? button.title(for: .normal)
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
        XCTAssertGreaterThanOrEqual(bar.searchPill.bounds.width, 36, file: file, line: line)
        XCTAssertGreaterThanOrEqual(bar.markReadPill.bounds.width, 40, file: file, line: line)
        XCTAssertGreaterThanOrEqual(bar.markReadExpandButton.bounds.width, 26, file: file, line: line)
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
