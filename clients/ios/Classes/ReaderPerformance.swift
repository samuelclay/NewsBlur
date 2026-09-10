// ReaderPerformance.swift records opt-in simulator measurements without story content.
import UIKit
import WebKit
import ObjectiveC.runtime

@objcMembers
final class ReaderPerformance: NSObject {
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
        guard ProcessInfo.processInfo.environment["NB_SCROLL_PERFORMANCE"] == "1", recorder == nil else { return }
        let instance = ReaderPerformance()
        recorder = instance
        FileManager.default.createFile(atPath: instance.output.path, contents: nil)
        instance.installProbes()
        let link = CADisplayLink(target: instance, selector: #selector(instance.tick(_:)))
        link.add(to: .main, forMode: .common)
        instance.displayLink = link
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
        wrapVoid(FeedDetailObjCViewController.self, name: "reloadTable", metric: "reload.stories")
        wrapVoid(FeedDetailObjCViewController.self, name: "checkScroll", metric: "scroll.mark_read")
        wrapVoid(StoryDetailObjCViewController.self, name: "refreshHeader", metric: "detail.header")
        wrapVoid(StoryDetailObjCViewController.self, name: "updateFeedTitleGradientPosition", metric: "detail.gradient")
        for (name, metric) in [("FeedTableCellView", "draw.feed"), ("FeedDetailTableCell", "draw.story"),
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
