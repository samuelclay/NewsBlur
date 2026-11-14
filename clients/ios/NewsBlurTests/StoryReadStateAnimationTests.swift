import XCTest
import UIKit
import SwiftUI

@testable import NewsBlur

@MainActor final class Test_StoryReadStateAnimation: XCTestCase {
    private let defaults = UserDefaults.standard
    private let preferences: [String: Any] = [
        "theme_style": "light", "theme_light": "light", "theme_dark": "dark",
        "feed_list_spacing": "comfortable", "story_list_preview_images_size": "large_right",
        "story_list_preview_text_size": "medium"
    ]
    private var saved = [String: Any]()

    override func setUp() {
        super.setUp()
        for (key, value) in preferences {
            saved[key] = defaults.object(forKey: key)
            defaults.set(value, forKey: key)
        }
    }

    override func tearDown() {
        for key in preferences.keys {
            if let value = saved[key] { defaults.set(value, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }
        saved.removeAll()
        super.tearDown()
    }

    func test_scrollReadFadesExistingParentAndRelatedCellsWithoutReloading() throws {
        let fixture = makeFixture(markRelated: true)
        defer { fixture.window.isHidden = true }

        fixture.markRead()

        XCTAssertTrue(fixture.table.parent.isRead)
        XCTAssertTrue(fixture.table.related.isRead)
        XCTAssertFalse(fixture.table.other.isRead)
        for cell in [fixture.table.parent, fixture.table.related] {
            let animations = activeAnimations(in: cell.layer)
            XCTAssertFalse(animations.isEmpty, "StoryReadStateAnimationTests.swift: a visible read change must fade instead of snapping.")
            XCTAssertTrue(animations.contains { $0.duration >= 0.15 && $0.duration <= 0.3 })
            XCTAssertEqual(cell.alpha, 1, "The final cell opacity must preserve its existing read appearance.")
        }
        XCTAssertTrue(activeAnimations(in: fixture.table.other.layer).isEmpty)
        XCTAssertEqual(fixture.table.reloadCount, 0)
    }

#if targetEnvironment(macCatalyst)
    func test_macRelatedReadTitleAndDateUseTheSameGray() throws {
        let fixture = makeFixture(markRelated: true)
        defer { fixture.window.isHidden = true }
        (fixture.app as? ReadFadeAppDelegate)?.image = nil
        let cell = fixture.table.related
        cell.storyTitle = "MMMMMM"
        cell.storyDate = "MMMMMM"
        cell.clusterTier = nil
        cell.isRead = true
        for theme in ["light", "sepia", "medium", "dark"] {
            defaults.set(theme, forKey: "theme_style")
            for selected in [false, true] {
                cell.setSelected(selected, animated: false)
                let image = drawTypography(cell)
                let title = try dominantInk(in: image, rect: CGRect(x: 72, y: 75, width: 90, height: 30))
                let date = try dominantInk(in: image, rect: CGRect(x: 315, y: 75, width: 50, height: 30))
                XCTAssertEqual(title, date, "Related read title/date must match: \(theme) selected=\(selected)")
            }
        }
    }

    func test_macBylineUsesTheRegularPreviewWeight() throws {
        defaults.set("none", forKey: "story_list_preview_images_size")
        let fixture = makeFixture(markRelated: true)
        defer { fixture.window.isHidden = true }
        let cell = fixture.table.parent
        let text = "MMMMmmmm by Reporter"
        cell.storyAuthor = ""
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.alignment = .left
        paragraph.lineHeightMultiple = 0.95
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.preferredRange = .standard
        for selected in [false, true] {
            cell.setSelected(selected, animated: false)
            for read in [false, true] {
                cell.isRead = read
                cell.storyDate = text
                let actual = drawTypography(cell)
                cell.storyDate = ""
                let color = ThemeManager.color(fromRGB: read ? [0xB8B8B8] : [selected ? 0x888785 : 0x404040])
                let reference = UIGraphicsImageRenderer(size: cell.canvas.bounds.size, format: format).image { _ in
                    cell.canvas.draw(cell.canvas.bounds)
                    // StoryReadStateAnimationTests.swift compares actual byline glyphs with the same regular face as the preview.
                    (text as NSString).draw(in: CGRect(x: selected ? 36 : 34, y: 152, width: 336, height: 15),
                        withAttributes: [.font: UIFont(name: "WhitneySSm-Book", size: 11)!,
                                         .foregroundColor: color, .paragraphStyle: paragraph])
                }
                let crop = CGRect(x: 32 * 3, y: 150 * 3, width: 300 * 3, height: 20 * 3)
                let actualCrop = try XCTUnwrap(actual.cgImage?.cropping(to: crop))
                let expectedCrop = try XCTUnwrap(reference.cgImage?.cropping(to: crop))
                XCTAssertEqual(UIImage(cgImage: actualCrop).pngData(), UIImage(cgImage: expectedCrop).pngData(),
                               "The byline must use regular glyphs, selected=\(selected) read=\(read)")
            }
        }
    }

    func test_macReadTextUsesOneColorAndUnreadHeadingsMatchAcrossThemes() throws {
        defaults.set("none", forKey: "story_list_preview_images_size")
        let fixture = makeFixture(markRelated: true)
        defer { fixture.window.isHidden = true }
        let cell = fixture.table.parent
        cell.isSaved = false
        cell.isShared = false
        for read in [false, true] {
            cell.isRead = read
            let example = XCTAttachment(image: drawTypography(cell))
            example.name = "Mac story row example read=\(read)"
            example.lifetime = .keepAlways
            add(example)
        }
        cell.storyTitle = "MMMMMMMMMMMM"
        cell.siteTitle = "MMMMMMMMMMMM"
        cell.storyContent = "MMMMMMMMMMMM"
        cell.storyDate = "MMMMMMMMMMMM"
        cell.storyAuthor = ""
        for theme in ["light", "sepia", "medium", "dark"] {
            defaults.set(theme, forKey: "theme_style")
            for selected in [false, true] {
                cell.setSelected(selected, animated: false)
                for read in [false, true] {
                    cell.isRead = read
                    let image = drawTypography(cell)
                    let attachment = XCTAttachment(image: image)
                    attachment.name = "Mac text \(theme) selected=\(selected) read=\(read)"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                    let feed = try dominantInk(in: image, rect: CGRect(x: 60, y: 10, width: 160, height: 22))
                    let title = try dominantInk(in: image, rect: CGRect(x: 36, y: 40, width: 180, height: 48))
                    let preview = try dominantInk(in: image, rect: CGRect(x: 36, y: 95, width: 180, height: 45))
                    let byline = try dominantInk(in: image, rect: CGRect(x: 36, y: 150, width: 180, height: 20))
                    let state = "\(theme) selected=\(selected) read=\(read)"
                    print("MAC_TEXT_COLORS \(state) feed=\(feed) title=\(title) preview=\(preview) byline=\(byline)")
                    XCTAssertEqual(feed, title, "Feed and story title must match: \(state)")
                    XCTAssertEqual(preview, byline, "Preview and byline must match: \(state)")
                    if read {
                        XCTAssertEqual(title, preview, "All read text must share one gray: \(state)")
                    }
                }
            }
        }
    }

    private func drawTypography(_ cell: ReadFadeCell) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: cell.canvas.bounds.size, format: format).image { _ in
            // StoryReadStateAnimationTests.swift records the real native draw pass without resampling cached layer contents.
            cell.canvas.draw(cell.canvas.bounds)
        }
    }

    private func dominantInk(in image: UIImage, rect: CGRect) throws -> UInt32 {
        let bitmap = try XCTUnwrap(image.cgImage?.cropping(to: CGRect(x: rect.minX * image.scale,
            y: rect.minY * image.scale, width: rect.width * image.scale, height: rect.height * image.scale)))
        var pixels = [UInt32](repeating: 0, count: bitmap.width * bitmap.height)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: bitmap.width, height: bitmap.height,
            bitsPerComponent: 8, bytesPerRow: bitmap.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(bitmap, in: CGRect(x: 0, y: 0, width: bitmap.width, height: bitmap.height))
        let counts = pixels.reduce(into: [UInt32: Int]()) { $0[$1, default: 0] += 1 }
        let ranked = counts.sorted { $0.value > $1.value }
        XCTAssertGreaterThan(ranked.count, 1, "The crop must contain text, not just its background")
        // StoryReadStateAnimationTests.swift excludes the flat row background and samples solid glyph interiors at 3x.
        return try XCTUnwrap(ranked.dropFirst().first?.key)
    }
#endif

    func test_selectedStoryRefreshPreservesReadSaveShareAndRelatedArtworkWithoutReloading() {
        for markRelated in [false, true] {
            let fixture = makeFixture(markRelated: markRelated)
            defer { fixture.window.isHidden = true }
            let stories = fixture.controller.storiesCollection!
            fixture.app.storiesCollection = stories
            fixture.app.activeStory = stories.activeFeedStories[0] as? [AnyHashable: Any]
            fixture.app.recentlyReadStories["read-fade-parent"] = true
            var updated = fixture.app.activeStory!
            updated["starred"] = true
            updated["shared"] = true
            stories.setStories([updated, stories.activeFeedStories[1]])
            stories.calculateStoryLocations()
            fixture.app.activeStory = updated
            fixture.table.parent.isSaved = false
            fixture.table.parent.isShared = false
            fixture.table.related.isSaved = false
            fixture.table.related.isShared = false

            fixture.controller.redrawUnreadStory()

            XCTAssertEqual(fixture.table.reloadCount, 0)
            XCTAssertTrue(fixture.table.parent.isRead)
            XCTAssertTrue(fixture.table.parent.isSaved)
            XCTAssertTrue(fixture.table.parent.isShared)
            XCTAssertEqual(fixture.table.related.isRead, markRelated)
            XCTAssertFalse(fixture.table.related.isSaved)
            XCTAssertFalse(fixture.table.related.isShared)
            XCTAssertFalse(fixture.table.other.isRead)
            updated["starred"] = false
            updated["shared"] = false
            stories.setStories([updated, stories.activeFeedStories[1]])
            fixture.app.activeStory = updated

            fixture.controller.redrawUnreadStory()

            XCTAssertFalse(fixture.table.parent.isSaved)
            XCTAssertFalse(fixture.table.parent.isShared)
            XCTAssertEqual(fixture.table.reloadCount, 0)
        }
    }

    func test_selectedStoryRefreshUsesLatestIndividualRelatedReadStatus() {
        let fixture = makeFixture(markRelated: false)
        defer { fixture.window.isHidden = true }
        let stories = fixture.controller.storiesCollection!
        fixture.app.storiesCollection = stories
        var parent = stories.activeFeedStories[0] as! [String: Any]
        parent["cluster_stories"] = [["story_hash": "related-changed", "read_status": 1]]
        stories.setStories([parent, stories.activeFeedStories[1]])
        stories.calculateStoryLocations()
        fixture.app.activeStory = parent
        fixture.controller.setValue([
            ["type": 0, "story_location": 0],
            ["type": 1, "story_location": 0,
             "cluster_story": ["story_hash": "related-changed", "read_status": 0]],
            ["type": 0, "story_location": 1]
        ], forKey: "visibleStoryRows")

        fixture.controller.redrawUnreadStory()

        XCTAssertFalse(fixture.table.parent.isRead)
        XCTAssertTrue(fixture.table.related.isRead, "Related read updates must use the current model even when the parent remains unread")
        XCTAssertEqual(fixture.table.reloadCount, 0)
    }

    func test_relatedPreferenceOffLeavesRelatedArtworkAndAnimationUntouched() {
        let fixture = makeFixture(markRelated: false)
        defer { fixture.window.isHidden = true }

        fixture.markRead()

        XCTAssertTrue(fixture.table.parent.isRead)
        XCTAssertFalse(fixture.table.related.isRead)
        XCTAssertFalse(activeAnimations(in: fixture.table.parent.layer).isEmpty)
        XCTAssertTrue(activeAnimations(in: fixture.table.related.layer).isEmpty)
        XCTAssertEqual(fixture.table.reloadCount, 0)
    }

    func test_repeatedReadRefreshDoesNotRestartFade() {
        let fixture = makeFixture(markRelated: true)
        defer { fixture.window.isHidden = true }
        fixture.markRead()
        let before = activeAnimations(in: fixture.table.parent.layer).map { [$0.beginTime, $0.duration] }

        fixture.markRead()

        XCTAssertFalse(before.isEmpty)
        XCTAssertEqual(activeAnimations(in: fixture.table.parent.layer).map { [$0.beginTime, $0.duration] }, before)
        XCTAssertEqual(fixture.table.reloadCount, 0)
    }

    func test_reuseCancelsReadFadeBeforeDisplayingAnotherStory() {
        let fixture = makeFixture(markRelated: true)
        defer { fixture.window.isHidden = true }
        fixture.markRead()
        XCTAssertFalse(activeAnimations(in: fixture.table.parent.layer).isEmpty)

        fixture.table.parent.prepareForReuse()
        fixture.table.parent.storyHash = "read-fade-reused"
        fixture.table.parent.isRead = false

        XCTAssertTrue(activeAnimations(in: fixture.table.parent.layer).isEmpty)
        XCTAssertFalse(fixture.table.parent.isRead)
        XCTAssertEqual(fixture.table.parent.alpha, 1)
    }

    func test_offscreenReadRefreshDoesNotCreateAnimation() {
        let fixture = makeFixture(markRelated: true)
        fixture.window.isHidden = true
        fixture.table.removeFromSuperview()

        fixture.markRead()

        XCTAssertTrue(fixture.table.parent.isRead)
        XCTAssertTrue(activeAnimations(in: fixture.table.parent.layer).isEmpty)
        XCTAssertEqual(fixture.table.reloadCount, 0)
    }

    func test_changedStoryIdentityCancelsFadeWithoutRemovingOtherAnimations() {
        let fixture = makeFixture(markRelated: true)
        defer { fixture.window.isHidden = true }
        fixture.markRead()
        let cell = fixture.table.parent
        XCTAssertFalse(activeAnimations(in: cell.canvas.layer).isEmpty)
        let unrelated = CABasicAnimation(keyPath: "opacity")
        unrelated.fromValue = 1
        unrelated.toValue = 1
        unrelated.duration = 5
        cell.canvas.layer.add(unrelated, forKey: "test.unrelatedAnimation")

        cell.storyHash = "read-fade-another-story"

        XCTAssertEqual(cell.canvas.layer.animationKeys(), ["test.unrelatedAnimation"])
        XCTAssertEqual(cell.alpha, 1)
    }

    func test_sameStoryIdentityKeepsTheExistingFade() {
        let fixture = makeFixture(markRelated: true)
        defer { fixture.window.isHidden = true }
        fixture.markRead()
        let cell = fixture.table.parent
        let before = activeAnimations(in: cell.canvas.layer).map { [$0.beginTime, $0.duration] }

        cell.storyHash = String(cell.storyHash ?? "")

        XCTAssertFalse(before.isEmpty)
        XCTAssertEqual(activeAnimations(in: cell.canvas.layer).map { [$0.beginTime, $0.duration] }, before)
    }

    func test_normalReadAssignmentCancelsTheExistingFade() {
        for read in [false, true] {
            let fixture = makeFixture(markRelated: true)
            defer { fixture.window.isHidden = true }
            fixture.markRead()
            XCTAssertFalse(activeAnimations(in: fixture.table.parent.canvas.layer).isEmpty)

            fixture.table.parent.isRead = read

            XCTAssertTrue(activeAnimations(in: fixture.table.parent.canvas.layer).isEmpty)
            XCTAssertEqual(fixture.table.parent.isRead, read)
        }
    }

    func test_reducedMotionUpdatesReadArtworkWithoutAnimation() {
        let fixture = makeFixture(markRelated: true)
        defer { fixture.window.isHidden = true }
        fixture.table.parent.reduceMotion = true
        fixture.table.related.reduceMotion = true
        let before = bitmap(fixture.table.parent.canvas)

        fixture.markRead()
        display(fixture.table.parent)

        XCTAssertTrue(fixture.table.parent.isRead)
        XCTAssertTrue(activeAnimations(in: fixture.table.parent.canvas.layer).isEmpty)
        XCTAssertTrue(activeAnimations(in: fixture.table.related.canvas.layer).isEmpty)
        XCTAssertNotEqual(bitmap(fixture.table.parent.canvas), before)
        XCTAssertEqual(fixture.table.reloadCount, 0)
    }

    func test_defaultAnimationPolicyRespectsSystemReduceMotion() {
        let cell = FeedDetailTableCell(style: .default, reuseIdentifier: "policy")
        XCTAssertEqual(cell.readStateAnimationsEnabled, !UIAccessibility.isReduceMotionEnabled)
    }

    func test_presentedFixtureCanCaptureUnchangedArtworkWithoutReloading() {
        let fixture = makeFixture(markRelated: true)
        defer { fixture.window.isHidden = true }

        for cell in [fixture.table.parent, fixture.table.related] {
            XCTAssertNotNil(bitmap(cell.canvas))
            XCTAssertNotNil(bitmap(cell.canvas))
        }

        XCTAssertEqual(fixture.table.reloadCount, 0, fixture.table.reloadOrigins.joined(separator: "\n"))
        XCTAssertFalse(fixture.table.parent.isRead)
    }

    func test_cellOutsideTheVisibleWindowDoesNotAnimate() {
        let fixture = makeFixture(markRelated: true)
        defer { fixture.window.isHidden = true }
        fixture.table.parent.frame.origin.y = -500

        fixture.markRead()

        XCTAssertTrue(fixture.table.parent.isRead)
        XCTAssertTrue(activeAnimations(in: fixture.table.parent.canvas.layer).isEmpty)
    }

    func test_fadePublishesExactExistingReadPixelsAcrossThemesAndImageSides() {
        for theme in ["light", "sepia", "medium", "dark"] {
            defaults.set(theme, forKey: "theme_style")
            for imageStyle in ["none", "small_left", "large_right"] {
                defaults.set(imageStyle, forKey: "story_list_preview_images_size")
                let fixture = makeFixture(markRelated: true)
                defer { fixture.window.isHidden = true }
                let cells = [fixture.table.parent, fixture.table.related]
                let unread = cells.map { bitmap($0.canvas) }

                fixture.markRead()
                let faded = cells.map { bitmap($0.canvas) }

                for (index, cell) in cells.enumerated() {
                    XCTAssertNotEqual(faded[index], unread[index], "\(theme) \(imageStyle) row\(index)")
                    cell.isRead = true
                    cell.setNeedsDisplay()
                    display(cell)
                    XCTAssertEqual(bitmap(cell.canvas), faded[index],
                                   "The fade must publish the same final artwork as an immediate read redraw.")
                    XCTAssertEqual(cell.alpha, 1)
                    XCTAssertEqual(cell.canvas.alpha, 1)
                }
                XCTAssertEqual(fixture.table.reloadCount, 0)
            }
        }
    }

    func test_compositorFadeDoesNotContinuouslyRedrawTheCustomCanvas() {
        let fixture = makeFixture(markRelated: true)
        defer { fixture.window.isHidden = true }
        fixture.markRead()
        let canvases = [fixture.table.parent.canvas, fixture.table.related.canvas]
        let drawsAfterStateChange = canvases.map(\.drawCount)
        XCTAssertFalse(activeAnimations(in: fixture.table.parent.canvas.layer).isEmpty)
        let finished = expectation(description: "The short layer fade has elapsed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { finished.fulfill() }

        wait(for: [finished], timeout: 1)

        for (index, canvas) in canvases.enumerated() {
            XCTAssertLessThanOrEqual(canvas.drawCount - drawsAfterStateChange[index], 1,
                                     "Core Animation should composite the fade without redrawing text and images each frame.")
            XCTAssertTrue(activeAnimations(in: canvas.layer).isEmpty)
        }
        XCTAssertEqual(fixture.table.reloadCount, 0)
    }

    func test_tappingSelectedStoryDoesNotReplayReaderAppearanceOrReloadBeforeNextSelection() {
        for (grid, visible, compact) in [(false, true, false), (true, true, false), (true, false, false), (false, false, true)] {
            let app = RepeatedStoryTapApp()
            app.storiesCollection = StoriesCollection()
            app.storiesCollection.appDelegate = app
            let reader = RepeatedStoryTapPages()
            reader.appDelegate = app
            let detail = RepeatedStoryTapDetail()
            detail.grid = grid
            app.storyPagesViewController = reader
            app.detailViewController = detail
            let feed = RepeatedStoryTapFeed()
            feed.compact = compact
            feed.appDelegate = app
            feed.storiesCollection = app.storiesCollection
            let first: [AnyHashable: Any] = ["story_hash": "selected", "read_status": 1]
            let second: [AnyHashable: Any] = ["story_hash": "next", "read_status": 1]
            app.storiesCollection.activeFeedStories = [first, second]
            app.storiesCollection.activeFeedStoryLocations = NSMutableArray(array: [0, 1])
            app.storiesCollection.activeFeedStoryLocationIds = NSMutableArray(array: ["selected", "next"])
            app.storiesCollection.storyLocationsCount = 2
            app.activeStory = first
            feed.setValue([["type": 0, "story_location": 0], ["type": 0, "story_location": 1]], forKey: "visibleStoryRows")
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
            window.rootViewController = UIViewController()
            if visible {
                window.rootViewController?.view.addSubview(reader.view)
                window.isHidden = false
            }
            defer { window.isHidden = true }
            let expectedRepeatedLoads = compact || (grid && !visible) ? [0, 0] : []
            let initialAppearances = reader.appearances

            // StoryReadStateAnimationTests.swift uses the production title-selection entry point twice, then selects the next story.
            feed.perform(NSSelectorFromString("didSelectItemAtIndexPath:"), with: IndexPath(row: 0, section: 0))
            feed.perform(NSSelectorFromString("didSelectItemAtIndexPath:"), with: IndexPath(row: 0, section: 0))
            XCTAssertEqual(reader.appearances, initialAppearances, "Reselecting a visible story must not re-enter reader appearance; grid=\(grid)")
            XCTAssertEqual(feed.loadedRows, expectedRepeatedLoads, "Preserve a visible document, but reopen a compact or hidden grid reader; grid=\(grid), visible=\(visible), compact=\(compact)")
            feed.perform(NSSelectorFromString("didSelectItemAtIndexPath:"), with: IndexPath(row: 1, section: 0))
            XCTAssertEqual(feed.loadedRows, expectedRepeatedLoads + [1], "The following story should load exactly once; grid=\(grid)")
            app.storyPagesViewController = nil
            app.detailViewController = nil
        }
    }

    private func display(_ cell: FeedDetailTableCell) {
        cell.layer.displayIfNeeded()
        (cell.value(forKey: "cellContent") as? UIView)?.layer.displayIfNeeded()
    }

    private func bitmap(_ view: UIView) -> Data? {
        UIGraphicsImageRenderer(size: view.bounds.size).image { view.layer.render(in: $0.cgContext) }.pngData()
    }

    private func activeAnimations(in layer: CALayer) -> [CAAnimation] {
        (layer.animationKeys() ?? []).compactMap { layer.animation(forKey: $0) }
            + (layer.sublayers ?? []).flatMap { activeAnimations(in: $0) }
    }

    private func makeFixture(markRelated: Bool) -> ReadFadeFixture {
        let app = ReadFadeAppDelegate()
        app.fontDescriptorTitleSize = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption1).withSize(13)
        app.image = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 60)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 60))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 30, height: 60))
        }
        app.recentlyReadStories = NSMutableDictionary()
        app.selectedIntelligence = 0
        app.isPremiumArchive = true
        app.dictUserProfile = ["preferences": ["cluster_mark_read": markRelated]]
        let stories = StoriesCollection()
        stories.appDelegate = app
        stories.setStories([
            ["story_hash": "read-fade-parent", "story_feed_id": 1, "read_status": 0],
            ["story_hash": "read-fade-other", "story_feed_id": 1, "read_status": 0]
        ])
        let table = ReadFadeTable(frame: CGRect(x: 0, y: 0, width: 390, height: 700), style: .plain)
        let controller = ReadFadeController()
        controller.appDelegate = app
        controller.storiesCollection = stories
        controller.storyTitlesTable = table
        controller.setValue([
            ["type": 0, "story_location": 0],
            ["type": 1, "story_location": 0, "cluster_story": ["read_status": 0]],
            ["type": 0, "story_location": 1]
        ], forKey: "visibleStoryRows")

        let host = UIViewController()
        // StoryReadStateAnimationTests.swift supplies the visible hierarchy without storyboard toolbar outlets.
        controller.view = UIView(frame: table.frame)
        let window = UIWindow(frame: table.frame)
        window.rootViewController = host
        host.view.addSubview(table)
        for (index, cell) in [table.parent, table.related, table.other].enumerated() {
            // StoryReadStateAnimationTests.swift counts the same custom drawing while isolating its image provider.
            (cell.value(forKey: "cellContent") as? UIView)?.removeFromSuperview()
            cell.setValue(cell.canvas, forKey: "cellContent")
            cell.contentView.addSubview(cell.canvas)
            cell.renderingApp = app
            cell.setValue(app, forKey: "appDelegate")
            cell.frame = CGRect(x: 0, y: CGFloat(index) * 180, width: 390, height: 180)
            cell.storyHash = "read-fade-\(index)"
            cell.storyTitle = "A complete story title for the read transition"
            cell.storyContent = "The existing cell artwork should fade without rebuilding its row."
            cell.storyDate = "Today"
            cell.storyAuthor = "Reporter"
            cell.siteTitle = "Source"
            cell.siteFavicon = app.image
            cell.feedColorBar = .cyan
            cell.feedColorBarTopBorder = .blue
            cell.isRiverOrSocial = true
            cell.isSaved = true
            cell.textSize = .short
            cell.isRead = false
            table.addSubview(cell)
        }
        table.related.isClusterStory = true
        table.related.siteTitle = "Related source"
        table.related.clusterTier = "title"
        window.isHidden = false
        host.view.layoutIfNeeded()
        CATransaction.flush()
        for cell in [table.parent, table.related, table.other] {
            display(cell)
            // StoryReadStateAnimationTests.swift settles UIKit's first bitmap presentation before measuring read updates.
            _ = bitmap(cell.canvas)
        }
        XCTAssertNotNil(table.parent.window)
        table.reloadCount = 0
        table.reloadOrigins.removeAll()
        return ReadFadeFixture(app: app, controller: controller, table: table, window: window)
    }
}

@MainActor private final class ReadFadeController: FeedDetailViewController {
    override var isLegacyTable: Bool { true }
    override func viewDidLoad() {}
}

@MainActor private struct ReadFadeFixture {
    let app: NewsBlurAppDelegate
    let controller: FeedDetailViewController
    let table: ReadFadeTable
    let window: UIWindow

    func markRead() {
        let reloadsBefore = table.reloadCount
        app.recentlyReadStories["read-fade-parent"] = true
        controller.perform(NSSelectorFromString("refreshVisibleReadStateForStoryLocations:"),
                           with: NSIndexSet(index: 0))
        XCTAssertEqual(table.reloadCount, reloadsBefore, table.reloadOrigins.joined(separator: "\n"))
    }
}

@MainActor private final class ReadFadeTable: UITableView {
    let parent = ReadFadeCell(style: .default, reuseIdentifier: "parent")
    let related = ReadFadeCell(style: .default, reuseIdentifier: "related")
    let other = ReadFadeCell(style: .default, reuseIdentifier: "other")
    var reloadCount = 0
    var reloadOrigins = [String]()
    private var selectedPath: IndexPath?
    override var indexPathForSelectedRow: IndexPath? { selectedPath }
    override func selectRow(at indexPath: IndexPath?, animated: Bool, scrollPosition: UITableView.ScrollPosition) {
        // StoryReadStateAnimationTests.swift isolates artwork; StoryDetailLoadingTests.swift exercises real table selection.
        selectedPath = indexPath
    }

    override var indexPathsForVisibleRows: [IndexPath]? {
        (0..<3).map { IndexPath(row: $0, section: 0) }
    }

    override func cellForRow(at indexPath: IndexPath) -> UITableViewCell? {
        [parent, related, other][indexPath.row]
    }

    override func reloadData() {
        reloadCount += 1
        reloadOrigins.append(Thread.callStackSymbols.prefix(12).joined(separator: "\n"))
    }
    override func reloadRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {
        reloadCount += 1
        reloadOrigins.append(Thread.callStackSymbols.prefix(12).joined(separator: "\n"))
    }
}

private final class ReadFadeAppDelegate: NewsBlurAppDelegate {
    var image: UIImage?
    override func cachedImage(forStoryHash storyHash: String!) -> UIImage! { image }
}

@MainActor private final class ReadFadeCell: FeedDetailTableCell {
    let canvas = ReadFadeCanvas()
    var renderingApp: NewsBlurAppDelegate?
    var reduceMotion = false
    override var readStateAnimationsEnabled: Bool { !reduceMotion && super.readStateAnimationsEnabled }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        canvas.appDelegate = renderingApp
    }
}

@MainActor private final class ReadFadeCanvas: FeedDetailTableCellView {
    var drawCount = 0
    override func draw(_ rect: CGRect) {
        drawCount += 1
        super.draw(rect)
    }
}

@MainActor final class Test_ReaderMotion: XCTestCase {
    func test_feedEntranceWorkDoesNotGrowWithOffscreenFolders() throws {
        // StoryReadStateAnimationTests.swift protects filter responsiveness: scanning preceding folders per visible row made large subscriptions stall.
        func displayWork(sectionCount: Int) throws -> Int {
            let controller = ReaderMotionFeedsController()
            let table = ReaderMotionLargeFeedTable(frame: CGRect(x: 0, y: 0, width: 320, height: 500))
            table.sectionCount = sectionCount
            table.contentOffset = CGPoint(x: 0, y: 120)
            let header = UIView(frame: CGRect(x: 0, y: 120, width: 320, height: 45))
            let cells = (0..<5).map { row -> UITableViewCell in
                let cell = feedMotionCell(frame: CGRect(x: 0, y: 165 + row * 45, width: 320, height: 45))
                cell.accessibilityIdentifier = "large-list-feed-\(row)"
                return cell
            }
            table.displayedCells = cells
            table.addSubview(header)
            cells.forEach(table.addSubview)
            controller.feedTitlesTable = table
            controller.setValue(NSMutableDictionary(dictionary: [NSNumber(value: sectionCount - 1): header]), forKey: "folderTitleViews")
            let window = motionWindow(containing: [table])
            defer { window.isHidden = true }
            table.offscreenGeometryReads = 0
            let delegate: UITableViewDelegate = controller
            for (row, cell) in cells.enumerated() {
                delegate.tableView?(table, willDisplay: cell, forRowAt: IndexPath(row: row, section: sectionCount - 1))
            }
            delegate.tableView?(table, willDisplayHeaderView: header, forSection: sectionCount - 1)
            ReaderMotion.presentFeedRows(table, owner: controller)
            XCTAssertNotNil(header.layer.animation(forKey: "readerEntrance"))
            XCTAssertTrue(cells.allSatisfy { $0.layer.animation(forKey: "readerEntrance") != nil })
            return table.offscreenGeometryReads
        }
        let smallListWork = try displayWork(sectionCount: 20)
        let largeListWork = try displayWork(sectionCount: 1000)
        print("Feed motion offscreen geometry reads: 20 folders=\(smallListWork), 1000 folders=\(largeListWork)")
        XCTAssertLessThanOrEqual(largeListWork, smallListWork + 100,
                                 "The same six visible items must not scan thousands of offscreen folders to animate")
    }

    func test_pinnedFolderEntersBeforeItsFirstVisibleFeedAfterFilterReset() throws {
        // StoryReadStateAnimationTests.swift keeps a pinned header in the sequence after its original content frame scrolls away.
        let controller = ReaderMotionFeedsController()
        let table = ReaderMotionFeedOrderTable(frame: CGRect(x: 0, y: 0, width: 320, height: 500))
        table.contentOffset = CGPoint(x: 0, y: 120)
        let header = UIView(frame: CGRect(x: 0, y: 120, width: 320, height: 45))
        let cell = feedMotionCell(frame: CGRect(x: 0, y: 165, width: 320, height: 45))
        cell.accessibilityIdentifier = "feed-below-pinned-folder"
        table.displayedCells = [cell]
        table.addSubview(header)
        table.addSubview(cell)
        controller.feedTitlesTable = table
        controller.setValue(NSMutableDictionary(dictionary: [NSNumber(value: 1): header]), forKey: "folderTitleViews")
        let window = motionWindow(containing: [table])
        defer { window.isHidden = true }
        let delegate: UITableViewDelegate = controller
        delegate.tableView?(table, willDisplay: cell, forRowAt: IndexPath(row: 0, section: 1))
        delegate.tableView?(table, willDisplayHeaderView: header, forSection: 1)
        ReaderMotion.presentFeedRows(table, owner: controller)

        XCTAssertLessThan(try XCTUnwrap(header.layer.animation(forKey: "readerEntrance")).beginTime,
                          try XCTUnwrap(cell.layer.animation(forKey: "readerEntrance")).beginTime)
    }

    func test_rapidFeedFilterChangesApplyImmediatelyWithoutAnOutgoingOverlay() throws {
        // StoryReadStateAnimationTests.swift protects immediate cached filtering without snapshot fades or blocking HUDs.
        let defaults = UserDefaults.standard
        let oldIntelligence = defaults.object(forKey: "selectedIntelligence")
        defer {
            if let oldIntelligence { defaults.set(oldIntelligence, forKey: "selectedIntelligence") }
            else { defaults.removeObject(forKey: "selectedIntelligence") }
        }
        let controller = ReaderMotionFeedsController()
        controller.appDelegate = NewsBlurAppDelegate()
        controller.appDelegate.selectedIntelligence = 0
        let table = ReaderMotionFeedOrderTable(frame: CGRect(x: 0, y: 0, width: 320, height: 500))
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 45))
        table.addSubview(header)
        controller.view = UIView(frame: table.frame)
        controller.view.addSubview(table)
        controller.feedTitlesTable = table
        controller.intelligenceControl = UISegmentedControl(items: ["All", "Unread", "Focus", "Saved"])
        controller.intelligenceControl.selectedSegmentIndex = 1
        let window = motionWindow(containing: [controller.view])
        defer { window.isHidden = true }
        let delegate: UITableViewDelegate = controller
        delegate.tableView?(table, willDisplayHeaderView: header, forSection: 1)
        ReaderMotion.presentFeedRows(table, owner: controller)

        for (segment, intelligence, showsAll) in [(0, 0, true), (2, 1, false), (3, 2, false), (1, 0, false)] {
            controller.intelligenceControl.selectedSegmentIndex = segment
            controller.selectIntelligence()
            XCTAssertEqual(controller.appDelegate.selectedIntelligence, intelligence)
            XCTAssertEqual(controller.viewShowingAllFeeds, showsAll)
            XCTAssertNotNil(header.layer.animation(forKey: "readerEntrance"))
            XCTAssertTrue(controller.view.subviews.allSatisfy { $0 === table }, "Only the current list should remain above the filter controls")
            XCTAssertTrue(table.isUserInteractionEnabled)
        }
    }

    func test_changingFeedFilterReentersFoldersAndSitesButSelectingItAgainDoesNot() throws {
        // StoryReadStateAnimationTests.swift protects filter transitions even when a folder and feed survive both filters.
        let defaults = UserDefaults.standard
        let oldIntelligence = defaults.object(forKey: "selectedIntelligence")
        defer {
            if let oldIntelligence { defaults.set(oldIntelligence, forKey: "selectedIntelligence") }
            else { defaults.removeObject(forKey: "selectedIntelligence") }
        }
        let controller = ReaderMotionFeedsController()
        controller.appDelegate = NewsBlurAppDelegate()
        controller.appDelegate.selectedIntelligence = 0
        let table = ReaderMotionFeedOrderTable(frame: CGRect(x: 0, y: 0, width: 320, height: 500))
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 45))
        let cell = feedMotionCell(frame: CGRect(x: 0, y: 45, width: 320, height: 45))
        cell.accessibilityIdentifier = "surviving-filter-feed"
        table.displayedCells = [cell]
        controller.view = UIView(frame: table.frame)
        controller.view.addSubview(table)
        table.addSubview(header)
        table.addSubview(cell)
        controller.feedTitlesTable = table
        controller.intelligenceControl = UISegmentedControl(items: ["All", "Unread", "Focus", "Saved"])
        controller.intelligenceControl.selectedSegmentIndex = 1
        controller.setValue(NSMutableDictionary(dictionary: [NSNumber(value: 1): header]), forKey: "folderTitleViews")
        table.delegate = controller
        let window = motionWindow(containing: [controller.view])
        defer { window.isHidden = true }
        controller.viewIsAppearing(false)
        let delegate: UITableViewDelegate = controller
        delegate.tableView?(table, willDisplayHeaderView: header, forSection: 1)
        delegate.tableView?(table, willDisplay: cell, forRowAt: IndexPath(row: 0, section: 1))
        ReaderMotion.presentFeedRows(table, owner: controller)
        let oldHeaderStart = try XCTUnwrap(header.layer.animation(forKey: "readerEntrance")).beginTime

        controller.intelligenceControl.selectedSegmentIndex = 2
        controller.selectIntelligence()

        let changedHeader = try XCTUnwrap(header.layer.animation(forKey: "readerEntrance"))
        let changedFeed = try XCTUnwrap(cell.layer.animation(forKey: "readerEntrance"))
        XCTAssertNotEqual(changedHeader.beginTime, oldHeaderStart)
        XCTAssertLessThan(changedHeader.beginTime, changedFeed.beginTime)
        controller.selectIntelligence()
        XCTAssertEqual(try XCTUnwrap(header.layer.animation(forKey: "readerEntrance")).beginTime, changedHeader.beginTime)
    }

    func test_feedAppearanceIncludesHeadersPreparedBeforeTheWindowAttaches() throws {
        // StoryReadStateAnimationTests.swift protects startup headers whose willDisplay callback precedes attachment.
        let controller = ReaderMotionFeedsController()
        let table = ReaderMotionFeedOrderTable(frame: CGRect(x: 0, y: 0, width: 320, height: 500))
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 45))
        let cell = feedMotionCell(frame: CGRect(x: 0, y: 45, width: 320, height: 45))
        cell.accessibilityIdentifier = "prepared-feed"
        table.displayedCells = [cell]
        controller.view = UIView(frame: table.frame)
        controller.view.addSubview(table)
        table.addSubview(header)
        table.addSubview(cell)
        controller.feedTitlesTable = table
        controller.setValue(NSMutableDictionary(dictionary: [NSNumber(value: 1): header]), forKey: "folderTitleViews")
        table.delegate = controller
        controller.tableView(table, willDisplayHeaderView: header, forSection: 1)
        controller.tableView(table, willDisplay: cell, forRowAt: IndexPath(row: 0, section: 1))
        XCTAssertNil(header.layer.animation(forKey: "readerEntrance"))
        XCTAssertNil(cell.layer.animation(forKey: "readerEntrance"))

        let window = motionWindow(containing: [controller.view])
        defer { window.isHidden = true }
        controller.viewIsAppearing(false)

        let headerStart = try XCTUnwrap(header.layer.animation(forKey: "readerEntrance")).beginTime
        let feedStart = try XCTUnwrap(cell.layer.animation(forKey: "readerEntrance")).beginTime
        XCTAssertLessThan(headerStart, feedStart)
        controller.viewIsAppearing(false)
        XCTAssertEqual(try XCTUnwrap(header.layer.animation(forKey: "readerEntrance")).beginTime, headerStart,
                       "Returning to the feed list must not restart its already visible folders")
    }

    func test_feedFoldersAndSitesShareOneStrictScreenOrder() throws {
        // StoryReadStateAnimationTests.swift protects the visible sequence from treating a header and its first feed as the same row.
        let controller = FeedsObjCViewController()
        let table = ReaderMotionFeedOrderTable(frame: CGRect(x: 0, y: 0, width: 320, height: 500))
        let topLevel = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 45))
        let folder = UIView(frame: CGRect(x: 0, y: 45, width: 320, height: 45))
        let firstFeed = feedMotionCell(frame: CGRect(x: 0, y: 90, width: 320, height: 45))
        firstFeed.accessibilityIdentifier = "feed-order-first"
        let secondFeed = feedMotionCell(frame: CGRect(x: 0, y: 135, width: 320, height: 45))
        secondFeed.accessibilityIdentifier = "feed-order-second"
        let nextFolder = UIView(frame: CGRect(x: 0, y: 180, width: 320, height: 45))
        let orderedViews: [UIView] = [topLevel, folder, firstFeed, secondFeed, nextFolder]
        orderedViews.forEach(table.addSubview)
        let window = motionWindow(containing: [table])
        defer { window.isHidden = true }
        let delegate: UITableViewDelegate = controller

        // StoryReadStateAnimationTests.swift reproduces UIKit delivering headers and cells in separate passes.
        delegate.tableView?(table, willDisplay: secondFeed, forRowAt: IndexPath(row: 1, section: 1))
        delegate.tableView?(table, willDisplay: firstFeed, forRowAt: IndexPath(row: 0, section: 1))
        delegate.tableView?(table, willDisplayHeaderView: nextFolder, forSection: 2)
        delegate.tableView?(table, willDisplayHeaderView: folder, forSection: 1)
        delegate.tableView?(table, willDisplayHeaderView: topLevel, forSection: 0)
        ReaderMotion.presentFeedRows(table, owner: controller)

        let starts = try orderedViews.map { try XCTUnwrap($0.layer.animation(forKey: "readerEntrance")).beginTime }
        for index in 1..<starts.count {
            XCTAssertLessThan(starts[index - 1], starts[index], "Each folder and site must enter after the item above it")
        }
    }

    func test_returningToPreviouslyPresentedListDoesNotHideNewlyPreparedRows() {
        let owner = FeedDetailObjCViewController()
        let session = ReaderMotion.session(owner)
        session.didAppear()
        let cell = FeedDetailTableCell(style: .default, reuseIdentifier: "returning-story")
        cell.storyHash = "story-reached-while-reading"
        cell.frame = CGRect(x: 0, y: 0, width: 320, height: 100)

        // StoryReadStateAnimationTests.swift models next-story navigation preparing rows while the list is detached.
        ReaderMotion.row(cell.contentView, key: cell.storyHash!, owner: owner, scrolling: false, position: 0)
        let window = motionWindow(containing: [cell])
        defer { window.isHidden = true }
        window.layoutIfNeeded()

        XCTAssertNil(cell.contentView.layer.animation(forKey: "readerWaitingForAppearance"),
                     "Returning to an already presented list must show prepared rows without waiting for another display callback.")
        XCTAssertEqual(cell.contentView.layer.opacity, 1)
    }

    func test_nativeToolbarFollowsVisualOrderAndReentersOnlyAfterBeingHidden() throws {
        let bar = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
        let lower = UIButton(frame: CGRect(x: 0, y: 50, width: 40, height: 40))
        let upper = UIButton(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        lower.isEnabled = false
        lower.alpha = 0.35
        bar.addSubview(lower)
        bar.addSubview(upper)
        let window = motionWindow(containing: [bar])
        defer { window.isHidden = true }
        ReaderMotion.toolbarControls(bar)
        let first = try XCTUnwrap(upper.layer.animation(forKey: "readerEntrance"))
        let second = try XCTUnwrap(lower.layer.animation(forKey: "readerEntrance"))
        XCTAssertLessThan(first.beginTime, second.beginTime)
        for button in [lower, upper] { button.layer.removeAllAnimations() }
        ReaderMotion.toolbarControls(bar)
        XCTAssertNil(upper.layer.animation(forKey: "readerEntrance"))
        bar.isHidden = true
        ReaderMotion.toolbarControls(bar)
        bar.isHidden = false
        ReaderMotion.toolbarControls(bar)
        XCTAssertNotNil(upper.layer.animation(forKey: "readerEntrance"))
        XCTAssertEqual(lower.alpha, 0.35, accuracy: 0.001)
        XCTAssertFalse(lower.isEnabled)
    }

    func test_headerControlsWaitForAppearanceAndOnlyChangedControlsAnimate() throws {
        let parent = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        let toolbar = StoryToolbar()
        toolbar.setup(in: parent)
        toolbar.listenButton.isHidden = false
        XCTAssertNil(toolbar.backButton.layer.animation(forKey: "readerEntrance"))
        let window = motionWindow(containing: [parent])
        defer { window.isHidden = true }
        parent.layoutIfNeeded()
        let controls = [toolbar.backButton, toolbar.listenButton, toolbar.settingsButton, toolbar.browserButton]
        for control in controls {
            XCTAssertNotNil(control.layer.animation(forKey: "readerEntrance"))
            control.layer.removeAllAnimations()
        }
        toolbar.setNeedsLayout()
        toolbar.layoutIfNeeded()
        XCTAssertTrue(controls.allSatisfy { $0.layer.animationKeys()?.isEmpty ?? true })
        toolbar.listenButton.accessibilityLabel = "Pause listening"
        toolbar.setNeedsLayout()
        toolbar.layoutIfNeeded()
        XCTAssertNotNil(toolbar.listenButton.layer.animation(forKey: "readerControlChange"))
        XCTAssertNil(toolbar.backButton.layer.animation(forKey: "readerEntrance"))
        XCTAssertNil(toolbar.settingsButton.layer.animation(forKey: "readerControlChange"))
    }

    func test_controlMotionIgnoresDecorativeSubviewsButTracksItsVisibleTitle() throws {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 60))
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 160, height: 44))
        button.accessibilityLabel = "Back to story titles"
        let title = UILabel(frame: button.bounds)
        title.text = "Swift Weekly"
        button.addSubview(title)
        container.addSubview(button)
        let window = motionWindow(containing: [container])
        defer { window.isHidden = true }
        ReaderMotion.controls([button], in: container)
        button.layer.removeAllAnimations()

        // StoryReadStateAnimationTests.swift models UIKit adding and naming a decorative symbol during layout.
        let icon = UIImageView()
        button.addSubview(icon)
        ReaderMotion.controls([button], in: container)
        XCTAssertTrue(button.layer.animationKeys()?.isEmpty ?? true)
        icon.accessibilityLabel = "audiobook"
        ReaderMotion.controls([button], in: container)
        XCTAssertTrue(button.layer.animationKeys()?.isEmpty ?? true)

        title.text = "Design Notes"
        ReaderMotion.controls([button], in: container)
        XCTAssertNotNil(button.layer.animation(forKey: "readerControlChange"))
        XCTAssertNil(button.layer.animation(forKey: "readerEntrance"))
    }

    func test_traversalEntranceCascadesIndividualControls() throws {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 60))
        let window = motionWindow(containing: [container])
        defer { window.isHidden = true }
        let bar = StoryTraverseBar()
        bar.setup(in: container)
        container.layoutIfNeeded()
        let controls = [bar.textButton, bar.sendButton, bar.previousButton, bar.nextButton]
        let entrances = try controls.map { try XCTUnwrap($0.layer.animation(forKey: "readerEntrance")) }
        for index in 1..<entrances.count {
            XCTAssertGreaterThan(entrances[index].beginTime, entrances[index - 1].beginTime)
        }
        XCTAssertNil(bar.leftGroupView.layer.animation(forKey: "readerEntrance"))
        XCTAssertNil(bar.rightGroupView.layer.animation(forKey: "readerEntrance"))
    }

    func test_scrollingStoryRowsAreAlreadyVisibleAndDoNotReplayAfterScrollingStops() {
        let owner = ReaderMotionThemeController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UIViewController()
        window.isHidden = false
        defer { window.isHidden = true }
        let row = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 80))
        window.rootViewController?.view.addSubview(row)
        ReaderMotion.row(row, key: "scrolled-story", owner: owner, scrolling: true, position: 0)
        XCTAssertNil(row.layer.animation(forKey: "readerEntrance"), "Scrolling must never fade in newly visible story titles")
        XCTAssertEqual(row.alpha, 1)
        ReaderMotion.row(row, key: "scrolled-story", owner: owner, scrolling: false, position: 0)
        XCTAssertNil(row.layer.animation(forKey: "readerEntrance"), "An idle callback must not replay a scrolled row")
    }


    func test_dragCancelsCurrentAndPreparedRowsPreservingReadOpacityAndFeedListMotion() throws {
        let owner = ReaderMotionThemeController()
        let visible = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 80))
        visible.alpha = 0.4
        let window = motionWindow(containing: [visible])
        defer { window.isHidden = true }
        let swipe = CABasicAnimation(keyPath: "transform.translation.x")
        swipe.toValue = 20; swipe.duration = 1
        visible.layer.add(swipe, forKey: "swipe")
        ReaderMotion.row(visible, key: "opening", owner: owner, scrolling: false, position: 3)
        XCTAssertNotNil(visible.layer.animation(forKey: "readerEntrance"))
        let prepared = UIView()
        prepared.alpha = 0.6
        ReaderMotion.row(prepared, key: "prefetched", owner: owner, scrolling: false, position: 4)
        XCTAssertNotNil(prepared.layer.animation(forKey: "readerWaitingForAppearance"))
        owner.storyTitlesTable = UITableView()

        owner.scrollViewWillBeginDragging(owner.storyTitlesTable)

        XCTAssertNil(visible.layer.animation(forKey: "readerEntrance"))
        XCTAssertNil(prepared.layer.animation(forKey: "readerWaitingForAppearance"))
        XCTAssertNotNil(visible.layer.animation(forKey: "swipe"))
        XCTAssertEqual(visible.alpha, 0.4, accuracy: 0.001)
        XCTAssertEqual(prepared.alpha, 0.6, accuracy: 0.001)
        ReaderMotion.row(visible, key: "later-page", owner: owner, scrolling: false, position: 0)
        XCTAssertNil(visible.layer.animation(forKey: "readerEntrance"), "Pagination after scrolling must already be rendered")

        let feedListOwner = NSObject()
        ReaderMotion.row(visible, key: "feed", owner: feedListOwner, scrolling: true, position: 0)
        XCTAssertNotNil(visible.layer.animation(forKey: "readerEntrance"), "Story scrolling must not disable feed-list choreography")
        visible.layer.removeAnimation(forKey: "readerEntrance")
        ReaderMotion.session(owner).reset()
        ReaderMotion.row(visible, key: "opening", owner: owner, scrolling: false, position: 0)
        XCTAssertNotNil(visible.layer.animation(forKey: "readerEntrance"), "Opening another feed restores the initial cascade")
    }

    func test_cardSessionStopsPendingAndFutureEntrancesUntilAnotherFeedOpens() {
        let session = ReaderMotionSession()
        let viewport = CGRect(x: 0, y: 0, width: 320, height: 600)
        XCTAssertNotNil(session.start(for: "first", frame: viewport, viewport: viewport))
        session.stopEntrances()
        XCTAssertNil(session.ongoingStart(for: "first"))
        XCTAssertNil(session.start(for: "prefetched", frame: viewport, viewport: viewport))
        session.didAppear()
        XCTAssertNil(session.start(for: "pagination", frame: viewport, viewport: viewport))
        session.reset()
        XCTAssertNotNil(session.start(for: "next-feed", frame: viewport, viewport: viewport))
    }

    func test_prefetchedSwiftUICardIsFullyRenderedWhenScrollingStarts() async throws {
        let session = ReaderMotionSession()
        let host = UIHostingController(rootView: ZStack {
            Color.white
            Color.red.frame(width: 80, height: 80)
                .modifier(ReaderEntrance(session: session, key: "prefetched"))
                .environment(\.readerMotionViewport, .zero)
        }.ignoresSafeArea())
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previousKeyWindow?.makeKey() }
        host.view.backgroundColor = .white
        host.view.layoutIfNeeded()
        func redCenter() -> Bool {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let image = UIGraphicsImageRenderer(bounds: host.view.bounds, format: format).image { _ in
                host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
            }
            guard let cgImage = image.cgImage else { return false }
            var pixel: [UInt8] = [0, 0, 0, 0]
            let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(cgImage, in: CGRect(x: -cgImage.width / 2, y: -cgImage.height / 2,
                                           width: cgImage.width, height: cgImage.height))
            return pixel[0] > 200 && pixel[1] < 100 && pixel[2] < 100
        }
        XCTAssertFalse(redCenter(), "A prefetched card starts outside the opening viewport")
        session.stopEntrances()
        let deadline = Date().addingTimeInterval(SimulatorTestTiming.realWorkTimeout)
        while !redCenter(), Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(redCenter(), "A prefetched card must be rendered before it scrolls into the viewport")
    }

    func test_loadingDepartureDoesNotCreateOffscreenRowsOrTriggerDisplayCallbacks() {
        let table = UITableView(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        let host = UIView(frame: table.frame)
        let source = ReaderMotionLoadingDataSource()
        table.dataSource = source
        table.delegate = source
        host.addSubview(table)
        table.reloadData()
        XCTAssertEqual(source.cellsRequested, 0)

        ReaderMotion.retireLoadingRows(table)

        XCTAssertEqual(source.cellsRequested, 0, "An outgoing visual must not materialize rows before the data reload.")
        XCTAssertEqual(source.displayedRows, 0, "FeedDetailObjCViewController.m schedules pagination from display callbacks.")
    }

    func test_heldStoryCellReuseAndHashChangesCannotLeaveTheNextStoryBlank() throws {
        let owner = FeedDetailObjCViewController()
        ReaderMotion.session(owner).prepareForAppearance()
        let cell = FeedDetailTableCell(style: .default, reuseIdentifier: "held")
        cell.storyHash = "first"
        cell.contentView.alpha = 0.6
        ReaderMotion.row(cell.contentView, key: "first", owner: owner, scrolling: false, position: 0)
        XCTAssertNotNil(cell.contentView.layer.animation(forKey: "readerWaitingForAppearance"))
        cell.prepareForReuse()
        XCTAssertNil(cell.contentView.layer.animation(forKey: "readerWaitingForAppearance"))
        XCTAssertEqual(cell.contentView.alpha, 0.6, accuracy: 0.001)
        ReaderMotion.row(cell.contentView, key: "first", owner: owner, scrolling: false, position: 0)
        cell.storyHash = nil
        XCTAssertNil(cell.contentView.layer.animation(forKey: "readerWaitingForAppearance"), "A placeholder without a story hash will not get another row animation callback.")
    }

    func test_reduceMotionReleasesPendingRowsWithoutChangingTheirReadOpacity() throws {
        let owner = FeedDetailObjCViewController()
        ReaderMotion.session(owner).prepareForAppearance()
        let row = UIView()
        row.alpha = 0.4
        ReaderMotion.row(row, key: "waiting", owner: owner, scrolling: false, position: 0)
        XCTAssertNotNil(row.layer.animation(forKey: "readerWaitingForAppearance"))
        // StoryReadStateAnimationTests.swift invokes the accessibility observer's action without changing the user's setting.
        ReaderMotion.finishPendingEntrancesForReducedMotion()
        XCTAssertNil(row.layer.animation(forKey: "readerWaitingForAppearance"))
        XCTAssertEqual(row.alpha, 0.4, accuracy: 0.001)
        XCTAssertFalse(ReaderMotion.session(owner).hasSeen("waiting"))
    }

    func test_cachedRowsWaitForAppearanceAndReloadKeepsTheSameEntranceTime() throws {
        let owner = FeedDetailObjCViewController()
        let session = ReaderMotion.session(owner)
        session.prepareForAppearance()
        let first = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 80))
        let window = motionWindow(containing: [first])
        defer { window.isHidden = true }
        ReaderMotion.row(first, key: "cached", owner: owner, scrolling: false, position: 0)
        XCTAssertNil(first.layer.animation(forKey: "readerEntrance"))
        XCTAssertNotNil(first.layer.animation(forKey: "readerWaitingForAppearance"))
        XCTAssertFalse(session.hasSeen("cached"))

        session.didAppear()
        ReaderMotion.row(first, key: "cached", owner: owner, scrolling: false, position: 0)
        let entrance = try XCTUnwrap(first.layer.animation(forKey: "readerEntrance"))
        XCTAssertNil(first.layer.animation(forKey: "readerWaitingForAppearance"))
        first.layer.removeAnimation(forKey: "readerEntrance")
        let replacement = UIView(frame: first.frame)
        first.superview!.addSubview(replacement)
        ReaderMotion.row(replacement, key: "cached", owner: owner, scrolling: false, position: 0)
        XCTAssertEqual(try XCTUnwrap(replacement.layer.animation(forKey: "readerEntrance")).beginTime, entrance.beginTime)
        XCTAssertEqual(replacement.alpha, 1)
    }

    func test_swiftUICardsWaitForFirstAppearanceButVisibleSourceSwitchesStayReady() throws {
        let session = ReaderMotionSession()
        let viewport = CGRect(x: 0, y: 0, width: 320, height: 600)
        session.prepareForAppearance()
        XCTAssertNil(session.start(for: "prepared-card", frame: viewport, viewport: viewport))
        session.didAppear()
        XCTAssertNotNil(session.start(for: "prepared-card", frame: viewport, viewport: viewport))
        session.prepareForAppearance()
        XCTAssertTrue(session.presentationReady, "Returning to an already presented feed must not blank it.")
        session.reset()
        XCTAssertTrue(session.presentationReady, "A feed changed in an already visible iPad/Mac pane must animate immediately.")
        XCTAssertNotNil(session.start(for: "next-feed-card", frame: viewport, viewport: viewport))
    }

    private func feedMotionCell(frame: CGRect) -> UITableViewCell {
        // StoryReadStateAnimationTests.swift supplies the settled table layout after UIKit initializes its default cell frame.
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.frame = frame
        return cell
    }

    private func motionWindow(containing views: [UIView]) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        let host = UIViewController()
        window.rootViewController = host
        for view in views { host.view.addSubview(view) }
        window.isHidden = false
        return window
    }

    func test_preparedFeedRowsKeepTheirEntranceUntilTheyAreVisible() throws {
        let owner = NSObject()
        let row = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 80))
        // StoryReadStateAnimationTests.swift reproduces cached feeds preparing rows before the phone push.
        ReaderMotion.row(row, key: "cached-feed-story", owner: owner, scrolling: false, position: 0)
        XCTAssertNil(row.layer.animation(forKey: "readerEntrance"), "An off-window row must not spend its entrance before the feed is visible.")

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        let host = UIViewController()
        window.rootViewController = host
        host.view.addSubview(row)
        window.isHidden = false
        defer { window.isHidden = true }
        ReaderMotion.row(row, key: "cached-feed-story", owner: owner, scrolling: false, position: 0)
        XCTAssertNotNil(row.layer.animation(forKey: "readerEntrance"), "The first visible display must still animate.")
    }

    func test_variableHeightCardsStartFromTopToBottomRegardlessOfGeometryCallbackOrder() throws {
        let session = ReaderMotionSession()
        let viewport = CGRect(x: 0, y: 150, width: 320, height: 800)
        let frames = [CGRect(x: 0, y: 150, width: 320, height: 90),
                      CGRect(x: 0, y: 240, width: 320, height: 250),
                      CGRect(x: 0, y: 490, width: 320, height: 120)]
        var starts = [Int: CFTimeInterval]()
        for index in [2, 0, 1] {
            starts[index] = session.start(for: "card-\(index)", frame: frames[index], viewport: viewport)
        }
        XCTAssertLessThan(try XCTUnwrap(starts[0]), try XCTUnwrap(starts[1]))
        XCTAssertLessThan(try XCTUnwrap(starts[1]), try XCTUnwrap(starts[2]))
        XCTAssertNil(session.start(for: "card-1", frame: frames[1], viewport: viewport))
    }

    func test_loadingPulseKeepsItsPhaseAcrossReloadAndThemeChanges() throws {
        let defaults = UserDefaults.standard
        let keys = ["theme_style", "theme_light", "theme_dark"]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        defaults.set("light", forKey: "theme_style")
        defaults.set("light", forKey: "theme_light")
        defaults.set("dark", forKey: "theme_dark")
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        let host = UIView(frame: window.bounds)
        window.addSubview(host)
        let cell = NBLoadingCell(frame: CGRect(x: 0, y: 0, width: 320, height: 120))
        host.addSubview(cell)
        cell.animate()
        let first = try XCTUnwrap(cell.layer.animation(forKey: "readerLoadingPulse") as? CABasicAnimation)
        cell.endAnimation()
        cell.removeFromSuperview()
        host.addSubview(cell)
        cell.animate()
        let reattached = try XCTUnwrap(cell.layer.animation(forKey: "readerLoadingPulse") as? CABasicAnimation)
        XCTAssertEqual(first.beginTime, reattached.beginTime)
        defaults.set("dark", forKey: "theme_style")
        cell.animate()
        let dark = try XCTUnwrap(cell.layer.animation(forKey: "readerLoadingPulse") as? CABasicAnimation)
        XCTAssertEqual(first.beginTime, dark.beginTime)
        let color = try XCTUnwrap(cell.backgroundColor)
        XCTAssertEqual(color, ThemeManager.shared.storyListBackgroundColor)
        XCTAssertFalse((first.fromValue as! CGColor) == (dark.fromValue as! CGColor))
        cell.endAnimation()
    }

    func test_repeatedThemeApplicationKeepsTheVisibleNavigationTitleAndBackButtonHost() throws {
        let controller = ReaderMotionThemeController()
        let app = ReaderMotionThemeAppDelegate()
        controller.appDelegate = app
        controller.storiesCollection = StoriesCollection()
        controller.view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        let navigation = UINavigationController(navigationBarClass: ReaderMotionNavigationBar.self, toolbarClass: nil)
        navigation.viewControllers = [controller]
        controller.updateTheme()
        let title = try XCTUnwrap(controller.navigationItem.titleView)
        let bar = try XCTUnwrap(navigation.navigationBar as? ReaderMotionNavigationBar)
        let changes = bar.appearanceChanges
        controller.updateTheme()
        XCTAssertTrue(controller.navigationItem.titleView === title, "A no-op theme update must not replace a visible title during push.")
        XCTAssertEqual(bar.appearanceChanges, changes, "Rebuilding the navigation appearance can restart the native back-button crossfade.")
    }

    func test_storyEntrancesFollowVisualOrderWhenDisplayCallbacksArriveOutOfOrder() throws {
        let controller = FeedDetailObjCViewController()
        let table = UITableView(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        let cells = (0..<10).map { index -> FeedDetailTableCell in
            let cell = FeedDetailTableCell(style: .default, reuseIdentifier: nil)
            cell.storyHash = "ordered-story-\(index)"
            cell.frame = CGRect(x: 0, y: index * 50, width: 320, height: 50)
            return cell
        }
        let window = motionWindow(containing: cells)
        defer { window.isHidden = true }
        let delegate: UITableViewDelegate = controller
        for index in [9, 2, 5, 0, 8, 3, 6, 4, 7, 1] {
            delegate.tableView?(table, willDisplay: cells[index], forRowAt: IndexPath(row: index, section: 0))
        }
        let starts = try cells.map { try XCTUnwrap($0.contentView.layer.animation(forKey: "readerEntrance")).beginTime }
        // StoryReadStateAnimationTests.swift models Catalyst delivering the last visible cell first.
        for index in 1..<starts.count { XCTAssertLessThan(starts[index - 1], starts[index]) }
        XCTAssertLessThan(starts.last! - starts.first!, 0.175)
    }

    func test_loadingOnlyReloadKeepsTheSamePulseCell() throws {
        let controller = ReadFadeController()
        controller.view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 600))
        let selector = NSSelectorFromString("makeLoadingCell")
        let first = try XCTUnwrap(controller.perform(selector)?.takeUnretainedValue() as? NBLoadingCell)
        let second = try XCTUnwrap(controller.perform(selector)?.takeUnretainedValue() as? NBLoadingCell)
        XCTAssertTrue(first === second)
    }

    func test_repeatedLoadingDisplayDoesNotRestartItsEntrance() throws {
        let controller = FeedDetailObjCViewController()
        let table = UITableView()
        let cell = NBLoadingCell(frame: CGRect(x: 0, y: 0, width: 320, height: 120))
        let window = motionWindow(containing: [cell])
        defer { window.isHidden = true }
        let delegate: UITableViewDelegate = controller
        let indexPath = IndexPath(row: 0, section: 0)
        delegate.tableView?(table, willDisplay: cell, forRowAt: indexPath)
        let entrance = try XCTUnwrap(cell.layer.animation(forKey: "readerEntrance"))
        delegate.tableView?(table, willDisplay: cell, forRowAt: indexPath)
        let redisplayed = try XCTUnwrap(cell.layer.animation(forKey: "readerEntrance"))
        // StoryReadStateAnimationTests.swift catches the same loading row fading back to zero during reload.
        XCTAssertEqual(redisplayed.beginTime, entrance.beginTime)
    }

    func test_reusedStoriesDoNotReplayUntilTheFeedVisitResets() {
        let session = ReaderMotionSession()
        XCTAssertNotNil(session.delay(for: "feed:story"))
        XCTAssertNil(session.delay(for: "feed:story"))
        for index in 0..<100 {
            XCTAssertLessThanOrEqual(session.delay(for: "other-\(index)") ?? 1, 0.175)
        }
        session.reset()
        XCTAssertNotNil(session.delay(for: "feed:story"))
    }

    func test_entrancePreservesNavigationTransformAndReadOpacity() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 240, height: 80))
        view.transform = CGAffineTransform(translationX: 42, y: -10)
        view.alpha = 0.4
        let expectedTransform = view.transform
        ReaderMotion.enter(view, delay: 0, distance: 16)
        XCTAssertEqual(view.transform, expectedTransform)
        XCTAssertEqual(view.alpha, 0.4, accuracy: 0.001)
        view.layer.removeAllAnimations()
        XCTAssertEqual(view.transform, expectedTransform)
        XCTAssertEqual(view.alpha, 0.4, accuracy: 0.001)
    }
}

@MainActor private final class ReaderMotionThemeController: FeedDetailObjCViewController {
    override func viewDidLoad() {}
    override func reload() {}
    @objc(isPhoneOrCompact) func usesCompactLayout() -> Bool { true }
}

@MainActor private final class ReaderMotionLoadingDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    var cellsRequested = 0
    var displayedRows = 0
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        cellsRequested += 1
        return NBLoadingCell(frame: CGRect(x: 0, y: 0, width: 320, height: 120))
    }
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        displayedRows += 1
    }
}

@MainActor private final class ReaderMotionFeedOrderTable: UITableView {
    var displayedCells = [UITableViewCell]()
    // StoryReadStateAnimationTests.swift supplies fixed visible geometry rather than asking UIKit to create another data source's views.
    override func layoutSubviews() {}
    override var numberOfSections: Int { 3 }
    override func numberOfRows(inSection section: Int) -> Int { section == 1 ? 2 : 0 }
    override var visibleCells: [UITableViewCell] { displayedCells }
    override var indexPathsForVisibleRows: [IndexPath]? { displayedCells.indices.map { IndexPath(row: $0, section: 1) } }
    override func rectForHeader(inSection section: Int) -> CGRect {
        section == 1 ? CGRect(x: 0, y: 45, width: 320, height: 45) : .zero
    }
    override func indexPath(for cell: UITableViewCell) -> IndexPath? {
        displayedCells.firstIndex(of: cell).map { IndexPath(row: $0, section: 1) }
    }
    override func reloadRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {}
    override func scrollToRow(at indexPath: IndexPath, at scrollPosition: UITableView.ScrollPosition, animated: Bool) {}
}

@MainActor private final class ReaderMotionLargeFeedTable: UITableView {
    var sectionCount = 20
    var displayedCells = [UITableViewCell]()
    var offscreenGeometryReads = 0
    override func layoutSubviews() {}
    override var numberOfSections: Int { sectionCount }
    override func numberOfRows(inSection section: Int) -> Int {
        if section < sectionCount - 1 { offscreenGeometryReads += 1 }
        return 5
    }
    override func rectForHeader(inSection section: Int) -> CGRect {
        if section < sectionCount - 1 { offscreenGeometryReads += 1 }
        return .zero
    }
    override var visibleCells: [UITableViewCell] { displayedCells }
    override var indexPathsForVisibleRows: [IndexPath]? {
        displayedCells.indices.map { IndexPath(row: $0, section: sectionCount - 1) }
    }
    override func indexPath(for cell: UITableViewCell) -> IndexPath? {
        displayedCells.firstIndex(of: cell).map { IndexPath(row: $0, section: sectionCount - 1) }
    }
}

@MainActor private final class ReaderMotionFeedsController: FeedsObjCViewController {
    override func viewDidLoad() {}
    override func viewDidLayoutSubviews() {}
    override func calculateFeedLocations() {}
    override func reloadFeedTitlesTable() {}
    override func showExplainerOnEmptyFeedlist() {}
}

@MainActor private final class ReaderMotionThemeAppDelegate: NewsBlurAppDelegate {
    override func makeFeedTitle(_ feed: [AnyHashable: Any]!) -> UIView! { UILabel() }
}

@MainActor private final class ReaderMotionNavigationBar: UINavigationBar {
    var appearanceChanges = 0
    override var standardAppearance: UINavigationBarAppearance {
        didSet { appearanceChanges += 1 }
    }
}

@MainActor private final class RepeatedStoryTapFeed: FeedDetailViewController {
    var loadedRows: [Int] = []
    var compact = false
    override func viewDidLoad() {}
    @objc(isPhoneOrCompact) func usesCompactLayout() -> Bool { compact }
    override func markStoryReadIfNeeded(_ story: [AnyHashable: Any]!, isScrolling: Bool) -> Bool { false }
    override func loadStory(atRow row: Int) { loadedRows.append(row) }
    override func reload() {}
}

@MainActor private final class RepeatedStoryTapPages: StoryPagesViewController {
    var appearances = 0
    override func loadView() { view = UIView(frame: CGRect(x: 0, y: 0, width: 800, height: 600)) }
    override func viewDidLoad() {}
    override func viewWillLayoutSubviews() {}
    override func viewDidLayoutSubviews() {}
    override func viewWillAppear(_ animated: Bool) { appearances += 1 }
    override func viewDidAppear(_ animated: Bool) { appearances += 1 }
}

@MainActor private final class RepeatedStoryTapDetail: DetailViewController {
    var grid = false
    override var storyTitlesInGridView: Bool { grid }
    override func dismissFullscreenSidebarOverlayAfterStorySelection() {}
    override func restoreStoryKeyboardFocusIfNeeded() {}
}

@MainActor private final class RepeatedStoryTapApp: NewsBlurAppDelegate {
    override var isPhone: Bool { false }
    var testPages: StoryPagesViewController?
    override var storyPagesViewController: StoryPagesViewController! {
        get { testPages }
        set { testPages = newValue }
    }
    override func show(_ column: UISplitViewController.Column, debugInfo: String!, animated: Bool) {}
}
