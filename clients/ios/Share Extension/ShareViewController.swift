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
        
        tableView.isEditing = mode == .save
        
        if let dicts = prefs.object(forKey: "share:tags") as? TagsDict {
            tags = dicts.map { (key: String, value: TagDict) in
                return Tag(id: key, name: value["feed_title"] as? String ?? "tag", count: value["ps"] as? Int ?? 0)
            }
            
            tags.sort { tag1, tag2 in
                return tag1.name.lowercased() < tag2.name.lowercased()
            }
        }
        
        if let foldersArray = prefs.object(forKey: "share:folders") as? [String] {
            folders = foldersArray
            
            folders.removeAll { ["river_global", "river_blurblogs", "infrequent", "widget_stories", "read_stories", "saved_searches", "saved_stories"].contains($0) }
        }
        
        updateSaveButtonState()
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(notification:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    func updateSaveButtonState() {
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
        extensionContext?.cancelRequest(withError: NSError(domain: Bundle.main.bundleIdentifier!, code: 0))
    }
    
    @IBAction func save(_ sender: Any) {
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
            navigationItem.rightBarButtonItem?.title = "Add"
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
        guard let host = prefs.object(forKey: "share:host") as? String,
              let token = prefs.object(forKey: "share:token") as? String,
              let requestURL = URL(string: "\(host)/\(requestPath)/\(token)") else {
            return
        }
        
        let postBody = postBody(url: url, text: text)
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
    
    var requestPath: String {
        switch mode {
        case .share:
            return "api/share_story"
        case .save:
            return "api/save_story"
        case .add:
            return "api/add_url"
        }
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
    
    func postAdd(url: URL?, text: String?) -> String {
        let folder = folders[selectedFolderIndexPath.row]
        let encodedFolder = encoded(folder)
        let encodedURL = encoded(url?.absoluteString)
        
        var postBody = "folder=\(encodedFolder)&url=\(encodedURL)"
        
        if newFolder != "" {
            postBody += "&new_folder=\(encoded(newFolder))"
        }
        
        return postBody
    }
    
    func postBody(url: URL?, text: String?) -> String {
        switch mode {
        case .save:
            return postSave(url: url, text: text)
        case .share:
            return postShare(url: url, text: text)
        case .add:
            return postAdd(url: url, text: text)
        }
    }
}

//extension ShareViewController: URLSessionDataDelegate {
//    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
//        NSLog("⚾️ received \(String(describing: String(data: data, encoding: .utf8)))")
//    }
//}

extension ShareViewController: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let content = UNMutableNotificationContent()
        
        content.title = "NewsBlur"
        
        if let error {
            print("task completed with error: \(error)")
            
            NSLog("⚾️ share error: \(error)")
            
            switch mode {
            case .save:
                content.body = "Unable to save this story"
            case .share:
                content.body = "Unable to share this story"
            case .add:
                content.body = "Unable to add this site"
            }
        } else {
            print("task completed successfully: \(String(describing: task.response))")
            
            NSLog("⚾️ share success: \(String(describing: task.response))")
            
            switch mode {
            case .save:
                content.body = "Saved this story"
            case .share:
                content.body = "Shared this story"
            case .add:
                content.body = "Added this site"
            }
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let uuidString = UUID().uuidString
        let request = UNNotificationRequest(identifier: uuidString,
                                            content: content, trigger: trigger)
        let notificationCenter = UNUserNotificationCenter.current()
        
        notificationCenter.add(request) { (error) in
            if let error {
                print("notification error: \(error)")
            }
        }
    }
}
