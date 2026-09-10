// FeedIconRenderer.swift prepares the existing rounded cell artwork at its displayed size.
import UIKit

@objcMembers final class FeedIconRenderer: NSObject {
    func image(forKey key: String, size: CGSize, loader: () -> UIImage?) -> UIImage? {
        guard let source = loader() else { return nil }
        return Utilities.roundCorneredImage(source, radius: 4, convertTo: size)
    }

    func removeImage(forKey key: String) {}
    func removeAllImages() {}
}
