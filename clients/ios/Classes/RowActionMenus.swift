import SwiftUI
import UIKit

// RowActionMenus.swift gives UIKit rows and SwiftUI cards the same actions, icons, and grouping.
@MainActor struct RowMenuAction: Identifiable {
    let id: String
    let title: String
    let symbol: String
    var destructive = false
    let perform: () -> Void

    var native: UIAction {
        UIAction(title: title, image: UIImage(systemName: symbol), identifier: .init(id),
                 attributes: destructive ? .destructive : []) { _ in perform() }
    }
}

@MainActor struct RowMenuContent: View {
    let groups: [[RowMenuAction]]
    var body: some View {
        ForEach(Array(groups.enumerated()), id: \.offset) { _, actions in
            Section {
                ForEach(actions) { action in
                    Button(role: action.destructive ? .destructive : nil, action: action.perform) {
                        Label(action.title, systemImage: action.symbol)
                    }
                }
            }
        }
    }
}

@MainActor enum RowActionMenus {
    static func isUserFolder(_ folder: String) -> Bool {
        !folder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !["everything", "infrequent", "dashboard", "discover_sites", "daily_briefing", "try_feed"].contains(folder) &&
        !folder.hasPrefix("river_") && !folder.hasPrefix("trending:") &&
        !folder.hasPrefix("saved_") && !folder.hasSuffix("_stories")
    }

    static func performStoryShortcut(_ story: Story, controller: FeedDetailViewController) {
        let app = controller.appDelegate!
        switch UserDefaults.standard.string(forKey: "long_press_story_title") {
        case "mark_unread":
            controller.storiesCollection.toggleStoryUnread(story.dictionary)
            controller.reload()
        case "save_story":
            controller.storiesCollection.toggleStorySaved(story.dictionary)
            controller.reload()
        case "open_send_to":
            app.activeStory = story.dictionary
            app.showSend(to: controller, sender: controller.view)
        case "train_story":
            app.activeStory = story.dictionary
            app.openTrainStory(controller.view)
        case "ask":
            app.activeStory = story.dictionary
            app.showMarkOlderNewerReadMenu(with: controller.storiesCollection, story: story.dictionary,
                                         sourceView: controller.view, sourceRect: controller.view.bounds,
                                         extraItems: []) { _ in controller.reload() }
        default: break
        }
    }

    static func menu(_ groups: [[RowMenuAction]]) -> UIMenu {
        UIMenu(children: groups.filter { !$0.isEmpty }.map {
            UIMenu(options: .displayInline, children: $0.map(\.native))
        })
    }

    static func story(_ story: Story, controller: FeedDetailViewController, source: UIView, dashboard: Bool = false) -> [[RowMenuAction]] {
        let app = controller.appDelegate!
        let collection = controller.storiesCollection!
        let dictionary = story.dictionary
        let newestFirst = collection.activeOrder != "oldest"
        func action(_ id: String, _ title: String, _ icon: String, _ handler: @escaping () -> Void) -> RowMenuAction {
            RowMenuAction(id: id, title: title, symbol: icon, perform: handler)
        }
        var reading: [RowMenuAction] = []
        if !dashboard && !controller.isDashboard && story.isReadAvailable {
            reading.append(action("read", story.isRead ? NBLocalization.text("Mark as unread") : NBLocalization.text("Mark as read"), story.isRead ? "circle" : "checkmark.circle") {
                collection.toggleStoryUnread(dictionary)
                controller.reload()
            })
            if !collection.isSavedView && !collection.isReadView && !collection.isSocialView && !collection.isDailyBriefing && !collection.isTrending && !collection.isInfrequent {
                reading += [
                    action("newer", NBLocalization.text("Mark newer as read"), newestFirst ? "arrow.up.to.line" : "arrow.down.to.line") {
                        controller.markFeedsRead(fromTimestamp: story.timestamp, andOlder: false)
                    },
                    action("older", NBLocalization.text("Mark older as read"), newestFirst ? "arrow.down.to.line" : "arrow.up.to.line") {
                        controller.markFeedsRead(fromTimestamp: story.timestamp, andOlder: true)
                    }
                ]
            }
        }
        var saving = [action("save", story.isSaved ? NBLocalization.text("Unsave story") : NBLocalization.text("Save story"), story.isSaved ? "bookmark.slash" : "bookmark") {
            collection.toggleStorySaved(dictionary)
            controller.reload()
        }]
        if ListenStoryBridge.offersQueue(forStory: dictionary) {
            // RowActionMenus.swift adds the pressed story to Listen's Up Next without opening it (Listen/ListenQueue.swift).
            let queued = ListenStoryBridge.isQueued(dictionary)
            saving.append(action("up-next", ListenStoryBridge.queueMenuTitle(forStory: dictionary), queued ? "text.badge.minus" : "text.badge.plus") {
                ListenStoryBridge.toggleQueue(forStory: dictionary)
            })
        }
        var sharing: [RowMenuAction] = []
        if let permalink = dictionary["story_permalink"] as? String, let url = URL(string: permalink) {
            sharing = [
                action("share-link", NBLocalization.text("Share link…"), "square.and.arrow.up") {
                    share([url], from: controller, source: source)
                },
                action("share-story", NBLocalization.text("Share story…"), "doc.text") {
                    // NewsBlurAppDelegate.m snapshots the story when constructing its share sheet.
                    let previous = app.activeStory
                    app.activeStory = dictionary
                    app.showSend(to: controller, sender: source)
                    app.activeStory = previous
                }
            ]
        }
        sharing.append(action("share-newsblur", story.isShared ? NBLocalization.text("Edit NewsBlur share…") : NBLocalization.text("Share on NewsBlur…"), "quote.bubble") {
            // ShareViewController.m reads the active story and comment when the composer opens and submits.
            app.activeStory = dictionary
            let userID = app.dictSocialProfile?["user_id"].map { String(describing: $0) }
            let comments = dictionary["friend_comments"] as? [[String: Any]] ?? []
            app.activeComment = comments.first { comment in
                guard let userID, let author = comment["user_id"] else { return false }
                return String(describing: author) == userID
            }
            app.showShareView(app.activeComment == nil ? "share" : "edit-share", setUserId: nil,
                              setUsername: nil, setReplyId: nil)
        })
        var tools: [RowMenuAction] = []
        if !dashboard && collection.isRiverView && !collection.isSavedView && !collection.isSocialView,
           let id = dictionary["story_feed_id"], let feed = app.getFeed(String(describing: id)), !feed.isEmpty {
            tools.append(action("open-feed", NBLocalization.text("Open feed"), "dot.radiowaves.left.and.right") {
                app.loadFeed(String(describing: id), withStory: nil, animated: true)
            })
        }
        tools.append(action("train", NBLocalization.text("Train intelligence…"), "slider.horizontal.3") {
            app.activeStory = dictionary
            app.openTrainStory(source)
        })
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "show_ask_ai") == nil || defaults.bool(forKey: "show_ask_ai") {
            tools.append(action("ask-ai", NBLocalization.text("Ask AI…"), "sparkles") {
                app.openAskAIDialog(dictionary)
            })
        }
        return [reading, saving, sharing, tools].filter { !$0.isEmpty }
    }

    static func share(_ items: [Any], from controller: UIViewController, source: UIView) {
        let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = source
        sheet.popoverPresentationController?.sourceRect = source.bounds
        controller.present(sheet, animated: true)
    }
}

extension FeedsViewController: UIContextMenuInteractionDelegate {
    func feedActions(feedID: String?, folder: String, source: UIView) -> [[RowMenuAction]] {
        let app = appDelegate!
        let feed = feedID.flatMap { app.getFeed($0) }
        let title = feed?["feed_title"] as? String ?? app.extractFolderName(folder) ?? folder
        let regularFolder = RowActionMenus.isUserFolder(folder)
        let feedIDs = feedID.map { [$0] } ?? (app.feedIds(forFolderTitle: folder) ?? []).map { String(describing: $0) }
        func action(_ id: String, _ title: String, _ icon: String, destructive: Bool = false,
                    _ handler: @escaping () -> Void) -> RowMenuAction {
            RowMenuAction(id: id, title: title, symbol: icon, destructive: destructive, perform: handler)
        }
        var reading: [RowMenuAction] = []
        if !feedIDs.isEmpty && !app.isSavedStoriesIntelligenceMode() && !folder.hasPrefix("saved_") && !folder.hasPrefix("trending:") && folder != "read_stories" {
            reading.append(action("mark-read", NBLocalization.text("Mark as read…"), "checkmark.circle") { [weak self] in
                guard let self else { return }
                app.showMarkReadMenu(withFeedIds: feedIDs, collectionTitle: folder == "everything" ? "everything" : feedID == nil ? "entire folder" : "site",
                                    sourceView: source, sourceRect: source.bounds) { _ in
                    self.feedTitlesTable.reloadData()
                }
            })
        }
        var tools: [RowMenuAction] = []
        var organize: [RowMenuAction] = []
        var deletion: [RowMenuAction] = []
        if let feedID, feed != nil, !app.isSocialFeed(feedID), !app.isSavedFeed(feedID) {
            reading.append(action("refresh", NBLocalization.text("Refresh site"), "arrow.clockwise") { [weak self] in
                app.get("\(app.url!)/reader/refresh_feed/\(feedID)", parameters: nil, success: { _, _ in
                    app.reloadFeedsView(false)
                }, failure: { _, error in self?.informError(error) })
            })
            tools = [
                action("statistics", NBLocalization.text("Statistics"), "chart.bar") { app.openStatistics(withFeed: feedID, sender: source) },
                action("notifications", NBLocalization.text("Notifications"), "bell") { app.openNotifications(withFeed: feedID, sender: source) },
                action("train", NBLocalization.text("Train intelligence…"), "slider.horizontal.3") { [weak self] in
                    self?.selectFeed(feedID, inFolder: folder)
                    app.openTrainSite(withFeedLoaded: true, from: source)
                },
                action("related", NBLocalization.text("Related sites"), "sparkles") { app.openDiscoverFeedsDialog(fromSettingsButton: feedID, sourceView: source) }
            ]
            organize.append(action("rename", NBLocalization.text("Rename site…"), "pencil") { [weak self] in
                self?.renameMenuTarget(title: title, path: "/reader/rename_feed", parameters: ["feed_id": feedID], nameKey: "feed_title")
            })
            let muted = app.dictInactiveFeeds[feedID] != nil
            organize.append(action("mute", muted ? NBLocalization.text("Unmute site") : NBLocalization.text("Mute site"), muted ? "speaker.wave.2" : "speaker.slash") { [weak self] in
                self?.submitMenuAction("/reader/set_feed_mute", parameters: ["feed_id": feedID, "mute": muted ? "false" : "true"])
            })
            deletion = [action("delete", NBLocalization.text("Delete site…"), "trash", destructive: true) { [weak self] in
                self?.confirmMenuDeletion(title: title, path: "/reader/delete_feed",
                                         parameters: ["feed_id": feedID, "in_folder": app.extractFolderName(folder) ?? ""])
            }]
        } else if feedID == nil && regularFolder {
            let parent = app.extractFolderName(app.extractParentFolderName(folder)) ?? ""
            organize = [action("rename", NBLocalization.text("Rename folder…"), "pencil") { [weak self] in
                self?.renameMenuTarget(title: title, path: "/reader/rename_folder",
                                      parameters: ["folder_name": title, "in_folder": parent], nameKey: "new_folder_name")
            }]
            deletion = [action("delete", NBLocalization.text("Delete folder…"), "trash", destructive: true) { [weak self] in
                self?.confirmMenuDeletion(title: title, path: "/reader/delete_folder",
                                         parameters: ["folder_to_delete": title, "in_folder": parent, "feed_id": feedIDs])
            }]
        }
        return [reading, tools, organize, deletion].filter { !$0.isEmpty }
    }

    private func submitMenuAction(_ path: String, parameters: [String: Any]) {
        // RowActionMenus.swift captures the long-pressed target instead of altering the open reader's collection.
        appDelegate.post("\(appDelegate.url!)\(path)", parameters: parameters, success: { [weak self] _, response in
            guard let self else { return }
            if let result = response as? [String: Any], let code = result["code"] as? Int, code < 0 {
                self.informError(result["message"] as? String ?? NBLocalization.text("Unable to complete this action."))
            } else {
                self.appDelegate.reloadFeedsView(false)
            }
        }, failure: { [weak self] _, error in self?.informError(error) })
    }

    private func renameMenuTarget(title: String, path: String, parameters: [String: Any], nameKey: String) {
        let alert = UIAlertController(title: String(format: NBLocalization.text("Rename %@"), title), message: nil, preferredStyle: .alert)
        alert.addTextField { $0.text = title }
        alert.addAction(UIAlertAction(title: NBLocalization.text("Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: NBLocalization.text("Rename"), style: .default) { [weak self, weak alert] _ in
            guard let name = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return }
            var values = parameters
            values[nameKey] = name
            self?.submitMenuAction(path, parameters: values)
        })
        present(alert, animated: true)
    }

    private func confirmMenuDeletion(title: String, path: String, parameters: [String: Any]) {
        let message = path == "/reader/delete_folder"
            ? NBLocalization.text("This deletes the folder and unsubscribes from sites that are not in another folder.")
            : NBLocalization.text("This removes the subscription from your feeds.")
        let alert = UIAlertController(title: String(format: NBLocalization.text("Delete %@?"), title), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NBLocalization.text("Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: NBLocalization.text("Delete"), style: .destructive) { [weak self] _ in
            self?.submitMenuAction(path, parameters: parameters)
        })
        present(alert, animated: true)
    }

    @objc func installFolderContextMenu(_ header: FolderTitleView) {
        header.addInteraction(UIContextMenuInteraction(delegate: self))
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard GesturePreferences.feedLongPressShowsMenu, let header = interaction.view as? FolderTitleView,
              let folders = appDelegate.dictFoldersArray as? [String], folders.indices.contains(Int(header.section)) else { return nil }
        let groups = feedActions(feedID: nil, folder: folders[Int(header.section)], source: header)
        guard !groups.isEmpty else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in RowActionMenus.menu(groups) }
    }
}
