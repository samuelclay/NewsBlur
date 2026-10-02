// StoryTextLayoutCache.swift prepares the existing native cell's exact text measurements.
import UIKit

@objcMembers final class StoryTextLayout: NSObject {
    let titleSize: CGSize
    let previewSize: CGSize
    let contentGap: CGFloat

    init(titleSize: CGSize, previewSize: CGSize, contentGap: CGFloat) {
        self.titleSize = titleSize
        self.previewSize = previewSize
        self.contentGap = contentGap
    }
}

@objcMembers final class StoryTextLayoutRequest: NSObject {
    private let title: NSString
    private let preview: NSString
    private let contentWidth: CGFloat
    private let boundsHeight: CGFloat
    private let titleFont: UIFont
    private let previewFont: UIFont
    private let textSize: Int
    private let shortTitles: Bool
    private let river: Bool
    private let comfortMargin: CGFloat
    private let riverPadding: CGFloat
    private let hasImage: Bool
    private let paragraphStyle: NSParagraphStyle
    private let requestHash: Int
    let byteCost: Int

    init(title: NSString, preview: NSString, contentWidth: CGFloat, boundsHeight: CGFloat,
         fontPointSize: CGFloat, textSize: Int, shortTitles: Bool, river: Bool,
         comfortMargin: CGFloat, riverPadding: CGFloat, hasImage: Bool, paragraphStyle: NSParagraphStyle) {
        // StoryTextLayoutCache.swift keeps NSString's exact UTF-16, including a preview cut at its 500-unit limit.
        self.title = title.copy() as! NSString
        self.preview = preview.copy() as! NSString
        self.contentWidth = contentWidth
        self.boundsHeight = boundsHeight
        titleFont = UIFont(name: "WhitneySSm-Medium", size: fontPointSize + 1)!
        previewFont = UIFont(name: "WhitneySSm-Book", size: fontPointSize - 1)!
        self.textSize = textSize
        self.shortTitles = shortTitles
        self.river = river
        self.comfortMargin = comfortMargin
        self.riverPadding = riverPadding
        self.hasImage = hasImage
        self.paragraphStyle = paragraphStyle.copy() as! NSParagraphStyle
        byteCost = (title.length + preview.length) * 2 + 1_024
        var hasher = Hasher()
        hasher.combine(title.hash)
        hasher.combine(preview.hash)
        hasher.combine(contentWidth)
        hasher.combine(boundsHeight)
        hasher.combine(fontPointSize)
        hasher.combine(textSize)
        hasher.combine(shortTitles)
        hasher.combine(river)
        hasher.combine(comfortMargin)
        hasher.combine(riverPadding)
        hasher.combine(hasImage)
        hasher.combine(paragraphStyle.hash)
        requestHash = hasher.finalize()
        super.init()
    }

    override var hash: Int { requestHash }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? StoryTextLayoutRequest else { return false }
        return title.isEqual(other.title) && preview.isEqual(other.preview)
            && contentWidth == other.contentWidth && boundsHeight == other.boundsHeight
            && titleFont.isEqual(other.titleFont) && previewFont.isEqual(other.previewFont)
            && textSize == other.textSize && shortTitles == other.shortTitles && river == other.river
            && comfortMargin == other.comfortMargin && riverPadding == other.riverPadding
            && hasImage == other.hasImage && paragraphStyle.isEqual(other.paragraphStyle)
    }

    @objc(contentWidthForBoundsWidth:imageStyle:hasImage:)
    class func contentWidth(boundsWidth: CGFloat, imageStyle: String, hasImage: Bool) -> CGFloat {
        let small = ["small", "small_left", "small_right"].contains(imageStyle)
        let left = ["small_left", "large_left"].contains(imageStyle)
        let imageWidth: CGFloat = small ? 60 : 80
        let margin: CGFloat = small ? 14 : 0
        var width = boundsWidth - 24 - 18 - margin
        if left || (imageStyle != "none" && hasImage) { width -= imageWidth }
        return width
    }

    func measure() -> StoryTextLayout {
        // StoryTextLayoutCache.swift preserves FeedDetailTableCell.m's bounding rectangles and drawing options.
        let options: NSStringDrawingOptions = [.truncatesLastVisibleLine, .usesLineFragmentOrigin]
        var titleRows: CGFloat = shortTitles ? 1.5 : 4
        if !shortTitles && (textSize == 2 || textSize == 3) {
            titleRows = min((boundsHeight - 24) / titleFont.pointSize - 2, 4)
        }
        let titleStarted = ReaderPerformance.start()
        let titleSize = title.boundingRect(
            with: CGSize(width: contentWidth, height: titleFont.pointSize * titleRows), options: options,
            attributes: [.font: titleFont, .paragraphStyle: paragraphStyle], context: nil).size
        if titleStarted > 0 { ReaderPerformance.finish("story.title.layout", since: titleStarted) }
        var previewSize = CGSize.zero
        var gap: CGFloat = 0
        if preview.length > 0 {
            var previewRows: CGFloat = shortTitles ? 1.5 : 3
            if !shortTitles && (textSize == 2 || textSize == 3) {
                let titleBottom = 14 + riverPadding + titleSize.height
                previewRows = max(3, (boundsHeight - 30 - comfortMargin - titleBottom) / previewFont.pointSize)
            }
            let previewStarted = ReaderPerformance.start()
            previewSize = preview.boundingRect(
                with: CGSize(width: contentWidth, height: previewFont.pointSize * previewRows), options: options,
                attributes: [.font: previewFont, .paragraphStyle: paragraphStyle], context: nil).size
            if previewStarted > 0 { ReaderPerformance.finish("story.preview.layout", since: previewStarted) }
            let dateY = boundsHeight - 18 - comfortMargin
            let topEdge = river ? riverPadding : 0
            gap = max((dateY - topEdge - titleSize.height - previewSize.height) / 3, 2)
        }
        return StoryTextLayout(titleSize: titleSize, previewSize: previewSize, contentGap: gap)
    }
}

@objcMembers final class StoryTextLayoutCache: NSObject {
    private struct Entry {
        let layout: StoryTextLayout
        var lastUse: UInt64
    }
    private final class Work {
        let identifier: String
        let requests: [StoryTextLayoutRequest]
        let cost: Int
        var cancelled = false
        init(identifier: String, requests: [StoryTextLayoutRequest]) {
            self.identifier = identifier
            self.requests = requests
            cost = requests.reduce(0) { $0 + $1.byteCost }
        }
    }

    private let lock = NSLock()
    private let worker: DispatchQueue
    private var entries = [StoryTextLayoutRequest: Entry]()
    private var entryCost = 0
    private var clock: UInt64 = 0
    private var pending = [String: Work]()
    private var order = [String]()
    private var active: Work?
    private var draining = false
    private var memoryObserver: NSObjectProtocol?
    private let countLimit = 256
    private let costLimit = 4 * 1_024 * 1_024
    private let pendingLimit = 24

    override convenience init() {
        self.init(worker: DispatchQueue(label: "com.newsblur.story-text-layout", qos: .userInitiated))
    }

    @nonobjc init(worker: DispatchQueue) {
        self.worker = worker
        super.init()
        memoryObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil
        ) { [weak self] _ in self?.removeAllLayouts() }
    }

    deinit {
        if let memoryObserver { NotificationCenter.default.removeObserver(memoryObserver) }
    }

    @objc(cachedLayoutForRequest:)
    func cachedLayout(for request: StoryTextLayoutRequest) -> StoryTextLayout? {
        locked {
            guard var entry = entries[request] else { return nil }
            clock &+= 1
            entry.lastUse = clock
            entries[request] = entry
            return entry.layout
        }
    }

    @objc(cacheLayout:forRequest:)
    func cacheLayout(_ layout: StoryTextLayout, for request: StoryTextLayoutRequest) {
        locked { store(layout, for: request) }
    }

    func prefetch(_ requests: [StoryTextLayoutRequest], identifier: String) {
        let shouldStart: Bool = locked {
            let missing = Array(requests.prefix(2)).filter { entries[$0] == nil }
            guard !missing.isEmpty else { return false }
            if let work = pending[identifier], work.requests == missing { return false }
            if let active, !active.cancelled, active.identifier == identifier, active.requests == missing { return false }
            let work = Work(identifier: identifier, requests: missing)
            guard work.cost <= costLimit else { return false }
            removePending(identifier)
            if active?.identifier == identifier { active?.cancelled = true }
            while !order.isEmpty && (pending.count + (active == nil ? 0 : 1) >= pendingLimit
                                    || pendingCost + work.cost > costLimit) {
                removePending(order[0])
            }
            guard pending.count + (active == nil ? 0 : 1) < pendingLimit,
                  pendingCost + work.cost <= costLimit else { return false }
            pending[identifier] = work
            order.append(identifier)
            guard !draining else { return false }
            draining = true
            return true
        }
        if shouldStart {
            // StoryTextLayoutCache.swift queues one drain, so cancelled jobs do not retain captured strings in blocks.
            worker.async { [weak self] in self?.drain() }
        }
    }

    func cancelPrefetch(_ identifiers: [String]) {
        locked {
            for identifier in identifiers {
                removePending(identifier)
                if active?.identifier == identifier { active?.cancelled = true }
            }
        }
    }

    func removeAllLayouts() {
        locked {
            entries.removeAll()
            entryCost = 0
            pending.removeAll()
            order.removeAll()
            active?.cancelled = true
        }
    }

    @nonobjc var cachedEntryCount: Int { locked { entries.count } }
    @nonobjc var cachedByteCost: Int { locked { entryCost } }
    @nonobjc var pendingRowCount: Int { locked { pending.count + (active == nil ? 0 : 1) } }
    @nonobjc var pendingByteCost: Int { locked { pendingCost } }

    private var pendingCost: Int { pending.values.reduce(active?.cost ?? 0) { $0 + $1.cost } }

    private func removePending(_ identifier: String) {
        pending.removeValue(forKey: identifier)
        order.removeAll { $0 == identifier }
    }

    private func drain() {
        while let work: Work = locked({
            guard let identifier = order.first, let work = pending[identifier] else {
                draining = false
                return nil
            }
            removePending(identifier)
            active = work
            return work
        }) {
            autoreleasepool {
                for request in work.requests {
                    guard locked({ !work.cancelled && entries[request] == nil }) else { continue }
                    // StoryTextLayoutCache.swift never holds its lock while Core Text measures or opens fallback fonts.
                    let layout = request.measure()
                    locked {
                        if !work.cancelled { store(layout, for: request) }
                    }
                }
            }
            locked { active = nil }
        }
    }

    private func store(_ layout: StoryTextLayout, for request: StoryTextLayoutRequest) {
        guard request.byteCost <= costLimit else { return }
        if entries.removeValue(forKey: request) != nil { entryCost -= request.byteCost }
        while !entries.isEmpty && (entries.count >= countLimit || entryCost + request.byteCost > costLimit) {
            guard let oldest = entries.min(by: { $0.value.lastUse < $1.value.lastUse })?.key else { break }
            entries.removeValue(forKey: oldest)
            entryCost -= oldest.byteCost
        }
        clock &+= 1
        entries[request] = Entry(layout: layout, lastUse: clock)
        entryCost += request.byteCost
    }

    @nonobjc private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
