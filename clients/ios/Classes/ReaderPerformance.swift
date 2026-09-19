// ReaderPerformance.swift records opt-in simulator measurements without story content.
import UIKit
import WebKit
import ObjectiveC.runtime

@objcMembers
final class ReaderPerformance: NSObject {
    // ReaderPerformance.swift records presentation gates only for the isolated UI fixture process.
    static let recordsUITestPresentation = ProcessInfo.processInfo.arguments.contains("-newsblur-ui-testing") || recordsStorySelection

    private static var recordsStorySelection: Bool {
#if targetEnvironment(simulator)
        ProcessInfo.processInfo.arguments.contains("-newsblur-story-selection-trace")
#else
        false
#endif
    }
    private static var storySelectionObservation: NSKeyValueObservation?

    private static var recorder: ReaderPerformance?
    private var displayLink: CADisplayLink?
    private var events = [[String: Any]]()
    private let writer = DispatchQueue(label: "com.newsblur.scroll-performance", qos: .utility)
    private let epoch = Date().timeIntervalSince1970 - CACurrentMediaTime()
    private var lastFlush = CACurrentMediaTime()
    private var lastFrame: (surface: String, time: Double)?
    private let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("scroll-performance.jsonl")

    static func install() {
        installStorySelectionTraceIfRequested()
        guard ProcessInfo.processInfo.environment["NB_SCROLL_PERFORMANCE"] == "1", recorder == nil else { return }
        let instance = ReaderPerformance()
        recorder = instance
        FileManager.default.createFile(atPath: instance.output.path, contents: nil)
        instance.installProbes()
        let link = CADisplayLink(target: instance, selector: #selector(instance.tick(_:)))
        link.add(to: .main, forMode: .common)
        instance.displayLink = link
        instance.events.append(["metric": "launch.probes_ready", "ms": 0,
                                "at": instance.epoch + CACurrentMediaTime()])
    }

    private static func installStorySelectionTraceIfRequested() {
#if targetEnvironment(simulator)
        guard recordsStorySelection, storySelectionObservation == nil,
              let app = NewsBlurAppDelegate.shared else { return }
        // ReaderPerformance.swift observes the real setter without replacing it or installing account fixtures.
        storySelectionObservation = app.observe(\.activeStory, options: [.old, .new]) { app, change in
            let oldHash = (change.oldValue ?? nil)?["story_hash"] as? String
            let newHash = (change.newValue ?? nil)?["story_hash"] as? String
            guard oldHash != newHash else { return }
            let stack = Thread.callStackSymbols.prefix(20).joined(separator: "\n")
            guard Thread.isMainThread else {
                NSLog("[ReaderSelection] background hash=%@ -> %@\n%@", oldHash ?? "nil", newHash ?? "nil", stack)
                return
            }
            let pages = app.storyPagesViewController
            let page = pages?.currentPage
            let pager = pages?.scrollView
            NSLog("[ReaderSelection] hash=%@ -> %@ current=%@ index=%ld next=%@/%ld previous=%@/%ld pager=%@ offset=%@ insets=%@ dragging=%d target=%ld fetch=%lu\n%@",
                  oldHash ?? "nil", newHash ?? "nil", page?.activeStoryId ?? "nil", page?.pageIndex ?? -2,
                  pages?.nextPage?.activeStoryId ?? "nil", pages?.nextPage?.pageIndex ?? -2,
                  pages?.previousPage?.activeStoryId ?? "nil", pages?.previousPage?.pageIndex ?? -2,
                  NSCoder.string(for: pager?.bounds ?? .zero), NSCoder.string(for: pager?.contentOffset ?? .zero),
                  NSCoder.string(for: pager?.adjustedContentInset ?? .zero), pages?.isDraggingScrollview ?? false,
                  pages?.scrollingToPage ?? -2, app.feedDetailViewController?.fetchRequestId ?? 0, stack)
        }
        NSLog("[ReaderSelection] opt-in hash assignment trace installed")
#endif
    }

    static func start() -> Double {
        recorder == nil ? 0 : CACurrentMediaTime()
    }

    static func finish(_ metric: String, since start: Double) {
        guard start > 0, let recorder, Thread.isMainThread else { return }
        let end = CACurrentMediaTime()
        recorder.events.append(["metric": metric, "ms": (end - start) * 1000, "at": recorder.epoch + end])
    }

    private func installProbes() {
        // ReaderPerformance.swift exchanges only the instrumented process's IMPs.
        // Production launches leave the original dispatch and timing untouched.
        wrapCell(FeedsObjCViewController.self, metric: "cell.feed")
        wrapCell(FeedDetailObjCViewController.self, metric: "cell.story")
        wrapHeight(FeedDetailObjCViewController.self, metric: "height.story")
        wrapVoid(NewsBlurAppDelegate.self, name: "prepareViewControllers", metric: "launch.prepare_views")
        wrapVoid(FeedsObjCViewController.self, name: "reloadFeedTitlesTable", metric: "reload.feeds")
        wrapVoid(FeedDetailObjCViewController.self, name: "reloadTable", metric: "reload.stories")
        wrapObject(FeedDetailObjCViewController.self, name: "renderStories:", metric: "render.stories")
        wrapVoid(StoryDetailObjCViewController.self, name: "drawStory", metric: "detail.prepare")
        wrapVoid(StoryDetailObjCViewController.self, name: "loadStory", metric: "detail.submit")
        wrapVoid(StoryDetailObjCViewController.self, name: "webViewNotifyLoaded", metric: "detail.dom_ready")
        wrapVoid(FeedDetailObjCViewController.self, name: "checkScroll", metric: "scroll.mark_read")
        wrapVoid(StoryDetailObjCViewController.self, name: "refreshHeader", metric: "detail.header")
        wrapVoid(StoryDetailObjCViewController.self, name: "updateFeedTitleGradientPosition", metric: "detail.gradient")
        for (name, metric) in [("FeedTableCellView", "draw.feed"), ("FeedDetailTableCell", "draw.story"),
                               ("FeedDetailTableCellView", "draw.story.content"),
                               ("FolderTitleView", "draw.folder")] {
            if let type = NSClassFromString(name) { wrapDraw(type, metric: metric) }
        }
    }

    private func wrapCell(_ type: AnyClass, metric: String) {
        let selector = NSSelectorFromString("tableView:cellForRowAtIndexPath:")
        guard let method = class_getInstanceMethod(type, selector) else { return }
        typealias Original = @convention(c) (AnyObject, Selector, UITableView, NSIndexPath) -> UITableViewCell
        let original = unsafeBitCast(method_getImplementation(method), to: Original.self)
        let block: @convention(block) (AnyObject, UITableView, NSIndexPath) -> UITableViewCell = { object, table, path in
            let start = Self.start()
            let cell = original(object, selector, table, path)
            Self.finish(metric, since: start)
            return cell
        }
        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private func wrapHeight(_ type: AnyClass, metric: String) {
        let selector = NSSelectorFromString("tableView:heightForRowAtIndexPath:")
        guard let method = class_getInstanceMethod(type, selector) else { return }
        typealias Original = @convention(c) (AnyObject, Selector, UITableView, NSIndexPath) -> CGFloat
        let original = unsafeBitCast(method_getImplementation(method), to: Original.self)
        let block: @convention(block) (AnyObject, UITableView, NSIndexPath) -> CGFloat = { object, table, path in
            let start = Self.start()
            let height = original(object, selector, table, path)
            Self.finish(metric, since: start)
            return height
        }
        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private func wrapVoid(_ type: AnyClass, name: String, metric: String) {
        let selector = NSSelectorFromString(name)
        guard let method = class_getInstanceMethod(type, selector) else { return }
        typealias Original = @convention(c) (AnyObject, Selector) -> Void
        let original = unsafeBitCast(method_getImplementation(method), to: Original.self)
        let block: @convention(block) (AnyObject) -> Void = { object in
            let start = Self.start()
            original(object, selector)
            Self.finish(metric, since: start)
        }
        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private func wrapObject(_ type: AnyClass, name: String, metric: String) {
        let selector = NSSelectorFromString(name)
        guard let method = class_getInstanceMethod(type, selector) else { return }
        typealias Original = @convention(c) (AnyObject, Selector, AnyObject?) -> Void
        let original = unsafeBitCast(method_getImplementation(method), to: Original.self)
        let block: @convention(block) (AnyObject, AnyObject?) -> Void = { object, argument in
            let start = Self.start()
            original(object, selector, argument)
            Self.finish(metric, since: start)
        }
        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    private func wrapDraw(_ type: AnyClass, metric: String) {
        let selector = NSSelectorFromString("drawRect:")
        guard let method = class_getInstanceMethod(type, selector) else { return }
        typealias Original = @convention(c) (AnyObject, Selector, CGRect) -> Void
        let original = unsafeBitCast(method_getImplementation(method), to: Original.self)
        let block: @convention(block) (AnyObject, CGRect) -> Void = { object, rect in
            let start = Self.start()
            original(object, selector, rect)
            Self.finish(metric, since: start)
        }
        method_setImplementation(method, imp_implementationWithBlock(block))
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        if let app = NewsBlurAppDelegate.shared {
            let surfaces: [(String, UIScrollView?)] = [
                ("feeds", app.feedsViewController?.feedTitlesTable),
                ("titles", app.feedDetailViewController?.storyTitlesTable),
                ("detail", app.storyPagesViewController?.currentPage?.webView?.scrollView)
            ]
            if let surface = surfaces.first(where: { _, scroll in
                guard let scroll else { return false }
                return scroll.window != nil && (scroll.isDragging || scroll.isDecelerating || scroll.isTracking)
            })?.0 {
                if let previous = lastFrame, previous.surface == surface {
                    events.append(["metric": "frame.\(surface)", "ms": (now - previous.time) * 1000,
                                   "budget_ms": (link.targetTimestamp - link.timestamp) * 1000, "at": epoch + now])
                }
                lastFrame = (surface, now)
            } else {
                lastFrame = nil
            }
        }
        if now - lastFlush > 1 {
            lastFlush = now
            // ReaderPerformance.swift records counts and geometry, proving cache depth and traversal without account content.
            if let stories = NewsBlurAppDelegate.shared?.storiesCollection {
                var state: [String: Any] = ["metric": "state.stories", "ms": 0, "at": epoch + now,
                                            "loaded_count": stories.activeFeedStories?.count ?? 0,
                                            "visible_count": stories.activeFeedStoryLocations?.count ?? 0]
                if let table = NewsBlurAppDelegate.shared?.feedDetailViewController?.storyTitlesTable {
                    state["offset_y"] = table.contentOffset.y
                    state["content_height"] = table.contentSize.height
                    state["viewport_height"] = table.bounds.height
                    state["top_inset"] = table.adjustedContentInset.top
                }
                events.append(state)
            }
            let batch = events
            events.removeAll(keepingCapacity: true)
            let destination = output
            writer.async {
                guard let handle = try? FileHandle(forWritingTo: destination) else { return }
                defer { try? handle.close() }
                do {
                    try handle.seekToEnd()
                    for event in batch {
                        let data = try JSONSerialization.data(withJSONObject: event, options: [.sortedKeys])
                        try handle.write(contentsOf: data)
                        try handle.write(contentsOf: Data([10]))
                    }
                } catch {
                    NSLog("ReaderPerformance.swift could not write measurements: %@", error.localizedDescription)
                }
            }
        }
    }
}
