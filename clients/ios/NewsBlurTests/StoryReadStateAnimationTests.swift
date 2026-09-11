import XCTest
import UIKit

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
