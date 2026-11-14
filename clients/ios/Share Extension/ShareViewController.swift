//
//  ShareViewController.swift
//  Share Extension
//
//  Created by David Sinclair on 2021-07-18.
//  Copyright © 2021 NewsBlur. All rights reserved.
//

import UIKit
import MobileCoreServices
import UserNotifications

class ShareViewController: UIViewController {
    @IBOutlet var delegate: ShareViewDelegate!
    
    @IBOutlet weak var modeSegmentedControl: UISegmentedControl!
    
    @IBOutlet weak var tableView: UITableView!
    
    /// The group preferences, shared with the main app.
    lazy var prefs: UserDefaults = {
        return UserDefaults(suiteName: "group.com.newsblur.NewsBlur-Group") ?? UserDefaults.standard
    }()
    
    /// Whether we are saving the story privately or sharing publicly.
    enum Mode {
        /// Save privately.
        case save
        
        /// Share publicly.
        case share
        
        /// Add site.
        case add
    }
    
    /// Whether we are saving the story privately, sharing publicly, or adding a site.
    var mode: Mode = .save
    private var subscriptionTask: URLSessionDataTask?
    private var isSubscribing = false
    private var didFinish = false
    
    /// Dictionary representation of a tag.
    typealias TagDict = [String : Any]
    
    /// Dictionary of tag dictionaries.
    typealias TagsDict = [String : TagDict]
    
    /// Tag structure.
    struct Tag: Identifiable, Hashable {
        /// Identifier of the tag.
        let id: String
        
        /// Name of the tag.
        let name: String
        
        /// Count of stories with this tag.
        let count: Int
    }
    
    /// An array of tags, from the main app.
    var tags = [Tag]()
    
    /// New tag to add, if any.
    var newTag = ""
    
    /// User-entered comments, only used when sharing.
    var comments = ""
    
    /// An array of folders, from the main app.
    var folders = [String]()
    
    /// New folder name, only used when adding.
    var newFolder = ""
    
    /// Index path of the selected folder.
    var selectedFolderIndexPath = IndexPath(item: 0, section: 0)
    
    /// Title of the item being shared.
    var itemTitle: String? = nil

    /// The index path of the new tag field.
    lazy var indexPathForNewTag: IndexPath = {
        return IndexPath(item: tags.count, section: 0)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if Bundle.main.bundleIdentifier?.hasSuffix(".Subscribe-Extension") == true {
            modeSegmentedControl.selectedSegmentIndex = 2
            mode = .add
        }
        
        tableView.isEditing = mode == .save
        
        if let dicts = prefs.object(forKey: "share:tags") as? TagsDict {
            tags = dicts.map { (key: String, value: TagDict) in
                return Tag(id: key, name: value["feed_title"] as? String ?? "tag", count: value["ps"] as? Int ?? 0)
            }
            
            tags.sort { tag1, tag2 in
                return tag1.name.lowercased() < tag2.name.lowercased()
            }
        }
        
        folders = FeedSubscriptionRequest.selectableFolders(prefs.stringArray(forKey: "share:folders") ?? [])
        changedMode(modeSegmentedControl as Any)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(notification:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    func updateSaveButtonState() {
        guard !isSubscribing else {
            navigationItem.rightBarButtonItem?.isEnabled = false
            return
        }
        switch mode {
        case .save:
            if let rows = tableView.indexPathsForSelectedRows {
                navigationItem.rightBarButtonItem?.isEnabled = !rows.isEmpty
            } else {
                navigationItem.rightBarButtonItem?.isEnabled = false
            }
        default:
            navigationItem.rightBarButtonItem?.isEnabled = true
        }
    }
    
    @objc private func keyboardDidShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height + tableView.rowHeight, right: 0)
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        tableView.contentInset = .zero
    }
    
    @IBAction func newTagFieldChanged(_ sender: UITextField) {
        if mode == .save {
            newTag = sender.text ?? ""
            
            if newTag.isEmpty {
                tableView.deselectRow(at: indexPathForNewTag, animated: false)
            } else {
                tableView.selectRow(at: indexPathForNewTag, animated: false, scrollPosition: .none)
            }
        } else if mode == .add {
            newFolder = sender.text ?? ""
        }
        
        updateSaveButtonState()
    }
    
    @IBAction func newTagFieldReturn(_ sender: UITextField) {
        sender.resignFirstResponder()
    }
    
    @IBAction func cancel(_ sender: Any) {
        didFinish = true
        subscriptionTask?.cancel()
        subscriptionTask = nil
        extensionContext?.cancelRequest(withError: NSError(domain: Bundle.main.bundleIdentifier!, code: 0))
    }
    
    @IBAction func save(_ sender: Any) {
        if mode == .add {
            subscribe()
            return
        }
        itemTitle = nil

        if let itemProvider = providerWithURL {
            itemProvider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { item, error in
                if let url = item as? URL {
                    self.send(url: url)
                }

                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        } else if let itemProvider = providerWithText {
            itemProvider.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil) { item, error in
                if let text = item as? String {
                    self.send(text: text)
                }

                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
    }
    
    @IBAction func changedMode(_ sender: Any) {
        switch modeSegmentedControl.selectedSegmentIndex {
        case 1:
            mode = .share
            navigationItem.rightBarButtonItem?.title = "Share"
        case 2:
            mode = .add
            navigationItem.rightBarButtonItem?.title = "Subscribe"
        default:
            mode = .save
            navigationItem.rightBarButtonItem?.title = "Save"
        }
        
        tableView.isEditing = mode == .save
        tableView.reloadData()
        
        updateSaveButtonState()
    }
}

private extension ShareViewController {
    func setSubscribing(_ subscribing: Bool) {
        isSubscribing = subscribing
        modeSegmentedControl.isEnabled = !subscribing
        tableView.isUserInteractionEnabled = !subscribing
        navigationItem.rightBarButtonItem?.title = subscribing ? "Subscribing…" : "Subscribe"
        if subscribing {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            navigationItem.titleView = spinner
        } else {
            navigationItem.titleView = nil
        }
        updateSaveButtonState()
    }

    func subscribe() {
        guard !isSubscribing, !didFinish else { return }
        view.endEditing(true)
        guard let host = prefs.string(forKey: "share:host"), !host.isEmpty,
              let token = prefs.string(forKey: "share:token"), !token.isEmpty else {
            showSubscriptionError(FeedSubscriptionError.signInRequired)
            return
        }
        guard let username = prefs.string(forKey: "share:username"), !username.isEmpty else {
            showSubscriptionError(FeedSubscriptionError.accountRefreshRequired)
            return
        }
        setSubscribing(true)
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        let candidates = [kUTTypeURL as String, kUTTypeText as String].flatMap { type in
            providers.filter { $0.hasItemConformingToTypeIdentifier(type) }.map { ($0, type) }
        }
        loadSubscriptionURL(candidates, index: 0) { [weak self] url in
            guard let self, !self.didFinish else { return }
            guard let url else {
                self.showSubscriptionError(FeedSubscriptionError.invalidURL)
                return
            }
            let folderPath = self.folders.indices.contains(self.selectedFolderIndexPath.row)
                ? self.folders[self.selectedFolderIndexPath.row] : "everything"
            do {
                let request = try FeedSubscriptionRequest.make(url: url, host: host, token: token,
                                                              folder: self.extractFolderName(folderPath),
                                                              newFolder: self.newFolder)
                self.subscriptionTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                    let result: Result<String, Error> = Result {
                        if let error { throw error }
                        guard let data, let response = response as? HTTPURLResponse else {
                            throw FeedSubscriptionError.invalidResponse
                        }
                        return try FeedSubscriptionRequest.feedID(data: data, statusCode: response.statusCode)
                    }
                    DispatchQueue.main.async {
                        guard let self, !self.didFinish else { return }
                        self.subscriptionTask = nil
                        switch result {
                        case .success(let feedID):
                            // FeedSubscriptionCoordinator.swift opens the confirmed feed after the app refreshes.
                            self.prefs.set(["feed_id": feedID, "username": username, "host": host],
                                           forKey: "subscription:pending-feed")
                            self.setSubscribing(false)
                            let alert = UIAlertController(title: "Subscribed", message: "Open NewsBlur to read this feed.", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "Done", style: .default) { [weak self] _ in
                                self?.didFinish = true
                                self?.extensionContext?.completeRequest(returningItems: [])
                            })
                            self.present(alert, animated: true)
                        case .failure(let error):
                            self.showSubscriptionError(error)
                        }
                    }
                }
                self.subscriptionTask?.resume()
            } catch {
                self.showSubscriptionError(error)
            }
        }
    }

    func loadSubscriptionURL(_ candidates: [(NSItemProvider, String)], index: Int, completion: @escaping (URL?) -> Void) {
        guard !didFinish else { return }
        guard index < candidates.count else {
            completion(nil)
            return
        }
        let (provider, type) = candidates[index]
        provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self, !self.didFinish else { return }
                if let url = FeedSubscriptionRequest.remoteURL(item) {
                    completion(url)
                } else {
                    self.loadSubscriptionURL(candidates, index: index + 1, completion: completion)
                }
            }
        }
    }

    func showSubscriptionError(_ error: Error) {
        setSubscribing(false)
        let alert = UIAlertController(title: "Could Not Subscribe", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Try Again", style: .default) { [weak self] _ in
            self?.subscribe()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    var providerWithURL: NSItemProvider? {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return nil
        }
        
        for extensionItem in extensionItems {
            if let itemProviders = extensionItem.attachments {
                for itemProvider in itemProviders {
                    if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                        itemTitle = extensionItem.attributedTitle?.string
                        
                        if itemTitle == nil {
                            itemTitle = extensionItem.attributedContentText?.string
                        }
                        
                        return itemProvider
                    }
                }
            }
        }
        
        return nil
    }
    
    var providerWithText: NSItemProvider? {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return nil
        }
        
        for extensionItem in extensionItems {
            if let itemProviders = extensionItem.attachments {
                for itemProvider in itemProviders {
                    if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                        return itemProvider
                    }
                }
            }
        }
        
        return nil
    }
    
    func send(url: URL? = nil, text: String? = nil) {
        guard mode == .save || mode == .share else { return }
        let requestPath = mode == .share ? "api/share_story" : "api/save_story"
        guard let host = prefs.object(forKey: "share:host") as? String,
              let token = prefs.object(forKey: "share:token") as? String,
              let requestURL = URL(string: "\(host)/\(requestPath)/\(token)") else {
            return
        }
        
        let postBody = mode == .share ? postShare(url: url, text: text) : postSave(url: url, text: text)
        var request = URLRequest(url: requestURL)
        
        request.httpMethod = "POST"
        request.httpBody = postBody.data(using: .utf8)
        
        let config = URLSessionConfiguration.background(withIdentifier: UUID().uuidString)
        config.sharedContainerIdentifier = "group.com.newsblur.NewsBlur-Group"
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: request as URLRequest)
        
        task.resume()
        
        NSLog("⚾️ sending: \(request) \(postBody) \(config.identifier ?? "")")
    }
    
    func encoded(_ string: String?) -> String {
        return string?.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
    }

    func postSave(url: URL?, text: String?) -> String {
        let title = itemTitle
        let encodedURL = encoded(url?.absoluteString)
        let encodedTitle = encoded(title)
        let encodedContent = encoded(text)
        
        let indexPaths = tableView.indexPathsForSelectedRows ?? []
        var selectedTagsArray = [String]()
        
        for index in 0..<tags.count {
            if indexPaths.contains(IndexPath(item: index, section: 0)) {
                selectedTagsArray.append(encoded(tags[index].name))
            }
        }
        
        let selectedTags = selectedTagsArray.joined(separator: ",")
        let encodedNewTag = encoded(newTag)
        
        let postBody = "story_url=\(encodedURL)&title=\(encodedTitle)&content=\(encodedContent)&user_tags=\(selectedTags)&add_user_tag=\(encodedNewTag)"
        
        return postBody
    }
    
    func postShare(url: URL?, text: String?) -> String {
        let title = itemTitle
        let encodedURL = encoded(url?.absoluteString)
        let encodedTitle = encoded(title)
        let encodedContent = encoded(text)
        
        var comments = comments
        
        // Don't really need this stuff if I don't populate the comments from the title or text; leave for now just in case that is wanted.
        if title != nil && comments == title {
            comments = ""
        }
        
        if text != nil && comments == text {
            comments = ""
        }
        
        let encodedComments = encoded(comments)
        
        let postBody = "story_url=\(encodedURL)&title=\(encodedTitle)&content=\(encodedContent)&comments=\(encodedComments)"
        
        return postBody
    }
    
    /// Extracts just the folder name from a full folder path.
    /// "everything ▸ Tech ▸ Python" → "Python"
    /// "everything" → "" (root level)
    func extractFolderName(_ folderPath: String) -> String {
        // "everything" alone means top level
        if folderPath == "everything" {
            return ""
        }

        // Extract last component after " ▸ "
        if let range = folderPath.range(of: " ▸ ", options: .backwards) {
            return String(folderPath[range.upperBound...])
        }

        // No separator found - check for Top Level
        if folderPath.contains("Top Level") {
            return ""
        }

        return folderPath
    }

}

extension ShareViewController: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard mode == .save || mode == .share else { return }
        let content = UNMutableNotificationContent()
        content.title = "NewsBlur"

        if let error {
            NSLog("task completed with error: \(error)")
            
            NSLog("⚾️ share error: \(error)")

            content.body = mode == .save ? "Unable to save this story" : "Unable to share this story"
        } else {
            NSLog("task completed successfully: \(String(describing: task.response))")
            
            NSLog("⚾️ share success: \(String(describing: task.response))")

            content.body = mode == .save ? "Saved this story" : "Shared this story"
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let uuidString = UUID().uuidString
        let request = UNNotificationRequest(identifier: uuidString,
                                            content: content, trigger: trigger)
        let notificationCenter = UNUserNotificationCenter.current()

        notificationCenter.add(request) { (error) in
            if let error {
                NSLog("notification error: \(error)")
            }
        }
    }
}
