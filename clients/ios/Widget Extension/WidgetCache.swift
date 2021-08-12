//
//  WidgetCache.swift
//  Widget Extension
//
//  Created by David Sinclair on 2021-08-07.
//  Copyright © 2021 NewsBlur. All rights reserved.
//

import WidgetKit
import UIKit

enum WidgetCacheError: String, Error {
    case notLoggedIn
    case loading
    case noFeeds
    case noStories
}

class WidgetCache {
    /// The base URL of the NewsBlur server.
    var host: String?
    
    /// The secret token for authentication.
    var token: String?
    
    /// An array of feeds to load.
    var feeds = [Feed]()
    
    /// Loaded stories.
    var stories = [Story]()
    
    /// An error to display instead of the stories, or `nil` if the stories should be displayed.
    var error: WidgetCacheError?
    
    typealias CacheCompletion = () -> Void
    
    private var cacheCompletion: CacheCompletion?
    
    private typealias AnyDictionary = [String : Any]
    
    private typealias ImageDictionary = [String : UIImage]
    
    private var feedImageCache = ImageDictionary()
    private var storyImageCache = ImageDictionary()
    
    private typealias LoaderDictionary = [String : Loader]
    
    private var loaders = LoaderDictionary()
    
    // Paragraph style for title and content labels.
//    lazy var paragraphStyle: NSParagraphStyle = {
//        let paragraph = NSMutableParagraphStyle()
//
//        paragraph.lineBreakMode = .byTruncatingTail
//        paragraph.alignment = .left
//        paragraph.lineHeightMultiple = 0.95
//
//        return paragraph
//    }()
    
    struct Constant {
        static let group = "group.com.newsblur.NewsBlur-Group"
        static let token = "share:token"
        static let host = "share:host"
        static let feeds = "widget:feeds_array"
        static let widgetFolder = "Widget"
        static let storiesFilename = "Stories.json"
        static let feedImagesFilename = "Feed Images"
        static let storyImagesFilename = "Story Images"
        static let imageExtension = "png"
        static let limit = 5
        static let defaultRowHeight: CGFloat = 110
        static let storyImageSize: CGFloat = 64 * 3
        static let storyImageLimit: CGFloat = 200
        static let thumbnailHiddenConstant: CGFloat = -50
        static let thumbnailShownConstant: CGFloat = 20
    }
    
    func load(completionHandler: @escaping CacheCompletion) {
        let feedIds = feeds.map { $0.id }
        let combinedFeeds = feedIds.joined(separator: "&f=")
        
        guard let url = hostURL(with: "/reader/river_stories/?include_hidden=false&page=1&infrequent=false&order=newest&read_filter=unread&limit=\(Constant.limit)&f=\(combinedFeeds)") else {
            error = .loading
            completionHandler()
            return
        }
        
        error = nil
        cacheCompletion = completionHandler
        loaders[Constant.storiesFilename] = Loader(url: url, completion: storyLoaderCompletion(result:))
    }
    
    func cleaned(_ string: String) -> String {
        let clean = string.prefix(1000).replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "<[^>]+>|&[^;]+;", with: " ", options: .regularExpression, range: nil)
            .trimmingCharacters(in: .whitespaces)
        
        return clean.isEmpty ? " " : clean
    }
    
//    func attributed(_ string: String, with font: UIFont, color: UIColor) -> NSAttributedString {
//        let attributes: [NSAttributedString.Key : Any] = [.font : font, .foregroundColor: color, .paragraphStyle: paragraphStyle]
//
//        return NSAttributedString(string: cleaned(string), attributes: attributes)
//    }
    
    func hostURL(with path: String) -> URL? {
        guard let host = host else {
            return nil
        }
        
        if let token = token {
            return URL(string: host + path + "&secret_token=\(token)")
        } else {
            return URL(string: host + path)
        }
    }
    
    func storyLoaderCompletion(result: Result<Data, Error>) {
        defer {
            cacheCompletion = nil
            loaders[Constant.storiesFilename] = nil
        }
        
        if case .failure = result {
            error = .loading
            cacheCompletion?()
            
            return
        }
        
        guard case .success(let data) = result else {
            return
        }
        
        guard let dictionary = try? JSONSerialization.jsonObject(with: data, options: []) as? AnyDictionary else {
            error = .loading
            cacheCompletion?()
            
            return
        }
        
        guard let storyArray = dictionary["stories"] as? [AnyDictionary] else {
            error = .loading
            cacheCompletion?()
            
            return
        }
        
        stories.removeAll()
        
        for storyDict in storyArray {
            stories.append(Story(from: storyDict))
        }
        
        saveStories()
        flushStoryImages()
        
        if stories.isEmpty, error == nil {
            error = .noStories
        }
        
        // Keep a local copy, since the property will be cleared before the async closure is called.
        let localCompletion = cacheCompletion
        
        DispatchQueue.main.async {
//            self.extensionContext?.widgetLargestAvailableDisplayMode = self.error == nil ? .expanded : .compact
//
//            self.tableView.reloadData()
//            self.tableView.setNeedsDisplay()
            
            localCompletion?()
        }
    }
    
    var groupContainerURL: URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constant.group)
    }
    
    var widgetFolderURL: URL? {
        return groupContainerURL?.appendingPathComponent(Constant.widgetFolder)
    }
    
    var storiesURL: URL? {
        return widgetFolderURL?.appendingPathComponent(Constant.storiesFilename)
    }
    
    var feedImagesURL: URL? {
        return widgetFolderURL?.appendingPathComponent(Constant.feedImagesFilename)
    }
    
    var storyImagesURL: URL? {
        return widgetFolderURL?.appendingPathComponent(Constant.storyImagesFilename)
    }
    
    func createWidgetFolder(url: URL? = nil) {
        guard let url = url ?? widgetFolderURL else {
            return
        }
        
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }
    
    func stories(count: Int) -> [Story] {
        return Array(stories.prefix(count))
    }
    
    func feed(for story: Story) -> Feed? {
        return feeds.first(where: { $0.id == story.feed })
    }
    
    func loadCachedStories() {
        feeds = []
        stories = []
        
        guard let defaults = UserDefaults.init(suiteName: Constant.group) else {
            return
        }
        
        host = defaults.string(forKey: Constant.host)
        token = defaults.string(forKey: Constant.token)
        
        if let array = defaults.array(forKey: Constant.feeds) as? [Feed.Dictionary] {
            feeds = array.map { Feed(from: $0) }
        }
        
        guard let url = storiesURL else {
            return
        }
        
        do {
            let json = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            
            decoder.dateDecodingStrategy = .iso8601
            
            stories = try decoder.decode([Story].self, from: json)
        } catch {
            print("Error \(error)")
        }
    }
    
    func saveStories() {
        guard let url = storiesURL else {
            return
        }
        
        createWidgetFolder()
        
        let encoder = JSONEncoder()
        
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let json = try encoder.encode(stories)
            
            try json.write(to: url)
        } catch {
            print("Error \(error)")
        }
    }
    
    func save(feedImage: UIImage, for identifier: String) {
        feedImageCache[identifier] = feedImage
        save(image: feedImage, to: feedImagesURL, for: identifier)
    }
    
    func save(storyImage: UIImage, for identifier: String) {
        storyImageCache[identifier] = storyImage
        save(image: storyImage, to: storyImagesURL, for: identifier)
    }
    
    func save(image: UIImage, to folderURL: URL?, for identifier: String) {
        guard let folderURL = folderURL else {
            return
        }
        
        createWidgetFolder(url: folderURL)
        
        do {
            let imageURL = folderURL.appendingPathComponent(identifier).appendingPathExtension(Constant.imageExtension)
            
            try image.pngData()?.write(to: imageURL)
        } catch {
            print("Image error: \(error)")
        }
    }
    
    func flushStoryImages() {
        guard let folderURL = storyImagesURL else {
            return
        }
        
        do {
            let manager = FileManager.default
            let contents = try manager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [], options: .skipsHiddenFiles)
            
            for imageURL in contents {
                let identifier = imageURL.deletingPathExtension().lastPathComponent
                
                if stories.contains(where: { $0.id == identifier }) {
                    continue
                }
                
                try manager.removeItem(at: imageURL)
                storyImageCache[identifier] = nil
            }
        } catch {
            print("Flush story images error: \(error)")
        }
    }
    
    typealias ImageCompletion = (UIImage?, String?) -> Void
    
    func feedImage(for feed: String, completion: @escaping ImageCompletion) {
        guard let url = hostURL(with: "/reader/favicons?feed_ids=\(feed)") else {
            completion(nil, feed)
            return
        }
        
        if let image = cachedFeedImage(for: feed) {
            completion(image, feed)
            return
        }
        
        loaders[feed] = Loader(url: url) { (result) in
            DispatchQueue.main.async {
                defer {
                    self.loaders[feed] = nil
                }
                
                switch result {
                case .success(let data):
                    guard let dictionary = try? JSONSerialization.jsonObject(with: data, options: []) as? AnyDictionary,
                          let base64 = dictionary[feed] as? String,
                          let imageData = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
                          let image = UIImage(data: imageData) else {
                        completion(nil, feed)
                        return
                    }
                    
                    self.save(feedImage: image, for: feed)
                    completion(image, feed)
                case .failure:
                    completion(nil, feed)
                }
            }
        }
    }
    
    func storyImage(for identifier: String, imageURL: URL?, completion: @escaping ImageCompletion) {
        guard let url = imageURL else {
            completion(nil, identifier)
            return
        }
        
        if let image = cachedStoryImage(for: identifier) {
            completion(image, identifier)
            return
        }
        
        loaders[identifier] = Loader(url: url) { (result) in
            DispatchQueue.main.async {
                defer {
                    self.loaders[identifier] = nil
                }
                
                switch result {
                case .success(let data):
                    guard let loadedImage = UIImage(data: data) else {
                        completion(nil, identifier)
                        return
                    }
                    
                    let size = loadedImage.size
                    
                    guard size.width >= 50, size.height >= 50 else {
                        completion(nil, identifier)
                        return
                    }
                    
                    let scaledImage = self.scale(image: loadedImage)
                    
                    self.save(storyImage: scaledImage, for: identifier)
                    completion(scaledImage, identifier)
                case .failure:
                    completion(nil, identifier)
                }
            }
        }
    }
    
    func cachedFeedImage(for feed: String) -> UIImage? {
        if let image = feedImageCache[feed] {
            return image
        }
        
        guard let image = loadCachedImage(folderURL: feedImagesURL, identifier: feed) else {
            return nil
        }
        
        feedImageCache[feed] = image
        
        return image
    }
    
    func cachedStoryImage(for identifier: String) -> UIImage? {
        if let image = storyImageCache[identifier] {
            return image
        }
        
        guard let image = loadCachedImage(folderURL: storyImagesURL, identifier: identifier) else {
            return nil
        }
        
        storyImageCache[identifier] = image
        
        return image
    }
    
    func loadCachedImage(folderURL: URL?, identifier: String) -> UIImage? {
        guard let folderURL = folderURL else {
            return nil
        }
        
        do {
            let imageURL = folderURL.appendingPathComponent(identifier).appendingPathExtension(Constant.imageExtension)
            let data = try Data(contentsOf: imageURL)
            
            guard let image = UIImage(data: data) else {
                return nil
            }
            
            return image
        } catch {
            print("Image error: \(error)")
        }
        
        return nil
    }
    
    func scale(image: UIImage) -> UIImage {
        let oldSize = image.size
        
        guard oldSize.width > Constant.storyImageLimit || oldSize.height > Constant.storyImageLimit else {
            return image
        }
        
        let scale: CGFloat
        
        if oldSize.width < oldSize.height {
            scale = Constant.storyImageSize / oldSize.width
        } else {
            scale = Constant.storyImageSize / oldSize.height
        }
        
        let newSize = CGSize(width: oldSize.width * scale, height: oldSize.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1)
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        
        defer {
            UIGraphicsEndImageContext()
        }
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
}
