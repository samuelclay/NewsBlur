import XCTest
import UIKit

@testable import NewsBlur

@MainActor final class Test_FeedToolbarLayout: XCTestCase {
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
        // FeedToolbarLayoutTests.swift resolves margin-relative storyboard constraints without a host window.
        let leading = controller.view.layoutMargins.left + controller.toolbarLeadingConstraint.constant
        let trailing = controller.view.layoutMargins.right + controller.toolbarTrailingConstraint.constant
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
