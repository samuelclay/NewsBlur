//
//  WidgetViewController.swift
//  Widget Extension
//
//  Created by David Sinclair on 2019-11-26.
//  Copyright © 2019 NewsBlur. All rights reserved.
//

import UIKit
import NotificationCenter

enum WidgetError: String, Error {
    case notLoggedIn
    case loading
    case noFeeds
    case noStories
}

class WidgetExtensionViewController: UITableViewController, NCWidgetProviding {
    /// The base URL of the NewsBlur server.
    var host: String?
    
    /// The secret token for authentication.
    var token: String?
    
    /// An array of feeds to load.
    var feeds = [Feed]()
    
    /// Loaded stories.
    var stories = [Story]()
    
    /// An error to display instead of the stories, or `nil` if the stories should be displayed.
    var error: WidgetError?
    
    /// Paragraph style for title and content labels.
    lazy var paragraphStyle: NSParagraphStyle = {
        let paragraph = NSMutableParagraphStyle()
        
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = .left
        paragraph.lineHeightMultiple = 0.95
        
        return paragraph
    }()
    
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
    
    // MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Allow the today widget to be expanded or contracted.
        extensionContext?.widgetLargestAvailableDisplayMode = .expanded
        
        loadCachedStories()
        
        // Register the table view cell.
        let widgetTableViewCellNib = UINib(nibName: "WidgetTableViewCell", bundle: nil)
        tableView.register(widgetTableViewCellNib, forCellReuseIdentifier: WidgetTableViewCell.reuseIdentifier)
        
        let errorTableViewCellNib = UINib(nibName: "WidgetErrorTableViewCell", bundle: nil)
        tableView.register(errorTableViewCellNib, forCellReuseIdentifier: WidgetErrorTableViewCell.reuseIdentifier)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        extensionContext?.widgetLargestAvailableDisplayMode = error == nil ? .expanded : .compact
        
        tableView.reloadData()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        feedImageCache.removeAll()
        storyImageCache.removeAll()
    }
    
    // MARK: - Widget provider protocol
    
    typealias AnyDictionary = [String : Any]
    
    typealias WidgetCompletion = (NCUpdateResult) -> Void
    
    private var widgetCompletion: WidgetCompletion?
    
    private typealias ImageDictionary = [String : UIImage]
    private var feedImageCache = ImageDictionary()
    private var storyImageCache = ImageDictionary()
    
    private typealias LoaderDictionary = [String : Loader]
    private var loaders = LoaderDictionary()
    
    func widgetPerformUpdate(completionHandler: (@escaping WidgetCompletion)) {
        if feeds.isEmpty {
            if error == .noFeeds {
                completionHandler(.noData)
            } else {
                error = .noFeeds
                completionHandler(.newData)
            }
            return
        }
        
        let feedIds = feeds.map { $0.id }
        let combinedFeeds = feedIds.joined(separator: "&f=")
        
        guard let url = hostURL(with: "/reader/river_stories/?include_hidden=false&page=1&infrequent=false&order=newest&read_filter=unread&limit=\(Constant.limit)&f=\(combinedFeeds)") else {
            completionHandler(.failed)
            return
        }
        
        error = nil
        widgetCompletion = completionHandler
        loaders[Constant.storiesFilename] = Loader(url: url, completion: storyLoaderCompletion(result:))
    }
    
    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        switch activeDisplayMode {
        case .compact:
            // The compact view is a fixed size.
            preferredContentSize = maxSize
        case .expanded:
            let height: CGFloat = rowHeight * CGFloat(numberOfTableRowsToDisplay)
            
            preferredContentSize = CGSize(width: maxSize.width, height: min(height, maxSize.height))
        @unknown default:
            preconditionFailure("Unexpected value for activeDisplayMode.")
        }
    }
    
    // MARK: - Content container protocol
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        tableView.reloadData()
    }
    
    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return numberOfTableRowsToDisplay
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        precondition(Thread.isMainThread, "Table access not on the main thread")
        
        if let error {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: WidgetErrorTableViewCell.reuseIdentifier, for: indexPath) as? WidgetErrorTableViewCell else {
                preconditionFailure("Expected to dequeue a WidgetErrorTableViewCell")
            }
            
            switch error {
            case .notLoggedIn:
                cell.errorLabel.text = "Please log in to NewsBlur"
            case .loading:
                cell.errorLabel.text = "Tap to set up in NewsBlur"
            case .noFeeds:
                cell.errorLabel.text = "Please choose sites to show"
            case .noStories:
                cell.errorLabel.text = "No stories for selected sites"
            }
            
            return cell
        }
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: WidgetTableViewCell.reuseIdentifier, for: indexPath) as? WidgetTableViewCell
        else {
            preconditionFailure("Expected to dequeue a WidgetTableViewCell")
        }
        
        let story = stories[indexPath.row]
        let feed = feeds.first(where: { $0.id == story.feed })
        
        let isSmall = rowHeight < Constant.defaultRowHeight
        let baseDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption1)
        let sizedDescriptor = baseDescriptor.withSize(isSmall ? 12 : 13)
        let boldDescriptor = sizedDescriptor.withSymbolicTraits(.traitBold) ?? sizedDescriptor
        let titleFont = UIFont(descriptor: boldDescriptor, size: sizedDescriptor.pointSize)
        let titleColor = UIColor.label
        let contentFont = UIFont(descriptor: sizedDescriptor, size: isSmall ? 11 : 0)
        let contentColor = UIColor.secondaryLabel
        
        cell.barView.leftColor = feed?.leftColor
        cell.barView.rightColor = feed?.rightColor
        cell.barView.setNeedsDisplay()
        
        cell.feedImageView.image = nil
        
        // Completion handler passes the feed to confirm that this cell still wants that image (i.e. hasn't been reused).
        feedImage(for: story.feed) { (image, feed) in
            if story.feed == feed {
                cell.feedImageView.image = image
            }
        }
        
        if let title = feed?.title {
            cell.feedLabel.text = title
        } else {
            cell.feedLabel.text = ""
        }
        
        cell.feedLabel.textColor = UIColor.secondaryLabel
        cell.titleLabel.attributedText = attributed(story.title, with: titleFont, color: titleColor)
        cell.contentLabel.attributedText = attributed(story.content, with: contentFont, color: contentColor)
        cell.authorLabel.text = cleaned(story.author).uppercased()
        cell.authorLabel.textColor = UIColor.tertiaryLabel
        cell.dateLabel.text = story.date
        cell.dateLabel.textColor = UIColor.secondaryLabel
        cell.thumbnailImageView.image = nil
        cell.thumbnailImageView.isHidden = true
        cell.thumbnailTrailingConstraint.constant = Constant.thumbnailHiddenConstant
        cell.setNeedsLayout()
        
        storyImage(for: story.id, imageURL: story.imageURL) { (image, id) in
            if story.id == id {
                cell.thumbnailImageView.image = image
                cell.thumbnailImageView.isHidden = image == nil
                cell.thumbnailTrailingConstraint.constant = image == nil ? Constant.thumbnailHiddenConstant : Constant.thumbnailShownConstant
                cell.setNeedsLayout()
                cell.setNeedsDisplay()
            }
        }
        
        return cell
    }
    
    // MARK: - Table view delegate
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return rowHeight
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let error {
            if let appURL = URL(string: "newsblurwidget://?error=\(error.rawValue)") {
                extensionContext?.open(appURL, completionHandler: nil)
            }
        } else {
            let story = stories[indexPath.row]
            if let appURL = URL(string: "newsblurwidget://?feedId=\(story.feed)&storyHash=\(story.id)") {
                extensionContext?.open(appURL, completionHandler: nil)
            }
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - Helpers

private extension WidgetExtensionViewController {
    var numberOfTableRowsToDisplay: Int {
        if stories.isEmpty, error == nil {
            error = .loading
        }
        
        if error != nil {
            return 1
        } else if isCompact {
            return 1
        } else {
            return min(stories.count, Constant.limit)
        }
    }
    
    var isCompact: Bool {
        return extensionContext?.widgetActiveDisplayMode == NCWidgetDisplayMode.compact
    }
    
    var rowHeight: CGFloat {
        guard let context = extensionContext else {
            return Constant.defaultRowHeight
        }
        
        let height = context.widgetMaximumSize(for: .compact).height
        
        if isCompact {
            return height
        }
        
        let expandedHeight = context.widgetMaximumSize(for: .expanded).height
        
        if height * CGFloat(Constant.limit) > expandedHeight {
            return expandedHeight / CGFloat(Constant.limit)
        }
        
        return height
    }
    
    func cleaned(_ string: String) -> String {
        let clean = string.prefix(1000).replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "<[^>]+>|&[^;]+;", with: " ", options: .regularExpression, range: nil)
            .trimmingCharacters(in: .whitespaces)
        
        return clean.isEmpty ? " " : clean
    }
    
    func attributed(_ string: String, with font: UIFont, color: UIColor) -> NSAttributedString {
        let attributes: [NSAttributedString.Key : Any] = [.font : font, .foregroundColor: color, .paragraphStyle: paragraphStyle]
        
        return NSAttributedString(string: cleaned(string), attributes: attributes)
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
            widgetCompletion = nil
            loaders[Constant.storiesFilename] = nil
        }
        
        if case .failure = result {
            widgetCompletion?(.failed)
            
            return
        }
        
        guard case .success(let data) = result else {
            return
        }
        
        guard let dictionary = try? JSONSerialization.jsonObject(with: data, options: []) as? AnyDictionary else {
            widgetCompletion?(.failed)
            
            return
        }
        
        guard let storyArray = dictionary["stories"] as? [AnyDictionary] else {
            widgetCompletion?(.failed)
            
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
        let localCompletion = widgetCompletion
        
        DispatchQueue.main.async {
            self.extensionContext?.widgetLargestAvailableDisplayMode = self.error == nil ? .expanded : .compact
            
            self.tableView.reloadData()
            self.tableView.setNeedsDisplay()
            
            localCompletion?(.newData)
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
        guard let folderURL else {
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
