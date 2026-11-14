// StoryThumbnailPrefetcher.swift warms only the latest nearby disk images before native rows become visible.
import UIKit
import ObjectiveC

@objc final class StoryThumbnailPrefetcher: NSObject {
    private let worker: DispatchQueue
    private let loader: (String, Operation) -> Void
    private let lock = NSLock()
    private var pendingHashes = [String]()
    private var pendingTraits = UITraitCollection()
    private var active: (hash: String, operation: BlockOperation, traits: UITraitCollection)?
    private var draining = false
    private var memoryWarningObserver: NSObjectProtocol?
    private static var displayTraitsKey: UInt8 = 0

    @objc static func preparedImageForDisplay(_ image: UIImage) -> UIImage {
        // StoryThumbnailPrefetcher.swift keeps animated and symbol representations unchanged; UIKit also gives ordinary disk bitmaps an anonymous UIImageAsset.
        guard !Thread.isMainThread, image.images == nil, !image.isSymbolImage,
              let bitmap = image.cgImage, bitmap.height > 0,
              bitmap.bytesPerRow <= (20 * 1_024 * 1_024) / bitmap.height else { return image }
        guard let prepared = image.preparingForDisplay(), prepared !== image,
              prepared.size == image.size, prepared.scale == image.scale,
              prepared.imageOrientation == image.imageOrientation,
              prepared.renderingMode == image.renderingMode,
              prepared.capInsets == image.capInsets, prepared.resizingMode == image.resizingMode,
              prepared.alignmentRectInsets == image.alignmentRectInsets,
              let preparedBitmap = prepared.cgImage,
              preparedBitmap.width == bitmap.width, preparedBitmap.height == bitmap.height else { return image }
        // StoryThumbnailPrefetcher.swift retains the display traits only with the prepared memory object; the original disk image stays screen-independent.
        objc_setAssociatedObject(prepared, &displayTraitsKey, UITraitCollection.current, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return prepared
    }

    @objc static func imageMatchesCurrentDisplay(_ image: UIImage) -> Bool {
        guard let traits = objc_getAssociatedObject(image, &displayTraitsKey) as? UITraitCollection else { return true }
        return sameDisplay(traits, UITraitCollection.current)
    }

    private static func sameDisplay(_ lhs: UITraitCollection, _ rhs: UITraitCollection) -> Bool {
        lhs.displayScale == rhs.displayScale && lhs.displayGamut == rhs.displayGamut &&
            !lhs.hasDifferentColorAppearance(comparedTo: rhs)
    }

    @objc convenience init(appDelegate: NewsBlurAppDelegate) {
        self.init(worker: DispatchQueue(label: "com.newsblur.thumbnail-prefetch", qos: .userInitiated)) {
            [weak appDelegate] hash, operation in
            appDelegate?.prefetchCachedStoryImage(forStoryHash: hash, operation: operation)
        }
    }

    init(worker: DispatchQueue, loader: @escaping (String, Operation) -> Void) {
        self.worker = worker
        self.loader = loader
        super.init()
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil
        ) { [weak self] _ in
            self?.cancelAll()
        }
    }

    deinit {
        if let memoryWarningObserver { NotificationCenter.default.removeObserver(memoryWarningObserver) }
    }

    @objc func prefetchStoryHashes(_ hashes: [String]) {
        let traits = UITraitCollection.current
        var nearby = [String]()
        var unique = Set<String>()
        for hash in hashes {
            guard !hash.isEmpty, hash.utf8.count <= 1_024, unique.insert(hash).inserted else { continue }
            nearby.append(hash)
            if nearby.count == 24 { break }
        }

        lock.lock()
        if let active, !unique.contains(active.hash) || !Self.sameDisplay(active.traits, traits) {
            active.operation.cancel()
        }
        pendingHashes = nearby.filter { $0 != active?.hash || active?.operation.isCancelled == true }
        pendingTraits = traits
        let startWorker = !draining && !pendingHashes.isEmpty
        if startWorker { draining = true }
        lock.unlock()
        if startWorker {
            worker.async { [weak self] in self?.drain() }
        }
    }

    @objc func cancelAll() {
        prefetchStoryHashes([])
    }

    var pendingHashCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return pendingHashes.count + (active == nil ? 0 : 1)
    }

    private func drain() {
        while true {
            lock.lock()
            guard !pendingHashes.isEmpty else {
                active = nil
                draining = false
                lock.unlock()
                return
            }
            let hash = pendingHashes.removeFirst()
            let operation = BlockOperation()
            let traits = pendingTraits
            active = (hash, operation, traits)
            lock.unlock()

            // StoryThumbnailPrefetcher.swift queues one worker; replacing its bounded hash list releases abandoned rows immediately.
            autoreleasepool {
                operation.addExecutionBlock { [weak operation] in
                    guard let operation, !operation.isCancelled else { return }
                    traits.performAsCurrent { self.loader(hash, operation) }
                }
                operation.start()
            }
            lock.lock()
            active = nil
            lock.unlock()
        }
    }
}
