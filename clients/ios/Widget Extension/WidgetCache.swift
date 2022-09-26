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
    
    /// The preview size and position.
    enum Preview: String {
        case none
        case smallLeft
        case largeLeft
        case largeRight
        case smallRight
    }
    
    /// The preview size and position.
    var preview: Preview = .largeRight
    
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
    
    private typealias LoaderDictionary = [String : Loader]
    
    private var loaders = LoaderDictionary()
    
    struct Constant {
        static let group = "group.com.newsblur.NewsBlur-Group"
        static let token = "share:token"
        static let host = "share:host"
        static let feeds = "widget:feeds_array"
        static let preview = "widget:preview_images_size"
        static let previewNone = "none"
        static let previewSmallLeft = "small_left"
        static let previewLargeLeft = "large_left"
        static let previewLargeRight = "large_right"
        static let previewSmallRight = "small_right"
        static let widgetFolder = "Widget"
        static let storiesFilename = "Stories.json"
        static let feedImagesFilename = "Feed Images"
        static let imageExtension = "png"
        static let limit = 6
        static let defaultRowHeight: CGFloat = 110
        static let thumbnailHiddenConstant: CGFloat = -50
        static let thumbnailShownConstant: CGFloat = 20
    }
    
    func load(completionHandler: @escaping CacheCompletion) {
        let feedIds = feeds.map { $0.id }
        let combinedFeeds = feedIds.joined(separator: "&f=")
        
        guard let url = hostURL(with: "/reader/river_stories_widget/?include_hidden=false&replace_hidden_stories=true&thumbnail_size=192&page=1&infrequent=false&order=newest&read_filter=unread&limit=\(Constant.limit)&f=\(combinedFeeds)") else {
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
    
    func hostURL(with path: String) -> URL? {
        guard let host else {
            return nil
        }
        
        if let token {
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
        
        if stories.isEmpty, error == nil {
            error = .noStories
        }
        
        // Keep a local copy, since the property will be cleared before the async closure is called.
        let localCompletion = cacheCompletion
        
        DispatchQueue.main.async {
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
        
        if let previewString = defaults.string(forKey: Constant.preview) {
            switch previewString {
            case Constant.previewNone:
                preview = .none
            case Constant.previewSmallLeft:
                preview = .smallLeft
            case Constant.previewLargeLeft:
                preview = .largeLeft
            case Constant.previewSmallRight:
                preview = .smallRight
            default:
                preview = .largeRight
            }
        }
        
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
            decoder.dataDecodingStrategy = .base64
            
            stories = try decoder.decode([Story].self, from: json)
        } catch {
            NSLog("Error \(error)")
        }
    }
    
    func saveStories() {
        guard let url = storiesURL else {
            return
        }
        
        createWidgetFolder()
        
        let encoder = JSONEncoder()
        
        encoder.dateEncodingStrategy = .iso8601
        encoder.dataEncodingStrategy = .base64
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let json = try encoder.encode(stories)
            
            try json.write(to: url)
        } catch {
            NSLog("Error \(error)")
        }
    }
    
    func save(feedImage: UIImage, for identifier: String) {
        feedImageCache[identifier] = feedImage
        save(image: feedImage, to: feedImagesURL, for: identifier)
    }
    
    func save(image: UIImage, to folderURL: URL?, for identifier: String) {
        guard let folderURL else {
            return
        }
        
        createWidgetFolder(url: folderURL)
        
        do {
            let imageURL = folderURL.appendingPathComponent(identifier).appendingPathExtension(Constant.imageExtension)
            
            try image.pngData()?.write(to: imageURL)
        } catch {
            NSLog("Image saving error: \(error)")
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
    
    func loadCachedImage(folderURL: URL?, identifier: String) -> UIImage? {
        guard let folderURL else {
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
            NSLog("Cached image loading error: \(error)")
        }
        
        return nil
    }
}
