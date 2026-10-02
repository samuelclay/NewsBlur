import Foundation

@objc final class StoryDetailAssetCache: NSObject {
    @objc static let shared = StoryDetailAssetCache()

    private let lock = NSLock()
    private let resources = NSCache<NSString, CachedText>()

    override init() {
        super.init()
        resources.countLimit = 16
    }

    @objc(textForResource:ofType:)
    func text(forResource name: String, ofType fileExtension: String) -> String? {
        cachedText(forKey: "\(name).\(fileExtension)") {
            readResource(name, extension: fileExtension)
        }
    }

    @objc(embeddedMainCSSWithLoader:)
    func embeddedMainCSS(loader: (String?) -> String?) -> String? {
        // StoryDetailObjCViewController.m retains its existing font/image embedding and dynamic HTML assembly.
        cachedText(forKey: "embedded:storyDetailView.css") {
            loader(readResource("storyDetailView", extension: "css"))
        }
    }

    private func cachedText(forKey key: String, load: () -> String?) -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = resources.object(forKey: key as NSString) {
            return cached.text
        }
        let cached = CachedText(load())
        resources.setObject(cached, forKey: key as NSString)
        return cached.text
    }

    private func readResource(_ name: String, extension fileExtension: String) -> String? {
        guard let path = Bundle.main.path(forResource: name, ofType: fileExtension) else {
            return ""
        }
        return try? String(contentsOfFile: path, encoding: .utf8)
    }

    private final class CachedText: NSObject {
        let text: String?

        init(_ text: String?) {
            self.text = text
        }
    }
}
