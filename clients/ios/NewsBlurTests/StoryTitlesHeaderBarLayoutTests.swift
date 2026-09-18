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
        settle(bar, parent: parent)
        attach(bar, name: "header-narrow-unread")

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
