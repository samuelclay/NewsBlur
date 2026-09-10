// FeedIconRenderer.swift prepares the existing rounded cell artwork at its displayed size.
import UIKit

@objcMembers final class FeedIconRenderer: NSObject {
    private final class PreparedImage: NSObject {
        let image: UIImage
        let size: CGSize
        let scale: CGFloat

        init(image: UIImage, size: CGSize, scale: CGFloat) {
            self.image = image
            self.size = size
            self.scale = scale
        }
    }

    private final class LoadGeneration {
        var readers = 0
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

    func image(forKey key: String, size: CGSize, loader: () -> UIImage?) -> UIImage? {
        let scale = UIGraphicsImageRendererFormat.default().scale
        lock.lock()
        if let prepared = cache.object(forKey: key as NSString), prepared.size == size, prepared.scale == scale {
            lock.unlock()
            return prepared.image
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
        guard loads[key] === generation else { return nil }
        generation.readers -= 1
        if generation.readers == 0 {
            loads.removeValue(forKey: key)
        }

        if let image, let bitmap = image.cgImage {
            if let prepared = cache.object(forKey: key as NSString), prepared.size == size, prepared.scale == scale {
                return prepared.image
            }
            let cost = bitmap.bytesPerRow * bitmap.height + key.utf8.count
            if cost <= cache.totalCostLimit {
                cache.setObject(PreparedImage(image: image, size: size, scale: scale), forKey: key as NSString, cost: cost)
            }
        }
        return image
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
        lock.unlock()
    }
}
