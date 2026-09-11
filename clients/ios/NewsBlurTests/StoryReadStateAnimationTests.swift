import XCTest
import UIKit

@testable import NewsBlur

@MainActor final class Test_StoryReadStateAnimation: XCTestCase {
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

    private func activeAnimations(in layer: CALayer) -> [CAAnimation] {
        (layer.animationKeys() ?? []).compactMap { layer.animation(forKey: $0) }
            + (layer.sublayers ?? []).flatMap { activeAnimations(in: $0) }
    }

    private func makeFixture(markRelated: Bool) -> ReadFadeFixture {
        let app = NewsBlurAppDelegate()
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
            cell.frame = CGRect(x: 0, y: CGFloat(index) * 180, width: 390, height: 180)
            cell.storyHash = "read-fade-\(index)"
            cell.storyTitle = "A complete story title for the read transition"
            cell.storyContent = "The existing cell artwork should fade without rebuilding its row."
            cell.storyDate = "Today"
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
        XCTAssertNotNil(table.parent.window)
        table.reloadCount = 0
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
        app.recentlyReadStories["read-fade-parent"] = true
        controller.perform(NSSelectorFromString("refreshVisibleReadStateForStoryLocations:"),
                           with: NSIndexSet(index: 0))
    }
}

@MainActor private final class ReadFadeTable: UITableView {
    let parent = FeedDetailTableCell(style: .default, reuseIdentifier: "parent")
    let related = FeedDetailTableCell(style: .default, reuseIdentifier: "related")
    let other = FeedDetailTableCell(style: .default, reuseIdentifier: "other")
    var reloadCount = 0

    override var indexPathsForVisibleRows: [IndexPath]? {
        (0..<3).map { IndexPath(row: $0, section: 0) }
    }

    override func cellForRow(at indexPath: IndexPath) -> UITableViewCell? {
        [parent, related, other][indexPath.row]
    }

    override func reloadData() { reloadCount += 1 }
    override func reloadRows(at indexPaths: [IndexPath], with animation: UITableView.RowAnimation) {
        reloadCount += 1
    }
}
