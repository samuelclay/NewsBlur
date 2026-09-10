// StoryThumbnailPrefetcher.swift warms only the latest nearby disk images before native rows become visible.
import UIKit

@objc final class StoryThumbnailPrefetcher: NSObject {
    private let worker: DispatchQueue
    private let loader: (String, Operation) -> Void
    private let lock = NSLock()
    private var pendingHashes = [String]()
    private var active: (hash: String, operation: BlockOperation)?
    private var draining = false
    private var memoryWarningObserver: NSObjectProtocol?

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
        var nearby = [String]()
        var unique = Set<String>()
        for hash in hashes {
            guard !hash.isEmpty, hash.utf8.count <= 1_024, unique.insert(hash).inserted else { continue }
            nearby.append(hash)
            if nearby.count == 24 { break }
        }

        lock.lock()
        if let active, !unique.contains(active.hash) { active.operation.cancel() }
        pendingHashes = nearby.filter { $0 != active?.hash || active?.operation.isCancelled == true }
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
            active = (hash, operation)
            lock.unlock()

            // StoryThumbnailPrefetcher.swift queues one worker; replacing its bounded hash list releases abandoned rows immediately.
            autoreleasepool {
                operation.addExecutionBlock { [weak operation] in
                    guard let operation, !operation.isCancelled else { return }
                    self.loader(hash, operation)
                }
                operation.start()
            }
            lock.lock()
            active = nil
            lock.unlock()
        }
    }
}
