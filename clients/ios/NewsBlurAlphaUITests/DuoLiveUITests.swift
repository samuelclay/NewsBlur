import XCTest
import UIKit

final class Test_DuoLiveUI: XCTestCase {
    private var app: XCUIApplication!
    private var orientationToRestore: UIDeviceOrientation?
    private var shouldReturnToFeeds = false
    private var activeAuditPickerKey: String?
    private var auditPreferencesOpen = false
    private var auditAppIconChooserOpen = false
    private var auditDailyBriefingSettingsOpen = false
    private var auditDailyBriefingSettingsScroll: XCUIElement?

    override func setUpWithError() throws {
        continueAfterFailure = false
#if targetEnvironment(simulator)
        guard ProcessInfo.processInfo.environment["NEWSBLUR_LIVE_DUO_UI_TESTS"] == "1" else {
            throw XCTSkip("Opt in with TEST_RUNNER_NEWSBLUR_LIVE_DUO_UI_TESTS=1 on the signed-in Duo simulator")
        }
        let deviceName = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? UIDevice.current.name
        guard deviceName.localizedCaseInsensitiveContains("Duo") else {
            throw XCTSkip("Requires the existing iPhone Duo simulator, got \(deviceName)")
        }
        // DuoLiveUITests.swift activates the existing Alpha session without fixture arguments or a relaunch.
        app = XCUIApplication(bundleIdentifier: "com.newsblur.NB-Alpha")
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        capture("duo-live-before-audit")
        try recoverAuditModals()
        // DuoLiveUITests.swift can follow application tests that leave an unselected expanded reader; establish the feed-list starting screen through its real Sidebar action.
        let feeds = app.tables["feeds-list"]
        if !feeds.exists || !feeds.isHittable {
            let back = app.buttons["expanded-feeds-back"]
            if back.exists && back.isHittable {
                back.tap()
            } else if let sidebar = app.buttons.matching(identifier: "Sidebar").allElementsBoundByIndex.first(where: { $0.isHittable }) {
                sidebar.tap()
                // DuoLiveUITests.swift follows fullscreen's titles overlay through its own Feeds action.
                if back.exists && back.isHittable { back.tap() }
            }
        }
#else
        throw XCTSkip("This audit requires the iPhone Duo simulator")
#endif
    }

    override func tearDownWithError() throws {
        guard app != nil else { return }
        continueAfterFailure = true
        do {
            try recoverAuditModals()
        } catch {
            capture("duo-live-cleanup-failed")
            XCTFail("Could not dismiss an audit sheet: \(error)")
        }
        if let orientation = orientationToRestore {
            XCUIDevice.shared.orientation = orientation
            XCTAssertTrue(waitForStableFeeds(orientation: orientation), "The original orientation must be restored")
        }
    }

    func test_preferencesPickersOpenAndDismissWithoutChangingSelections() throws {
        try requireVisibleFeeds()
        try openPreferences()
        capture("duo-live-preferences")

        let pickers: [(key: String, title: String, options: [String])] = [
            ("default_order", "Story order", ["Newest first", "Oldest first"]),
            ("default_mark_read_filter", "Mark stories read", ["On scroll or selection", "Only on selection"]),
            ("story_toolbar_position", "Story list toolbar position", ["Top", "Bottom"]),
            ("story_detail_swipe_left_edge", "Swipe from the left edge while reading", ["Back to story titles", "Previous story"]),
        ]
        for picker in pickers {
            let row = try scrollToPreference(picker.key)
            let originalLabel = row.label
            let originalValue = row.value as? String
            activeAuditPickerKey = picker.key
            row.tap()
            XCTAssertTrue(app.staticTexts[picker.title].firstMatch.waitForExistence(timeout: 5))
            let firstChoice = app.buttons.matching(choicePredicate(picker.options[0])).firstMatch
            XCTAssertTrue(firstChoice.waitForExistence(timeout: 5), "The center tap must open the actual picker")
            let pickerScroll = app.scrollViews.containing(.button, identifier: firstChoice.label).firstMatch
            XCTAssertTrue(pickerScroll.exists, "Picker choices must be in their own sheet's scroll view")
            for option in picker.options {
                XCTAssertTrue(pickerScroll.buttons.matching(choicePredicate(option)).firstMatch.waitForExistence(timeout: 5),
                              "The real \(picker.key) picker must show \(option)")
            }
            capture("duo-live-picker-\(picker.key)")
            try dismissAuditPicker()
            XCTAssertEqual(row.label, originalLabel, "Dismissing \(picker.key) must preserve its selection")
            XCTAssertEqual(row.value as? String, originalValue)
        }

        try dismissAuditPreferences()
        capture("duo-live-preferences-returned-to-feeds")
    }

    func test_nativeStoryListMarkReadOptionsCanBeInspectedWithoutMarkingAnything() throws {
        try requireVisibleFeeds()
        // DuoLiveUITests.swift selects the UIButton inside its section header, excluding UITableView's duplicate AX mirror.
        let allStories = app.tables["feeds-list"].children(matching: .other)
            .children(matching: .button).matching(identifier: "folder-header-everything").element
        XCTAssertTrue(allStories.waitForExistence(timeout: 5))
        let headerFrame = allStories.frame
        let visibleFeeds = app.tables["feeds-list"].frame.intersection(app.frame)
        XCTAssertTrue(visibleFeeds.contains(headerFrame) && headerFrame.height > 0,
                      "All Site Stories must be fully visible before its header is tapped")
        capture("duo-live-native-mark-read-before-header")
        shouldReturnToFeeds = true
        // DuoLiveUITests.swift uses this observed custom button's center because its AX visible point is {-1,-1} on Duo.
        allStories.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.tables["story-titles-list"].waitForExistence(timeout: 15))
        // DuoLiveUITests.swift invokes only the plus/menu item; the adjacent checkmark performs a read mutation.
        try tapFeedAction("story-list-mark-read-options", fallbackTitle: "Mark Read options")
        let firstAge = app.buttons["Older than 1 day"].firstMatch
        XCTAssertTrue(firstAge.waitForExistence(timeout: 5))
        for title in ["Older than 3 days", "Older than 7 days", "Older than 14 days"] {
            XCTAssertTrue(app.buttons[title].firstMatch.exists)
        }
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Mark ' AND label ENDSWITH ' as read'")).firstMatch.exists)
        capture("duo-live-native-mark-read-options")
        try dismissNativeMenu(containing: firstAge)
        try returnToFeedsFromStoryList()
        capture("duo-live-native-mark-read-cancelled")
    }

    func test_expandedTitleFeedsBackReopensFeedList() throws {
        try requireVisibleFeeds()
        let allStories = app.tables["feeds-list"].children(matching: .other)
            .children(matching: .button).matching(identifier: "folder-header-everything").element
        XCTAssertTrue(allStories.waitForExistence(timeout: 30), "The signed-in feed reload must finish rendering its All Site Stories header")
        XCTAssertTrue(app.tables["feeds-list"].frame.contains(allStories.frame))
        shouldReturnToFeeds = true
        allStories.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.tables["story-titles-list"].waitForExistence(timeout: 15))
        let back = app.buttons["expanded-feeds-back"]
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "duo-live-expanded-native-back-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        capture("duo-live-expanded-native-back-before-tap")
        XCTAssertTrue(waitUntilHittable(back), "Expanded Duo must render a Feeds back button beside the story-list title")
        XCTAssertLessThanOrEqual(back.frame.maxY, app.tables["story-titles-list"].frame.minY + 1,
                                 "Feeds must stay in the title band above the scrolling story list")
        back.tap()
        try requireVisibleFeeds()
        shouldReturnToFeeds = false
        capture("duo-live-expanded-native-back-returned-to-feeds")
    }

    func test_fullscreenReaderKeepsTitlesAndFeedsInAnOverlay() throws {
        try requireVisibleFeeds()
        let initialFullscreen = app.buttons["reader-fullscreen"]
        if initialFullscreen.exists && initialFullscreen.value as? String == "On" {
            let sidebar = try XCTUnwrap(app.buttons.matching(identifier: "Sidebar")
                .allElementsBoundByIndex.first { $0.isHittable })
            sidebar.tap()
            XCTAssertTrue(waitUntilHittable(initialFullscreen))
            initialFullscreen.tap()
            let back = app.buttons["expanded-feeds-back"]
            XCTAssertTrue(waitUntilHittable(back))
            back.tap()
            try requireVisibleFeeds()
        }
        let feeds = app.tables["feeds-list"]
        let folder = feeds.children(matching: .other).children(matching: .button)
            .matching(identifier: "folder-header-everything").element
        for _ in 0..<10 {
            if folder.exists && feeds.frame.contains(folder.frame) { break }
            feeds.swipeDown()
        }
        let folderReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            folder.exists && feeds.frame.contains(folder.frame)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [folderReady], timeout: 15), .completed,
                       "The signed-in feed reload must settle before selecting All Site Stories")
        shouldReturnToFeeds = true
        folder.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let list = app.tables["story-titles-list"]
        XCTAssertTrue(list.waitForExistence(timeout: 15))
        let row = list.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'story-row-'"))
            .allElementsBoundByIndex.first { list.frame.contains($0.frame) && $0.frame.height > 20 }
        let selected = try XCTUnwrap(row)
        selected.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let hash = String(selected.identifier.dropFirst("story-row-".count))
        let probe = app.staticTexts["story-current-story"].firstMatch
        try waitForLiveReader(probe, expectedHash: hash)
        let outgoingTitle = probe.label
        let web = try XCTUnwrap(app.webViews.allElementsBoundByIndex.first { $0.isHittable })
        let splitWidth = web.frame.width
        capture("duo-fullscreen-before-toggle")
        let fullscreen = app.buttons["reader-fullscreen"]
        XCTAssertTrue(waitUntilHittable(fullscreen), "Open Duo needs a full-screen reader toggle in place of reading progress")
        XCTAssertFalse(app.buttons["reader-progress"].exists && app.buttons["reader-progress"].isHittable)
        fullscreen.tap()
        let expanded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            web.frame.width > splitWidth + 100 && (!list.exists || !list.isHittable)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expanded], timeout: 10), .completed)
        let fullWidth = web.frame.width
        XCTAssertEqual(probe.value as? String, hash)
        capture("duo-fullscreen-reader")
        let sidebar = try XCTUnwrap(app.buttons.matching(identifier: "Sidebar")
            .allElementsBoundByIndex.first { $0.isHittable })
        // DuoLiveUITests.swift anchors the edge drag to the visible reader because the application's coordinate space can belong to Duo's inactive outer display.
        let edge = web.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
            .withOffset(CGVector(dx: 1, dy: 0))
        // DuoLiveUITests.swift crosses the native completion threshold even when the remembered overlay width is large.
        let revealDistance = fullWidth * 0.65
        edge.press(forDuration: 0.05, thenDragTo: edge.withOffset(CGVector(dx: revealDistance, dy: 0)),
                   withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(waitUntilHittable(list), "A leading-edge swipe must reveal story titles instead of paging to a different article")
        XCTAssertEqual(probe.value as? String, hash)
        XCTAssertEqual(web.frame.width, fullWidth, accuracy: 1)
        capture("duo-fullscreen-edge-reveal")
        sidebar.tap()
        XCTAssertTrue(list.waitForDisappearance(timeout: 5))
        edge.press(forDuration: 0.05, thenDragTo: edge.withOffset(CGVector(dx: 35, dy: 0)),
                   withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertFalse(list.exists && list.isHittable, "A short released edge swipe must cancel without committing the overlay")
        XCTAssertEqual(probe.value as? String, hash)
        capture("duo-fullscreen-edge-cancel")
        XCTAssertFalse(app.otherElements["story-image-viewer"].exists,
                       "Cancelling the native edge swipe over a photo must not open that photo")
        XCTAssertTrue(waitUntilHittable(sidebar), "Cancelling the edge swipe must leave the reader rail interactive")
        sidebar.tap()
        XCTAssertTrue(waitUntilHittable(list))
        XCTAssertEqual(web.frame.width, fullWidth, accuracy: 1,
                       "Showing titles must overlay the full-width article")
        let back = app.buttons["expanded-feeds-back"]
        XCTAssertTrue(waitUntilHittable(back), "The titles overlay needs a Feeds back button")
        XCTAssertLessThanOrEqual(back.frame.midY, app.frame.minY + 35,
                                 "The overlay title must not reserve an obsolete horizontal status band")
        capture("duo-fullscreen-titles-overlay")
        let originalOverlayWidth = list.frame.width
        let resizeHandle = app.descendants(matching: .any)["feeds-sidebar-resize-handle"].firstMatch
        XCTAssertTrue(waitUntilHittable(resizeHandle), "The native titles overlay needs a working resize handle")
        // DuoLiveUITests.swift drags the rendered native handle, then checks the actual list edge instead of the handle alone.
        func resizeOverlay(_ content: XCUIElement, to width: CGFloat) {
            let start = resizeHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.1,
                        thenDragTo: start.withOffset(CGVector(dx: width - content.frame.width, dy: 0)),
                        withVelocity: .slow, thenHoldForDuration: 0)
            let resized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                abs(content.frame.width - width) < 3 && abs(resizeHandle.frame.midX - content.frame.maxX) < 3
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [resized], timeout: 5), .completed,
                           "Dragging must resize the visible list to \(width); actual content \(content.frame), handle \(resizeHandle.frame)")
            XCTAssertEqual(web.frame.width, fullWidth, accuracy: 1)
        }
        let resizedOverlayWidth = originalOverlayWidth + 60
        resizeOverlay(list, to: resizedOverlayWidth)
        capture("duo-fullscreen-resized-titles-overlay")
        back.tap()
        try requireVisibleFeeds()
        XCTAssertEqual(web.frame.width, fullWidth, accuracy: 1)
        XCTAssertEqual(feeds.frame.width, resizedOverlayWidth, accuracy: 3,
                       "Feeds and story titles must share the selected overlay width")
        capture("duo-fullscreen-feeds-overlay")
        // DuoLiveUITests.swift dismisses through UIKit's outside-tap surface and then uses a fresh edge gesture, without the explicit Sidebar button preparing titles.
        web.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertTrue(feeds.waitForDisappearance(timeout: 5))
        edge.press(forDuration: 0.05, thenDragTo: edge.withOffset(CGVector(dx: revealDistance, dy: 0)),
                   withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(waitUntilHittable(list), "A fresh edge reveal after dismissing Feeds must show story titles")
        XCTAssertFalse(feeds.exists && feeds.isHittable)
        XCTAssertEqual(web.frame.width, fullWidth, accuracy: 1)
        XCTAssertEqual(probe.value as? String, hash)
        back.tap()
        try requireVisibleFeeds()
        let source = try XCTUnwrap(feeds.cells.matching(NSPredicate(format: "identifier MATCHES 'feed-row-[0-9]+'"))
            .allElementsBoundByIndex.first {
                feeds.frame.contains($0.frame) && $0.frame.height > 20 &&
                    !hash.hasPrefix(String($0.identifier.dropFirst("feed-row-".count)) + ":")
            })
        let sourceID = String(source.identifier.dropFirst("feed-row-".count))
        source.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(waitUntilHittable(list))
        let sourceRows = list.cells.matching(NSPredicate(format: "identifier BEGINSWITH %@", "story-row-\(sourceID):"))
        let sourceLoaded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            sourceRows.allElementsBoundByIndex.contains { list.frame.contains($0.frame) && $0.frame.height > 20 }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [sourceLoaded], timeout: 20), .completed)
        XCTAssertTrue(web.staticTexts.matching(NSPredicate(format: "label == %@", outgoingTitle)).firstMatch.exists,
                      "Browsing another feed must retain the rendered article behind the overlay")
        XCTAssertEqual(web.frame.width, fullWidth, accuracy: 1)
        XCTAssertEqual(list.frame.width, resizedOverlayWidth, accuracy: 3)
        resizeOverlay(list, to: originalOverlayWidth)
        let nextRow = try XCTUnwrap(sourceRows
            .allElementsBoundByIndex.first { list.frame.contains($0.frame) && $0.frame.height > 20 })
        let nextHash = String(nextRow.identifier.dropFirst("story-row-".count))
        nextRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        try waitForLiveReader(probe, expectedHash: nextHash)
        XCTAssertEqual(web.frame.width, fullWidth, accuracy: 1)
        XCTAssertFalse(list.exists && list.isHittable)
        capture("duo-fullscreen-selected-from-overlay")
        XCTAssertTrue(waitUntilHittable(fullscreen))
        fullscreen.tap()
        XCTAssertTrue(waitUntilHittable(list))
        XCTAssertEqual(web.frame.width, splitWidth, accuracy: 1)
        capture("duo-fullscreen-returned-to-two-columns")
        XCTAssertTrue(waitUntilHittable(back))
        back.tap()
        try requireVisibleFeeds()
        shouldReturnToFeeds = false
    }

    func test_fullscreenPhotoEdgeCancellationPreservesReader() throws {
        try requireVisibleFeeds()
        let search = app.textFields["Search feeds"]
        let feeds = app.tables["feeds-list"]
        for _ in 0..<12 {
            if search.exists && search.isHittable { break }
            feeds.swipeDown()
        }
        XCTAssertTrue(waitUntilHittable(search))
        search.tap()
        search.typeText("STREET ART UTOPIA\n")
        let source = feeds.cells["feed-row-674970"]
        XCTAssertTrue(waitUntilHittable(source), "The signed-in photo feed used in the cancellation reproduction must be available")
        shouldReturnToFeeds = true
        source.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let list = app.tables["story-titles-list"]
        XCTAssertTrue(waitUntilHittable(list))
        let rows = list.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'story-row-674970:'"))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            rows.allElementsBoundByIndex.contains { list.frame.contains($0.frame) && $0.frame.height > 20 }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 20), .completed)
        let row = try XCTUnwrap(rows.allElementsBoundByIndex.first { list.frame.contains($0.frame) && $0.frame.height > 20 })
        let hash = String(row.identifier.dropFirst("story-row-".count))
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let probe = app.staticTexts["story-current-story"].firstMatch
        try waitForLiveReader(probe, expectedHash: hash)
        let fullscreen = app.buttons["reader-fullscreen"]
        XCTAssertTrue(waitUntilHittable(fullscreen))
        let wasFullscreen = fullscreen.value as? String == "On"
        if !wasFullscreen { fullscreen.tap() }
        let web = try XCTUnwrap(app.webViews.allElementsBoundByIndex.first { $0.isHittable })
        func visiblePhoto() -> XCUIElement? {
            web.images.allElementsBoundByIndex.first {
                $0.frame.minX <= web.frame.minX + 2 && $0.frame.maxX >= web.frame.maxX - 2 &&
                    $0.frame.intersection(web.frame).height > 100
            }
        }
        let photoReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in visiblePhoto() != nil }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [photoReady], timeout: 20), .completed)
        let photo = try XCTUnwrap(visiblePhoto())
        let photoFrame = photo.frame.intersection(web.frame)
        let edge = web.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 1, dy: photoFrame.midY - web.frame.minY))
        capture("duo-fullscreen-photo-before-cancel")
        edge.press(forDuration: 0.05, thenDragTo: edge.withOffset(CGVector(dx: 35, dy: 0)),
                   withVelocity: .slow, thenHoldForDuration: 0.3)
        capture("duo-fullscreen-photo-after-cancel")
        XCTAssertFalse(app.otherElements["story-image-viewer"].exists)
        XCTAssertFalse(list.exists && list.isHittable)
        XCTAssertEqual(probe.value as? String, hash)
        // DuoLiveUITests.swift also proves the same photo remains normally tappable after cancelling the native sidebar gesture.
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.otherElements["story-image-viewer"].waitForExistence(timeout: 5))
        app.buttons["Close image"].tap()
        XCTAssertTrue(app.otherElements["story-image-viewer"].waitForDisappearance(timeout: 5))
        if !wasFullscreen { fullscreen.tap() }
        try returnToFeedsFromStoryList()
    }

    func test_openReadingWithStoryTapsScrollingAndNextPrevious() throws {
        try requireVisibleFeeds()
        let folder = app.tables["feeds-list"].children(matching: .other)
            .children(matching: .button).matching(identifier: "folder-header-everything").element
        // DuoLiveUITests.swift taps the observed header center because Duo reports its AX visible point as {-1,-1}.
        XCTAssertTrue(folder.waitForExistence(timeout: 30), "The signed-in feed reload must finish rendering its All Site Stories header")
        XCTAssertTrue(app.tables["feeds-list"].frame.contains(folder.frame))
        shouldReturnToFeeds = true
        folder.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let list = app.tables["story-titles-list"]
        XCTAssertTrue(list.waitForExistence(timeout: 15))
        let rows = list.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'story-row-'"))
        // DuoLiveUITests.swift excludes clipped/offscreen rows before asking AX for a target; portrait Duo can throw for their invalid activation points.
        func visibleRows() -> [XCUIElement] {
            let viewport = list.frame.insetBy(dx: 0, dy: 2)
            return rows.allElementsBoundByIndex.filter {
                let frame = $0.frame
                return frame.width > 40 && frame.height > 20 && viewport.contains(frame)
            }
        }
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            visibleRows().count >= 2
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 20), .completed)
        XCTAssertTrue(waitUntilHittable(app.buttons["expanded-feeds-back"]))
        assertVisibleStoryHeaderClearsList(list)
        let identifiers = Array(visibleRows().prefix(2).map(\.identifier))
        XCTAssertEqual(identifiers.count, 2)
        let probe = app.staticTexts["story-current-story"].firstMatch
        for (index, identifier) in identifiers.enumerated() {
            let row = list.cells[identifier]
            XCTAssertTrue(row.exists && list.frame.contains(row.frame))
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let hash = String(identifier.dropFirst("story-row-".count))
            try waitForLiveReader(probe, expectedHash: hash)
            capture("duo-live-reading-selected-\(index)")
            let web = try XCTUnwrap(app.webViews.allElementsBoundByIndex.first { $0.isHittable })
            let titleState = try storyHeaderState(list)
            if index == 0 {
                let storyTitle = probe.label
                let renderedTitle = web.staticTexts.matching(NSPredicate(format: "label == %@", storyTitle)).firstMatch
                // DuoLiveUITests.swift returns a previously read article to its actual top through touch input before recording the pull.
                var reachedTop = false
                for _ in 0..<6 {
                    let before = renderedTitle.frame
                    web.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
                        .press(forDuration: 0.05,
                               thenDragTo: web.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)),
                               withVelocity: .slow, thenHoldForDuration: 0)
                    if renderedTitle.isHittable, web.frame.contains(renderedTitle.frame),
                       abs(renderedTitle.frame.minY - before.minY) <= 1 {
                        reachedTop = true
                        break
                    }
                }
                XCTAssertTrue(reachedTop, "The rendered article title must stop moving at the document top before the recorded pull")
                let titleFrameAtTop = renderedTitle.frame
                let webFrameAtTop = web.frame
                let feedHeader = try XCTUnwrap(flattened(try web.snapshot()).first {
                    $0.elementType == .staticText && !$0.label.isEmpty && $0.label != storyTitle &&
                        $0.frame.width > 20 && $0.frame.height > 0 &&
                        $0.frame.minY >= webFrameAtTop.minY && $0.frame.maxY <= webFrameAtTop.minY + 25
                }, "The native river feed label must be visible in the pinned top strip")
                try assertStoryHeaderUnchanged(titleState, list: list)
                capture("duo-live-reading-before-top-pull")
                print("DUO_TOP_PULL_READY hash=\(hash) title=\(storyTitle)")
                fflush(stdout)
                web.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
                    .press(forDuration: 0.05,
                           thenDragTo: web.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)),
                           withVelocity: .slow, thenHoldForDuration: 2)
                try waitForLiveReader(probe, expectedHash: hash)
                XCTAssertEqual(probe.label, storyTitle, "The pull must preserve the selected article and its rendered document")
                let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    renderedTitle.isHittable && abs(renderedTitle.frame.minY - titleFrameAtTop.minY) <= 1 &&
                        web.staticTexts.matching(NSPredicate(format: "label == %@", feedHeader.label))
                            .allElementsBoundByIndex.contains { abs($0.frame.minY - feedHeader.frame.minY) <= 1 }
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 10), .completed,
                               "The article and native feed header must settle back to their original protected top after the pull")
                try assertStoryHeaderUnchanged(titleState, list: list)
                capture("duo-live-reading-top-pull-settled")
            }
            web.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                .press(forDuration: 0.05, thenDragTo: web.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)))
            XCTAssertEqual(probe.value as? String, hash, "Scrolling an article must retain the selected story")
            try assertStoryHeaderUnchanged(titleState, list: list)
            capture("duo-live-reading-scrolled-\(index)")
        }
        let beforeNext = try XCTUnwrap(probe.value as? String)
        let nativeNext = app.buttons["reader-next"]
        let next = nativeNext.exists ? nativeNext : app.buttons["story-traverse-next-button"]
        XCTAssertTrue(waitUntilHittable(next))
        XCTAssertTrue(["Next unread story", "Next story"].contains(next.label),
                      "The live river must have another unread story; never invoke Done as a substitute")
        next.tap()
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let hash = probe.value as? String else { return false }
            return !hash.isEmpty && hash != beforeNext
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 20), .completed)
        let nextHash = try XCTUnwrap(probe.value as? String)
        try waitForLiveReader(probe, expectedHash: nextHash)
        capture("duo-live-reading-next")
        let nativePrevious = app.buttons["reader-previous"]
        let previous = nativePrevious.exists ? nativePrevious : app.buttons["story-traverse-previous-button"]
        XCTAssertTrue(waitUntilHittable(previous))
        previous.tap()
        let previousChanged = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let hash = probe.value as? String else { return false }
            return !hash.isEmpty && hash != nextHash
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [previousChanged], timeout: 20), .completed)
        // DuoLiveUITests.swift allows Next Unread to skip read rows; Previous still must load a different, readable story.
        try waitForLiveReader(probe, expectedHash: try XCTUnwrap(probe.value as? String))
        capture("duo-live-reading-previous")
        let finalHash = try XCTUnwrap(probe.value as? String)
        try restoreStoryHeaderByReversingList(list)
        XCTAssertEqual(probe.value as? String, finalHash)
        capture("duo-live-reading-title-restored-after-traversal")

        // DuoLiveUITests.swift uses actual gestures in the left table to prove its native header can minimize and restore independently.
        let visibleWeb = try XCTUnwrap(app.webViews.allElementsBoundByIndex.first { $0.isHittable })
        let protectedTop = visibleWeb.frame.minY
        list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            .press(forDuration: 0.05, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)))
        let collapsed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !self.app.buttons["expanded-feeds-back"].isHittable && abs(list.frame.minY - protectedTop) <= 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [collapsed], timeout: 15), .completed,
                       "Scrolling story titles must hide their header and reclaim the whole protected top without a status strip")
        XCTAssertEqual(probe.value as? String, finalHash, "Scrolling titles must not change the selected article")
        capture("duo-live-reading-title-minimized")
        let collapsedState = try storyHeaderState(list)
        visibleWeb.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            .press(forDuration: 0.05, thenDragTo: visibleWeb.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)))
        try assertStoryHeaderUnchanged(collapsedState, list: list)
        XCTAssertEqual(probe.value as? String, finalHash)
        try restoreStoryHeaderByReversingList(list)
        XCTAssertEqual(probe.value as? String, finalHash)
        capture("duo-live-reading-title-reversed")
        let feedsBack = app.buttons["expanded-feeds-back"]
        XCTAssertTrue(waitUntilHittable(feedsBack))
        feedsBack.tap()
        try requireVisibleFeeds()
        shouldReturnToFeeds = false
    }

    private func waitForLiveReader(_ probe: XCUIElement, expectedHash: String) throws {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard probe.exists, probe.value as? String == expectedHash, probe.label != "No story selected" else { return false }
            return self.app.webViews.allElementsBoundByIndex.contains { web in
                web.isHittable && web.staticTexts.matching(NSPredicate(format: "label == %@", probe.label)).firstMatch.exists
            }
        }, object: nil)
        let result = XCTWaiter.wait(for: [ready], timeout: 25)
        if result != .completed {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "duo-live-reading-not-ready-hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            capture("duo-live-reading-not-ready")
        }
        XCTAssertEqual(result, .completed,
                       "The selected story title must actually render in the visible article")
        assertVisibleStoryHeaderClearsList(app.tables["story-titles-list"])
    }

    private struct StoryHeaderState {
        let visible: Bool
        let headerFrame: CGRect?
        let listFrame: CGRect
        let anchorIdentifier: String
        let anchorRelativeY: CGFloat
    }

    private func storyHeaderState(_ list: XCUIElement) throws -> StoryHeaderState {
        let header = app.buttons["expanded-feeds-back"]
        let snapshot = try list.snapshot()
        let anchor = try XCTUnwrap(flattened(snapshot).first {
            $0.elementType == .cell && $0.identifier.hasPrefix("story-row-") &&
                $0.frame.width > 40 && snapshot.frame.intersection($0.frame).height > 20
        }, "A real visible story row must anchor the list's scroll position")
        let headerExists = header.exists
        return StoryHeaderState(visible: headerExists && header.isHittable,
                                headerFrame: headerExists ? header.frame : nil, listFrame: snapshot.frame,
                                anchorIdentifier: anchor.identifier, anchorRelativeY: anchor.frame.minY - snapshot.frame.minY)
    }

    private func assertStoryHeaderUnchanged(_ original: StoryHeaderState, list: XCUIElement) throws {
        let header = app.buttons["expanded-feeds-back"]
        let headerExists = header.exists
        let listFrame = list.frame
        XCTAssertEqual(headerExists && header.isHittable, original.visible,
                       "Article scrolling must preserve the story-title header's own visibility")
        XCTAssertEqual(headerExists, original.headerFrame != nil)
        if headerExists, let originalFrame = original.headerFrame {
            let frame = header.frame
            XCTAssertEqual(frame.minX, originalFrame.minX, accuracy: 1)
            XCTAssertEqual(frame.minY, originalFrame.minY, accuracy: 1)
            XCTAssertEqual(frame.width, originalFrame.width, accuracy: 1)
            XCTAssertEqual(frame.height, originalFrame.height, accuracy: 1)
        }
        XCTAssertEqual(listFrame.minX, original.listFrame.minX, accuracy: 1)
        XCTAssertEqual(listFrame.minY, original.listFrame.minY, accuracy: 1)
        XCTAssertEqual(listFrame.width, original.listFrame.width, accuracy: 1)
        XCTAssertEqual(listFrame.height, original.listFrame.height, accuracy: 1)
        let anchor = list.cells[original.anchorIdentifier]
        XCTAssertTrue(anchor.exists)
        // DuoLiveUITests.swift measures the same row relative to its table because XCUIElement does not expose UIScrollView.contentOffset.
        XCTAssertEqual(anchor.frame.minY - listFrame.minY, original.anchorRelativeY, accuracy: 1,
                       "Article scrolling must not move the story-title list's content offset")
        assertVisibleStoryHeaderClearsList(list)
    }

    private func assertVisibleStoryHeaderClearsList(_ list: XCUIElement) {
        let header = app.buttons["expanded-feeds-back"]
        if header.exists && header.isHittable {
            XCTAssertLessThanOrEqual(header.frame.maxY, list.frame.minY + 1,
                                     "The shown Feeds/source header must remain above the list's visible viewport")
        }
    }

    private func restoreStoryHeaderByReversingList(_ list: XCUIElement) throws {
        XCTAssertTrue(list.isHittable)
        list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
            .press(forDuration: 0.05, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
        let header = app.buttons["expanded-feeds-back"]
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            header.isHittable && header.frame.maxY <= list.frame.minY + 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 15), .completed,
                       "Reversing the story-title scroll must restore its tappable header and title space")
        assertVisibleStoryHeaderClearsList(list)
    }

    func test_appIconChooserOpensWithoutChangingTheIcon() throws {
        try requireVisibleFeeds()
        try openPreferences()
        let scroll = app.scrollViews.firstMatch
        var foundRow = false
        for _ in 0..<30 {
            let snapshot = try scroll.snapshot()
            let viewport = snapshot.frame.insetBy(dx: 2, dy: 8)
            if flattened(snapshot).contains(where: {
                $0.elementType == .button && $0.label.contains("Choose Icon") && viewport.contains($0.frame)
            }) {
                foundRow = true
                break
            }
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                .press(forDuration: 0.05,
                       thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)))
        }
        XCTAssertTrue(foundRow, "The App Icon row must be reachable in Preferences")
        let row = appIconPreferenceRow
        XCTAssertTrue(waitUntilHittable(row))
        let original = try row.snapshot()
        let availability = XCTAttachment(string: "App Icon row: \(original.label)\nValue: \(String(describing: original.value))")
        availability.name = "duo-live-app-icon-availability"
        availability.lifetime = .keepAlways
        add(availability)
        capture("duo-live-app-icon-row")
        if original.label.localizedCaseInsensitiveContains("Unavailable") || original.label.localizedCaseInsensitiveContains("Premium") {
            try dismissAuditPreferences()
            throw XCTSkip("App Icon chooser is gated: \(original.label)")
        }

        auditAppIconChooserOpen = true
        row.tap()
        XCTAssertTrue(app.staticTexts["App Icon"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Use both"].firstMatch.waitForExistence(timeout: 5),
                      "The center tap must open the actual icon chooser and its appearance controls")
        capture("duo-live-app-icon-chooser")
        // DuoLiveUITests.swift never taps an appearance or icon; Done dismisses an unchanged pending selection.
        try dismissAuditAppIconChooser()
        let restored = try row.snapshot()
        XCTAssertEqual(restored.label, original.label)
        XCTAssertEqual(String(describing: restored.value), String(describing: original.value))
        try dismissAuditPreferences()
    }

    func test_dailyBriefingSettingsBottomActionsAreVisibleWithoutSavingOrGenerating() throws {
        try requireVisibleFeeds()
        let header = app.tables["feeds-list"].children(matching: .other)
            .children(matching: .button).matching(identifier: "folder-header-daily-briefing").element
        guard header.waitForExistence(timeout: 5) else {
            capture("duo-live-daily-briefing-unavailable")
            throw XCTSkip("Daily Briefing is not available in the signed-in feed list")
        }
        let headerFrame = header.frame
        XCTAssertTrue(app.tables["feeds-list"].frame.intersection(app.frame).contains(headerFrame) && headerFrame.height > 0,
                      "The observed Daily Briefing header must be fully visible")
        shouldReturnToFeeds = true
        header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let settings = app.buttons.matching(identifier: "story-list-discover")
            .matching(NSPredicate(format: "label == %@", "Daily Briefing Settings")).firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 30))
        auditDailyBriefingSettingsOpen = true
        try tapFeedAction("story-list-discover", fallbackTitle: "Daily Briefing Settings")
        XCTAssertTrue(app.staticTexts["Daily Briefing Settings"].firstMatch.waitForExistence(timeout: 15))
        // DuoLiveUITests.swift retains the observed scroll index so scrolling its title off screen does not lose the sheet.
        let scroll = try XCTUnwrap(app.scrollViews.allElementsBoundByIndex.first {
            $0.staticTexts["Daily Briefing Settings"].exists && $0.isHittable
        }, "Daily Briefing settings must expose their scrollable form")
        auditDailyBriefingSettingsScroll = scroll
        XCTAssertTrue(scroll.buttons["Save"].firstMatch.waitForExistence(timeout: 30),
                      "The loaded settings form must contain its Save action")
        capture("duo-live-daily-briefing-settings-top")

        var reachedActions = false
        var previousContent = ""
        for _ in 0..<24 {
            let snapshot = try scroll.snapshot()
            let viewport = snapshot.frame.intersection(app.frame).insetBy(dx: 2, dy: 8)
            let visible = flattened(snapshot).filter { $0.frame.height > 0 && viewport.contains($0.frame) }
            if ["Save", "Generate Now"].allSatisfy({ title in
                visible.contains { $0.elementType == .button && $0.label == title }
            }) {
                reachedActions = true
                break
            }
            let content = visible.map { "\($0.label)|\(Int($0.frame.minY.rounded()))" }.joined(separator: "\n")
            if !content.isEmpty && content == previousContent { break }
            previousContent = content
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                .press(forDuration: 0.05,
                       thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)))
        }
        capture("duo-live-daily-briefing-settings-bottom")
        XCTAssertTrue(reachedActions, "Save and Generate Now must both fit at the bottom of the settings form")
        XCTAssertTrue(scroll.buttons["Save"].firstMatch.isHittable)
        XCTAssertTrue(scroll.buttons["Generate Now"].firstMatch.isHittable)
        // DuoLiveUITests.swift inspects these actions without tapping either or changing any setting.
        try dismissAuditDailyBriefingSettings()
        try returnToFeedsFromStoryList()
    }

    private var appIconPreferenceRow: XCUIElement {
        app.buttons.containing(.staticText, identifier: "Choose Icon").firstMatch
    }

    func test_everyVisiblePreferencePickerOpensWithoutChangingSelections() throws {
        try requireVisibleFeeds()
        try openPreferences()
        let scroll = app.scrollViews.firstMatch
        var visited: [String] = []
        var seen = Set<String>()
        var parentValues: [String: String] = [:]
        var reachedBottom = false
        var previousVisibleContent = ""
        var repeatedContent = 0
        defer {
            let missing = preferencePickerKeys.filter { !visited.contains($0) }
            let report = ["Visited (\(visited.count)): \(visited.joined(separator: ", "))",
                          "Reached bottom: \(reachedBottom)",
                          "Seen but unvisited: \(seen.subtracting(visited).sorted().joined(separator: ", "))"] +
                missing.map { "\($0): \(missingPickerReason($0, parentValues: parentValues))" }
            let attachment = XCTAttachment(string: report.joined(separator: "\n"))
            attachment.name = "duo-live-preference-picker-inventory"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        for _ in 0..<60 {
            // DuoLiveUITests.swift reads each viewport once; snapshot descendants do not make another AX request.
            let snapshot = try scroll.snapshot()
            let elements = flattened(snapshot)
            let viewport = snapshot.frame.insetBy(dx: 2, dy: 8)
            for element in elements {
                if preferencePickerKeys.contains(element.identifier) { seen.insert(element.identifier) }
                if conditionalPickerParents.values.contains(where: { $0.key == element.identifier }), let value = element.value {
                    parentValues[element.identifier] = String(describing: value)
                }
            }
            let visible = elements.filter { $0.frame.height > 0 && viewport.contains($0.frame) }
            let rows = visible.filter {
                $0.elementType == .button && preferencePickerKeys.contains($0.identifier) && !visited.contains($0.identifier)
            }.sorted { $0.frame.minY < $1.frame.minY }
            for row in rows {
                let key = row.identifier
                try auditPreferencePicker(key, original: row)
                visited.append(key)
            }
            if visible.contains(where: { $0.label == "Delete Account" }) {
                reachedBottom = true
                break
            }
            let content = visible.filter { !$0.label.isEmpty }.map {
                "\($0.identifier)|\($0.label)|\(Int($0.frame.minY.rounded()))"
            }.joined(separator: "\n")
            repeatedContent = content == previousVisibleContent ? repeatedContent + 1 : 0
            if repeatedContent >= 2 {
                reachedBottom = true
                break
            }
            previousVisibleContent = content
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                .press(forDuration: 0.05,
                       thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)))
        }
        XCTAssertTrue(reachedBottom, "Inventory must reach the observed bottom or stable end of Preferences")
        // DuoLiveUITests.swift revisits only missed rows after the forward inventory; sheet dismissal can shift a row past a viewport edge.
        let backfill = preferencePickerKeys.reversed().filter {
            !visited.contains($0) && !missingPickerReason($0, parentValues: parentValues).hasPrefix("hidden:")
        }
        for key in backfill {
            let row = try scrollToPreference(key, backward: true)
            try auditPreferencePicker(key, original: row.snapshot())
            seen.insert(key)
            visited.append(key)
        }
        let unresolved = preferencePickerKeys.filter {
            !visited.contains($0) && !missingPickerReason($0, parentValues: parentValues).hasPrefix("hidden:")
        }
        XCTAssertTrue(unresolved.isEmpty, "Unreachable or undetermined picker keys: \(unresolved.joined(separator: ", "))")
        try dismissAuditPreferences()
    }

    private let preferencePickerKeys = [
        "default_order", "default_folder_read_filter", "default_feed_read_filter", "default_confirm_read_filter",
        "after_mark_read", "feed_opening", "default_mark_read_filter", "discover_display", "cluster_mode",
        "story_toolbar_position", "story_titles_position", "story_titles_style", "story_list_preview_text_size",
        "story_list_preview_images_size", "feed_list_sort_order", "app_opening", "infrequent_stories_per_month",
        "feed_list_font_size", "story_font_size", "theme_style", "theme_light", "theme_dark",
        "offline_download_connection", "offline_store_limit", "feed_title_swipe_left", "feed_title_swipe_right",
        "long_press_feed_title", "story_title_swipe_left", "story_title_swipe_right", "long_press_story_title",
        "double_tap_story", "two_finger_double_tap", "story_detail_swipe_left_edge", "story_browser", "app_unread_badge",
    ]

    private let conditionalPickerParents: [String: (key: String, hiddenWhenOn: Bool)] = [
        "cluster_mode": ("story_clustering", false),
        "infrequent_stories_per_month": ("show_infrequent_site_stories", false),
        "feed_list_font_size": ("use_system_font_size", true), "story_font_size": ("use_system_font_size", true),
        "offline_download_connection": ("offline_allowed", false), "offline_store_limit": ("offline_allowed", false),
        "feed_title_swipe_left": ("enable_feed_swipes", false), "feed_title_swipe_right": ("enable_feed_swipes", false),
        "story_title_swipe_left": ("enable_story_swipes", false), "story_title_swipe_right": ("enable_story_swipes", false),
    ]

    private func missingPickerReason(_ key: String, parentValues: [String: String]) -> String {
        guard let condition = conditionalPickerParents[key] else { return "unreachable" }
        guard let value = parentValues[condition.key]?.lowercased(), ["0", "1", "false", "true", "off", "on"].contains(value) else {
            return "undetermined: parent \(condition.key) was not observed"
        }
        let isOn = ["1", "true", "on"].contains(value)
        return isOn == condition.hiddenWhenOn ? "hidden: \(condition.key)=\(value)" : "unreachable: \(condition.key)=\(value)"
    }

    private func flattened(_ snapshot: XCUIElementSnapshot) -> [XCUIElementSnapshot] {
        [snapshot] + snapshot.children.flatMap { flattened($0) }
    }

    private func auditPreferencePicker(_ key: String, original: XCUIElementSnapshot) throws {
        activeAuditPickerKey = key
        app.buttons[key].tap()
        try requirePresentedPreferenceChoices(for: key)
        capture("duo-live-picker-inventory-\(key)")
        try dismissAuditPicker()
        let restored = try app.buttons[key].snapshot()
        XCTAssertEqual(restored.label, original.label, "Dismissing \(key) must preserve its value")
        XCTAssertEqual(String(describing: restored.value), String(describing: original.value))
    }

    private func requirePresentedPreferenceChoices(for key: String) throws {
        // DuoLiveUITests.swift identifies the exposed choice list by content, not the order of stacked sheet scroll views.
        var presentedChoices: [[XCUIElementSnapshot]] = []
        for scroll in app.scrollViews.allElementsBoundByIndex {
            let snapshot = try scroll.snapshot()
            let choices = flattened(snapshot).filter { $0.elementType == .button }
            guard choices.count >= 2,
                  !choices.contains(where: { preferencePickerKeys.contains($0.identifier) }),
                  choices.contains(where: { !$0.label.isEmpty && snapshot.frame.contains($0.frame) }),
                  scroll.isHittable else { continue }
            presentedChoices.append(choices)
        }
        XCTAssertEqual(presentedChoices.count, 1, "\(key) must expose one actual picker choice list")
        let choices = try XCTUnwrap(presentedChoices.first, "The center tap must open \(key)'s selectable choices")
        XCTAssertFalse(app.buttons[key].isHittable, "The picker must cover the underlying \(key) preference row")
        let attachment = XCTAttachment(string: choices.map(\.label).joined(separator: "\n"))
        attachment.name = "duo-live-picker-choices-\(key)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func choicePredicate(_ title: String) -> NSPredicate {
        // DuoLiveUITests.swift accepts SwiftUI's selected checkmark label while excluding the underlying preference row.
        NSPredicate(format: "label == %@ OR label BEGINSWITH %@", title, title + ",")
    }

    func test_addSiteFolderMenuAndEmptyNewFolderCanBeCancelled() throws {
        try requireVisibleFeeds()
        try tapFeedAction("feed-list-add", fallbackTitle: "Add Site")
        let field = app.textFields["add-site-url-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        let folderMenu = app.buttons["add-site-folder-menu"]
        XCTAssertTrue(waitUntilHittable(folderMenu))
        let originalFolder = folderMenu.value as? String
        folderMenu.tap()
        XCTAssertTrue(app.buttons["Top Level"].firstMatch.waitForExistence(timeout: 5))
        capture("duo-live-add-site-folder-menu")

        try dismissFolderMenu()
        XCTAssertTrue(waitUntilHittable(folderMenu))
        XCTAssertEqual(folderMenu.value as? String, originalFolder)
        let toggle = app.buttons["add-site-folder-toggle"]
        XCTAssertTrue(toggle.isHittable)
        toggle.tap()
        let folderName = app.textFields["New folder name"]
        XCTAssertTrue(folderName.waitForExistence(timeout: 5))
        folderName.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        capture("duo-live-add-site-empty-new-folder")
        XCTAssertFalse(app.buttons["add-site-submit-button"].isEnabled)
        toggle.tap()
        XCTAssertTrue(folderName.waitForDisappearance(timeout: 5))

        try dismissAddSite()
        try requireVisibleFeeds()
        capture("duo-live-add-site-cancelled")
    }

    func test_feedActionsRemainUsableAcrossRotations() throws {
        try requireVisibleFeeds()
        let original = XCUIDevice.shared.orientation
        guard original.isPortrait || original.isLandscape else {
            throw XCTSkip("A known starting orientation is required so the audit can restore it")
        }
        orientationToRestore = original
        let orientations: [(UIDeviceOrientation, String)] = [
            (.landscapeLeft, "landscape-left"), (.landscapeRight, "landscape-right"), (.portrait, "portrait"),
        ]
        for (orientation, name) in orientations {
            XCUIDevice.shared.orientation = orientation
            XCTAssertTrue(waitForStableFeeds(orientation: orientation), "Feeds must settle after rotating to \(name)")
            capture("duo-live-rotation-\(name)-feeds")
            try openPreferences()
            capture("duo-live-rotation-\(name)-preferences")
            try dismissAuditPreferences()
            XCTAssertTrue(waitForStableFeeds(orientation: orientation))
            try tapFeedAction("feed-list-add", fallbackTitle: "Add Site")
            XCTAssertTrue(waitUntilHittable(app.textFields["add-site-url-field"]))
            XCTAssertTrue(app.buttons["add-site-folder-menu"].isHittable)
            XCTAssertTrue(app.buttons["add-site-folder-toggle"].isHittable)
            capture("duo-live-rotation-\(name)-add-site")
            try dismissAddSite()
            XCTAssertTrue(waitForStableFeeds(orientation: orientation))
        }
    }

    private func openPreferences() throws {
        try tapFeedAction("feed-list-settings", fallbackTitle: "Settings")
        let preferences = app.staticTexts["Preferences"].firstMatch
        XCTAssertTrue(waitUntilHittable(preferences))
        auditPreferencesOpen = true
        preferences.tap()
        XCTAssertTrue(waitUntilHittable(app.buttons["default_order"]))
    }

    private func dismissFolderMenu() throws {
        let topLevel = app.buttons["Top Level"].firstMatch
        guard topLevel.exists else { return }
        let menu = app.menus.firstMatch
        // DuoLiveUITests.swift excludes the menu's observed horizontal extent; its rows can cover the sheet header.
        let row = topLevel.frame
        let appFrame = app.frame
        let excluded = menu.exists ? menu.frame : CGRect(x: row.minX - 24, y: appFrame.minY,
                                                         width: row.width + 48, height: appFrame.height)
        let field = app.textFields["add-site-url-field"]
        let fieldFrame = field.frame
        let fractions: [CGFloat] = [0.95, 0.05, 0.5]
        if field.exists, let fraction = fractions.first(where: {
            !excluded.insetBy(dx: -8, dy: -8).contains(CGPoint(x: fieldFrame.minX + fieldFrame.width * $0,
                                                             y: fieldFrame.midY))
        }) {
            // DuoLiveUITests.swift uses the observed editor's coordinate space; the expanded simulator's application frame can retain portrait dimensions.
            field.coordinate(withNormalizedOffset: CGVector(dx: fraction, dy: 0.5)).tap()
        } else {
            try tapOutside(excluded)
        }
        XCTAssertTrue(topLevel.waitForDisappearance(timeout: 5))
    }

    private func dismissAddSite() throws {
        let field = app.textFields["add-site-url-field"]
        guard field.exists else { return }
        try dismissFolderMenu()
        let header = app.descendants(matching: .any)["add-site-header"].firstMatch
        XCTAssertTrue(waitUntilHittable(header), "Only the observed Add Site header may dismiss its sheet")
        let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: destination)
        XCTAssertTrue(field.waitForDisappearance(timeout: 5))
    }

    private func recoverAuditModals() throws {
        for _ in 0..<5 {
            let imageClose = app.buttons["Close image"]
            if app.otherElements["story-image-viewer"].exists && imageClose.isHittable {
                imageClose.tap()
                XCTAssertTrue(app.otherElements["story-image-viewer"].waitForDisappearance(timeout: 5))
                continue
            }
            if auditDailyBriefingSettingsOpen {
                try dismissAuditDailyBriefingSettings()
                continue
            }
            if let key = activeAuditPickerKey {
                if app.buttons[key].isHittable {
                    // DuoLiveUITests.swift also handles a failed tap that never presented its tracked picker.
                    activeAuditPickerKey = nil
                } else {
                    try dismissAuditPicker()
                }
                continue
            }
            if auditAppIconChooserOpen {
                if appIconPreferenceRow.isHittable {
                    auditAppIconChooserOpen = false
                } else {
                    try dismissAuditAppIconChooser()
                }
                continue
            }
            if auditPreferencesOpen {
                if app.tables["feeds-list"].isHittable && !app.buttons["Done"].exists {
                    auditPreferencesOpen = false
                } else {
                    try dismissAuditPreferences()
                }
                continue
            }
            let markReadChoice = app.buttons["Older than 1 day"].firstMatch
            if shouldReturnToFeeds && markReadChoice.exists {
                try dismissNativeMenu(containing: markReadChoice)
                continue
            }
            if app.textFields["add-site-url-field"].exists {
                try dismissAddSite()
                continue
            }
            let preferenceTitles = ["Preferences", "Story order", "Mark stories read", "Story list toolbar position",
                                    "Swipe from the left edge while reading"]
            if app.staticTexts.matching(NSPredicate(format: "label IN %@", preferenceTitles)).firstMatch.exists,
               let done = app.buttons.matching(identifier: "Done").allElementsBoundByIndex.last(where: { $0.isHittable }) {
                done.tap()
                continue
            }
            let settingsMenu = app.tables.containing(.staticText, identifier: "Preferences").firstMatch
            if settingsMenu.exists && settingsMenu.isHittable {
                try tapOutside(settingsMenu.frame)
                XCTAssertTrue(settingsMenu.waitForDisappearance(timeout: 5))
                continue
            }
            if shouldReturnToFeeds { try returnToFeedsFromStoryList() }
            return
        }
        XCTFail("Audit sheets did not finish dismissing")
    }

    private func dismissNativeMenu(containing choice: XCUIElement) throws {
        let menu = app.menus.firstMatch
        let row = choice.frame
        let appFrame = app.frame
        let excluded = menu.exists ? menu.frame : CGRect(x: row.minX - 24, y: appFrame.minY,
                                                         width: row.width + 48, height: appFrame.height)
        try tapOutside(excluded)
        XCTAssertTrue(choice.waitForDisappearance(timeout: 5))
    }

    private func returnToFeedsFromStoryList() throws {
        let feeds = app.tables["feeds-list"]
        if feeds.exists && feeds.isHittable {
            shouldReturnToFeeds = false
            return
        }
        let feedsBack = app.buttons["expanded-feeds-back"]
        if feedsBack.exists && feedsBack.isHittable {
            feedsBack.tap()
            try requireVisibleFeeds()
            shouldReturnToFeeds = false
            return
        }
        // DuoLiveUITests.swift follows fullscreen's Sidebar to titles, then its explicit Feeds action.
        if let sidebar = app.buttons.matching(identifier: "Sidebar").allElementsBoundByIndex.first(where: { $0.isHittable }) {
            sidebar.tap()
            if feedsBack.exists && feedsBack.isHittable { feedsBack.tap() }
            try requireVisibleFeeds()
            shouldReturnToFeeds = false
            return
        }
        // DuoLiveUITests.swift uses UIKit's observed BackButton identifier because its label follows the current feed filter.
        let identifiedBackButtons = app.buttons.matching(identifier: "BackButton").allElementsBoundByIndex
        let candidates: [XCUIElement]
        if identifiedBackButtons.isEmpty {
            let predicate = NSPredicate(format: "label IN %@", ["Back", "Feeds", "All Sites", "NewsBlur"])
            candidates = app.toolbars.buttons.matching(predicate).allElementsBoundByIndex +
                app.navigationBars.buttons.matching(predicate).allElementsBoundByIndex
        } else {
            candidates = identifiedBackButtons
        }
        let visibleBack = candidates.first(where: { $0.isHittable })
        if visibleBack == nil {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "duo-live-missing-native-back-hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            capture("duo-live-missing-native-back")
        }
        let back = try XCTUnwrap(visibleBack,
                                "Story list must expose its safe back control in a native bar")
        back.tap()
        try requireVisibleFeeds()
        shouldReturnToFeeds = false
    }

    private func tapOutside(_ excluded: CGRect) throws {
        let geometry = XCTAttachment(string: "application=\(app.frame) windows=\(app.windows.allElementsBoundByIndex.map(\.frame)) excluded=\(excluded) orientation=\(XCUIDevice.shared.orientation.rawValue)")
        geometry.name = "duo-live-menu-dismiss-geometry"
        geometry.lifetime = .keepAlways
        add(geometry)
        let appFrame = app.frame
        let bounds = appFrame.insetBy(dx: 12, dy: 12)
        let candidates = [CGPoint(x: bounds.maxX, y: bounds.midY), CGPoint(x: bounds.minX, y: bounds.midY),
                          CGPoint(x: bounds.midX, y: bounds.minY), CGPoint(x: bounds.midX, y: bounds.maxY)]
        let point = try XCTUnwrap(candidates.first { !excluded.insetBy(dx: -8, dy: -8).contains($0) },
                                 "No observed safe point outside the menu")
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: point.x - appFrame.minX, dy: point.y - appFrame.minY)).tap()
    }

    private func waitForStableFeeds(orientation: UIDeviceOrientation) -> Bool {
        let feeds = app.tables["feeds-list"]
        var previousFrames: [CGRect] = []
        var stableSince: Date?
        var observations: [String] = []
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let actualOrientation = XCUIDevice.shared.orientation
            let appFrame = self.app.frame
            let feedFrame = feeds.frame
            observations.append("requested=\(orientation.rawValue) actual=\(actualOrientation.rawValue) app=\(appFrame) feeds=\(feedFrame)")
            guard actualOrientation == orientation, feeds.isHittable else {
                stableSince = nil
                return false
            }
            let frames = [appFrame, feedFrame]
            let visible = feedFrame.intersection(appFrame)
            guard visible.width > 100, visible.height > 100 else { return false }
            if frames != previousFrames {
                previousFrames = frames
                stableSince = Date()
                return false
            }
            if let started = stableSince { return Date().timeIntervalSince(started) >= 1 }
            stableSince = Date()
            return false
        }, object: nil)
        let result = XCTWaiter.wait(for: [settled], timeout: 15) == .completed
        let attachment = XCTAttachment(string: observations.joined(separator: "\n"))
        attachment.name = "duo-live-orientation-\(orientation.rawValue)-frames"
        attachment.lifetime = .keepAlways
        add(attachment)
        if !result { capture("duo-live-orientation-\(orientation.rawValue)-did-not-settle") }
        return result
    }

    private func requireVisibleFeeds() throws {
        let feeds = app.tables["feeds-list"]
        XCTAssertTrue(feeds.waitForExistence(timeout: 10), "Start this audit on the signed-in feed list")
        XCTAssertTrue(waitUntilHittable(feeds), "The feed list must be visible before the audit continues")
    }

    private func tapFeedAction(_ identifier: String, fallbackTitle: String) throws {
        let action = app.buttons[identifier]
        if !waitUntilHittable(action) {
            let overflow = app.buttons.allElementsBoundByIndex.first {
                ["More", "More options", "More Actions"].contains($0.label) && $0.isHittable
            }
            try XCTUnwrap(overflow, "The feed action or system overflow must be visible").tap()
        }
        let target = action.isHittable ? action : app.buttons[fallbackTitle].firstMatch
        XCTAssertTrue(waitUntilHittable(target), "\(identifier) must be reachable through UIKit's bar")
        target.tap()
    }

    private func scrollToPreference(_ key: String, backward: Bool = false) throws -> XCUIElement {
        let row = app.buttons[key]
        for _ in 0..<35 {
            let scroll = try XCTUnwrap(app.scrollViews.allElementsBoundByIndex.last { $0.isHittable },
                                       "Preferences must expose a scrollable list")
            if row.exists && row.isHittable && scroll.frame.insetBy(dx: 2, dy: 8).contains(row.frame) { return row }
            let start: CGFloat = backward ? 0.25 : 0.75
            let end: CGFloat = backward ? 0.75 : 0.25
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: start))
                .press(forDuration: 0.05,
                       thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: end)))
        }
        capture("duo-live-missing-preference-\(key)")
        XCTFail("Preference \(key) never became tappable")
        return row
    }

    private func dismissTopDone() throws {
        let done = try XCTUnwrap(app.buttons.matching(identifier: "Done").allElementsBoundByIndex.last { $0.isHittable },
                                 "The presented sheet must expose Done")
        done.tap()
    }

    private func dismissAuditPicker() throws {
        let key = try XCTUnwrap(activeAuditPickerKey, "Only a picker opened by this audit may be dismissed here")
        try dismissTopDone()
        guard waitUntilHittable(app.buttons[key]) else {
            XCTFail("Done must return to the tracked \(key) preference row")
            return
        }
        activeAuditPickerKey = nil
    }

    private func dismissAuditPreferences() throws {
        guard auditPreferencesOpen && activeAuditPickerKey == nil && !auditAppIconChooserOpen,
              app.staticTexts["Preferences"].firstMatch.exists else {
            XCTFail("Only the tracked Preferences sheet may be dismissed here")
            return
        }
        try dismissTopDone()
        guard waitUntilHittable(app.tables["feeds-list"]) else {
            XCTFail("Done must return from the audit's Preferences sheet to feeds")
            return
        }
        auditPreferencesOpen = false
    }

    private func dismissAuditAppIconChooser() throws {
        guard auditAppIconChooserOpen, app.staticTexts["App Icon"].firstMatch.exists else {
            XCTFail("Only the tracked App Icon chooser may be dismissed here")
            return
        }
        try dismissTopDone()
        guard waitUntilHittable(appIconPreferenceRow) else {
            XCTFail("Done must return to the App Icon preference row")
            return
        }
        auditAppIconChooserOpen = false
    }

    private func dismissAuditDailyBriefingSettings() throws {
        guard auditDailyBriefingSettingsOpen else { return }
        let settings = app.buttons["story-list-discover"]
        if settings.isHittable && !app.staticTexts["Daily Briefing Settings"].exists {
            auditDailyBriefingSettingsOpen = false
            auditDailyBriefingSettingsScroll = nil
            return
        }
        let scroll = try XCTUnwrap(auditDailyBriefingSettingsScroll ?? app.scrollViews.allElementsBoundByIndex.first {
            $0.staticTexts["Daily Briefing Settings"].exists && $0.isHittable
        }, "Only the tracked Daily Briefing settings sheet may be dismissed")
        let popover = app.popovers.firstMatch
        let excluded = popover.exists ? popover.frame : scroll.frame
        let appFrame = app.frame
        // DuoLiveUITests.swift uses the observed outer margin; compact popovers can leave less than 12pt beside their form.
        let bounds = appFrame.insetBy(dx: 2, dy: 2)
        let candidates = [CGPoint(x: bounds.minX, y: bounds.midY), CGPoint(x: bounds.maxX, y: bounds.midY),
                          CGPoint(x: bounds.midX, y: bounds.minY), CGPoint(x: bounds.midX, y: bounds.maxY)]
        let point = try XCTUnwrap(candidates.first { !excluded.contains($0) }, "The settings popover must have an observed outside margin")
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: point.x - appFrame.minX, dy: point.y - appFrame.minY)).tap()
        XCTAssertTrue(waitUntilHittable(settings), "Dismissing settings must return to Daily Briefing")
        auditDailyBriefingSettingsOpen = false
        auditDailyBriefingSettingsScroll = nil
    }

    private func waitUntilHittable(_ element: XCUIElement) -> Bool {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            element.exists && element.isHittable
        }, object: nil)
        return XCTWaiter.wait(for: [ready], timeout: 5) == .completed
    }

    private func capture(_ name: String) {
        // DuoLiveUITests.swift captures each device display because app.screenshot() selects Duo's inactive outer screen when open.
        for (index, screen) in XCUIScreen.screens.enumerated() {
            let attachment = XCTAttachment(screenshot: screen.screenshot())
            attachment.name = "\(name)-display-\(index)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}

private extension XCUIElement {
    func waitForDisappearance(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
