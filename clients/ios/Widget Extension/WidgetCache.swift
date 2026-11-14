//
//  WidgetCache.swift
//  Widget Extension
//
//  Created by David Sinclair on 2021-08-07.
//  Copyright © 2021 NewsBlur. All rights reserved.
//

import WidgetKit
import UIKit
import OSLog

enum WidgetCacheError: String, Error {
    case notLoggedIn
    case loading
    case noFeeds
    case noStories
}

class WidgetCache {
    private static let logger = Logger(subsystem: "com.newsblur.widget", category: "stories")
    let source: String
    private var cacheFilename = "Stories.json"

    init(source: String = "all") { self.source = source }

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
    private var storyPages = WidgetStoryPagination<Story>(limit: Constant.limit)
    private var storyLoadDeadline = Date.distantPast
    
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
        guard token?.isEmpty == false else {
            stories = []
            error = .notLoggedIn
            completionHandler()
            return
        }
        guard !feeds.isEmpty else {
            stories = []
            error = .noFeeds
            completionHandler()
            return
        }
        error = nil
        cacheCompletion = completionHandler
        storyPages = WidgetStoryPagination(limit: Constant.limit)
        storyLoadDeadline = Date().addingTimeInterval(20)
        loadStoryPage()
    }

    private func loadStoryPage() {
        let remainingTime = storyLoadDeadline.timeIntervalSinceNow
        let combinedFeeds = feeds.map { $0.id }.joined(separator: "&f=")
        guard remainingTime > 0,
              let url = hostURL(with: "/reader/river_stories_widget/?include_hidden=false&thumbnail_size=192&page=\(storyPages.page)&infrequent=false&order=newest&read_filter=unread&limit=\(Constant.limit)&f=\(combinedFeeds)") else {
            finishStoryLoading(reachedEnd: false)
            return
        }
        loaders[Constant.storiesFilename] = Loader(url: url, timeout: remainingTime, completion: storyLoaderCompletion(result:))
    }
    
    func cleaned(_ string: String) -> String {
        let clean = string.prefix(1000).replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "<[^>]+>|&[^;]+;", with: " ", options: .regularExpression, range: nil)
            .trimmingCharacters(in: .whitespaces)
        
        return clean.isEmpty ? " " : clean
    }
    
    func hostURL(with path: String) -> URL? {
        guard let host, var components = URLComponents(string: host + path) else { return nil }
        if let token {
            components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "secret_token", value: token)]
        }
        return components.url
    }

    func storyLoaderCompletion(result: Result<Data, Error>) {
        guard case .success(let data) = result,
              let dictionary = try? JSONSerialization.jsonObject(with: data, options: []) as? AnyDictionary,
              (dictionary["code"] as? Int ?? 1) >= 0,
              let storyArray = dictionary["stories"] as? [AnyDictionary] else {
            finishStoryLoading(reachedEnd: false)
            return
        }
        let pageStories = storyArray.map { Story(from: $0) }
        let hiddenCount = dictionary["hidden_stories_removed"] as? Int ?? 0
        let page = storyPages.page
        let result = storyPages.append(pageStories, hiddenCount: hiddenCount)
        Self.logger.notice("Story page \(page, privacy: .public): visible=\(pageStories.count, privacy: .public), hidden=\(hiddenCount, privacy: .public), accumulated=\(self.storyPages.stories.count, privacy: .public)")
        switch result {
        case .nextPage:
            loadStoryPage()
        case .complete:
            finishStoryLoading(reachedEnd: storyPages.stories.count < Constant.limit)
        case .pageLimit:
            finishStoryLoading(reachedEnd: false)
        }
    }

    private func finishStoryLoading(reachedEnd: Bool) {
        let usesCache = storyPages.stories.isEmpty && !reachedEnd && !stories.isEmpty
        stories = storyPages.resolvedStories(cached: stories, reachedEnd: reachedEnd)
        error = stories.isEmpty ? (reachedEnd ? .noStories : .loading) : nil
        Self.logger.notice("Story load complete: visible=\(self.stories.count, privacy: .public), reachedEnd=\(reachedEnd, privacy: .public), usedCache=\(usesCache, privacy: .public)")
        if !storyPages.stories.isEmpty || reachedEnd {
            saveStories()
        }
        // WidgetCache.swift releases the completion only after all pages, never between requests.
        let localCompletion = cacheCompletion
        cacheCompletion = nil
        loaders[Constant.storiesFilename] = nil
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
        return widgetFolderURL?.appendingPathComponent(cacheFilename)
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
        
        let catalog = WidgetSourceCatalog.load(defaults: defaults)
        let ids = catalog.feedIDs(for: source)
        feeds = ids.compactMap { id in
            guard var dictionary = catalog.feeds[id] else { return nil }
            dictionary["id"] = id
            return Feed(from: dictionary)
        }
        cacheFilename = WidgetSourceCatalog.cacheFilename(host: host ?? "", username: defaults.string(forKey: "share:username") ?? "", source: source, feedIDs: ids)
        guard token?.isEmpty == false else { error = .notLoggedIn; return }
        guard !feeds.isEmpty else { error = .noFeeds; return }

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
            
            try json.write(to: url, options: .atomic)
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

        // WidgetCache.swift reuses the account-bound bulk icons also displayed by WidgetConfiguration.swift.
        if let data = WidgetSourceCatalog.load().favicon(for: feed), let image = UIImage(data: data) {
            feedImageCache[feed] = image
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
