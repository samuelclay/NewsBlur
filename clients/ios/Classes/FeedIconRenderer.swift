// FeedIconRenderer.swift prepares the existing rounded cell artwork at its displayed size.
import UIKit

@objcMembers final class FeedIconPreparationRequest: NSObject {
    let key: String
    let size: CGSize

    init(key: String, size: CGSize) {
        self.key = key
        self.size = size
    }
}

@objcMembers final class FeedIconRenderer: NSObject {
    private final class PreparedImage: NSObject {
        let image: UIImage
        let size: CGSize
        let scale: CGFloat
        let cost: Int

        init(image: UIImage, size: CGSize, scale: CGFloat, cost: Int) {
            self.image = image
            self.size = size
            self.scale = scale
            self.cost = cost
        }
    }

    private final class PreparationGeneration: NSObject {}

    private final class Preparation {
        let requests: [FeedIconPreparationRequest]
        let loader: (String) -> UIImage?
        let generation = PreparationGeneration()
        let maximumRequestCount: Int
        var next = 0
        var remainingCost: Int

        init(requests: [FeedIconPreparationRequest], maximumRequestCount: Int, cost: Int, loader: @escaping (String) -> UIImage?) {
            self.requests = requests
            self.maximumRequestCount = maximumRequestCount
            self.loader = loader
            remainingCost = cost
        }

        func matches(_ requests: [FeedIconPreparationRequest], maximumRequestCount: Int) -> Bool {
            self.maximumRequestCount == maximumRequestCount && self.requests.count == requests.count &&
                zip(self.requests, requests).allSatisfy { $0.0.key == $0.1.key && $0.0.size == $0.1.size }
        }
    }

    private final class LoadGeneration {
        var readers = 0
    }

    private struct PreparationWork {
        let request: FeedIconPreparationRequest
        let generation: PreparationGeneration
        let loader: (String) -> UIImage?
        let remainingCost: Int
    }

    private let cache: NSCache<NSString, PreparedImage> = {
        let cache = NSCache<NSString, PreparedImage>()
        cache.name = "FeedIconRenderer.preparedImages"
        cache.countLimit = 1024
        cache.totalCostLimit = 8 * 1024 * 1024
        return cache
    }()
    private let lock = NSLock()
    private var loads: [String: LoadGeneration] = [:]
    private let preparationQueue: DispatchQueue
    private let preparationByteLimit: Int
    private var preparation: Preparation?
    private var preparationRunning = false
    private var activePreparation = false
    private var memoryObserver: NSObjectProtocol?

    override convenience init() {
        self.init(preparationQueue: DispatchQueue(label: "com.newsblur.feed-icon-preparation", qos: .utility))
    }

    @nonobjc init(preparationQueue: DispatchQueue, preparationByteLimit: Int = 8 * 1024 * 1024) {
        self.preparationQueue = preparationQueue
        self.preparationByteLimit = min(preparationByteLimit, 8 * 1024 * 1024)
        super.init()
        memoryObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil
        ) { [weak self] _ in self?.removeAllImages() }
    }

    deinit {
        if let memoryObserver { NotificationCenter.default.removeObserver(memoryObserver) }
    }

    func image(forKey key: String, size: CGSize, loader: () -> UIImage?) -> UIImage? {
        image(forKey: key, size: size, maximumCost: Int.max, preparationGeneration: nil, loader: loader).image
    }

    @nonobjc private func image(forKey key: String, size: CGSize, maximumCost: Int,
                                preparationGeneration: PreparationGeneration?, loader: () -> UIImage?) -> (image: UIImage?, cost: Int) {
        let scale = UIGraphicsImageRendererFormat.default().scale
        lock.lock()
        if let preparationGeneration, preparation?.generation !== preparationGeneration {
            lock.unlock()
            return (nil, 0)
        }
        if let prepared = cache.object(forKey: key as NSString), prepared.size == size, prepared.scale == scale {
            lock.unlock()
            return (prepared.cost <= maximumCost ? prepared.image : nil, prepared.cost)
        }
        let generation = loads[key] ?? LoadGeneration()
        generation.readers += 1
        loads[key] = generation
        lock.unlock()

        // FeedIconRenderer.swift releases originals after drawing and never holds its lock during disk access.
        let image: UIImage? = autoreleasepool {
            guard let source = loader() else { return nil }
            return Utilities.roundCorneredImage(source, radius: 4, convertTo: size)
        }

        lock.lock()
        defer { lock.unlock() }
        // FeedIconRenderer.swift discards results invalidated while their loader or drawing was in progress.
        guard loads[key] === generation else { return (nil, 0) }
        generation.readers -= 1
        if generation.readers == 0 {
            loads.removeValue(forKey: key)
        }
        if let preparationGeneration, preparation?.generation !== preparationGeneration { return (nil, 0) }

        if let image, let bitmap = image.cgImage {
            if let prepared = cache.object(forKey: key as NSString), prepared.size == size, prepared.scale == scale {
                return (prepared.cost <= maximumCost ? prepared.image : nil, prepared.cost)
            }
            let cost = bitmap.bytesPerRow * bitmap.height + key.utf8.count
            // FeedIconRenderer.swift admits a warm bitmap before insertion so the batch cannot evict its early rows.
            guard cost <= maximumCost else { return (nil, cost) }
            if cost <= cache.totalCostLimit {
                cache.setObject(PreparedImage(image: image, size: size, scale: scale, cost: cost), forKey: key as NSString, cost: cost)
            }
            return (image, cost)
        }
        return (image, 0)
    }

    func prepare(_ requests: [FeedIconPreparationRequest], loader: @escaping (String) -> UIImage?) {
        _ = prepare(requests, maximumRequestCount: 1024, loader: loader)
    }

    func prepare(_ requests: [FeedIconPreparationRequest], maximumRequestCount: Int,
                 loader: @escaping (String) -> UIImage?) -> NSObject? {
        lock.lock()
        var seen = Set<String>()
        let maximumRequestCount = min(max(maximumRequestCount, 0), 1024)
        var bounded = [FeedIconPreparationRequest]()
        for request in requests {
            if bounded.count == maximumRequestCount { break }
            if request.size.width > 0 && request.size.height > 0 && seen.insert(request.key).inserted {
                bounded.append(request)
            }
        }
        // FeedIconRenderer.swift keeps identical work before reserving an active slot for a replacement batch.
        if let preparation, preparation.matches(bounded, maximumRequestCount: maximumRequestCount) {
            lock.unlock()
            return preparation.generation
        }
        if activePreparation && bounded.count == maximumRequestCount && !bounded.isEmpty {
            bounded.removeLast()
        }
        if let preparation, preparation.matches(bounded, maximumRequestCount: maximumRequestCount) {
            lock.unlock()
            return preparation.generation
        }
        preparation = bounded.isEmpty ? nil : Preparation(requests: bounded, maximumRequestCount: maximumRequestCount,
                                                          cost: preparationByteLimit, loader: loader)
        let token = preparation?.generation
        let shouldStart = preparation != nil && !preparationRunning
        if shouldStart { preparationRunning = true }
        lock.unlock()
        if shouldStart {
            // FeedIconRenderer.swift queues one drain and retains identifiers, never a subscription set of originals.
            preparationQueue.async { [weak self] in self?.drainPreparation() }
        }
        return token
    }

    func cancelPreparation() {
        lock.lock()
        preparation = nil
        lock.unlock()
    }

    func cancelPreparation(_ token: NSObject) {
        lock.lock()
        if preparation?.generation === token { preparation = nil }
        lock.unlock()
    }

    @nonobjc var pendingPreparationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return (preparation.map { $0.requests.count - $0.next } ?? 0) + (activePreparation ? 1 : 0)
    }

    @nonobjc private func nextPreparationWork() -> PreparationWork? {
        lock.lock()
        defer { lock.unlock() }
        guard let current = preparation, current.next < current.requests.count else {
            preparation = nil
            preparationRunning = false
            return nil
        }
        let work = PreparationWork(request: current.requests[current.next], generation: current.generation,
                                   loader: current.loader, remainingCost: current.remainingCost)
        current.next += 1
        activePreparation = true
        return work
    }

    @nonobjc private func drainPreparation() {
        while let work = nextPreparationWork() {
            let cost = autoreleasepool {
                image(forKey: work.request.key, size: work.request.size, maximumCost: work.remainingCost,
                      preparationGeneration: work.generation) { work.loader(work.request.key) }.cost
            }
            lock.lock()
            activePreparation = false
            if preparation?.generation === work.generation {
                if cost > work.remainingCost { preparation = nil }
                else { preparation?.remainingCost -= cost }
            }
            lock.unlock()
        }
    }

    func removeImage(forKey key: String) {
        lock.lock()
        cache.removeObject(forKey: key as NSString)
        loads.removeValue(forKey: key)
        lock.unlock()
    }

    func removeAllImages() {
        lock.lock()
        cache.removeAllObjects()
        loads.removeAll()
        preparation = nil
        lock.unlock()
    }
}
