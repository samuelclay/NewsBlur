//
//  ClassifierScope.swift
//  NewsBlur
//
//  Created by Samuel Clay on 2026-03-03.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import SwiftUI

/// The scope at which a classifier operates: per-feed, per-folder, or globally.
enum ClassifierScope: String, CaseIterable {
    case feed = "feed"
    case folder = "folder"
    case global = "global"

    var iconName: String {
        switch self {
        case .feed: return "dot.radiowaves.left.and.right"
        case .folder: return "folder"
        case .global: return "globe"
        }
    }

    /// Color when the scope icon is active on a neutral (lighter gray) capsule.
    var activeColor: Color {
        switch self {
        case .feed: return Color(white: 0.35)
        case .folder: return Color(red: 0.231, green: 0.510, blue: 0.965) // #3B82F6
        case .global: return Color(red: 0.545, green: 0.361, blue: 0.965) // #8B5CF6
        }
    }

    /// Lighter color for active scope icon on a like/dislike (green/red) capsule.
    var activeLightColor: Color {
        switch self {
        case .feed: return Color(white: 0.9)
        case .folder: return Color(red: 0.576, green: 0.773, blue: 0.992) // #93C5FD
        case .global: return Color(red: 0.769, green: 0.710, blue: 0.992) // #C4B5FD
        }
    }

    /// Dark mode active color.
    var activeDarkColor: Color {
        switch self {
        case .feed: return Color(white: 0.67) // #AAA
        case .folder: return Color(red: 0.376, green: 0.647, blue: 0.980) // #60A5FA
        case .global: return Color(red: 0.655, green: 0.545, blue: 0.980) // #A78BFA
        }
    }

    /// Returns a label like "Feed Title", "Folder Text", "Global Author".
    func label(for classifierType: String) -> String {
        switch self {
        case .feed: return "Feed \(classifierType)"
        case .folder: return "Folder \(classifierType)"
        case .global: return "Global \(classifierType)"
        }
    }
}

struct ClassifierScopeInfo: Equatable {
    let scope: ClassifierScope
    let folderName: String

    init(scope: ClassifierScope = .feed, folderName: String = "") {
        self.scope = scope
        self.folderName = folderName
    }
}

/// ClassifierScope.swift names a folder scope by the full path apps/reader/models.py flatten_folders gives the folder
/// ("Tech - Swift"), since apps/analyzer/models.py matches folder classifiers to sites by that path. NewsBlurAppDelegate.m
/// keys its folders differently: FeedsObjCViewController.m fixFolderNames turns "Tech - Swift" into "Tech ▸ Swift", and
/// FeedsViewController.swift addSubfolderFeeds lists every subfolder's sites under each of its parents too.
enum ClassifierFolderPath {
    static let nativeSeparator = " ▸ "
    static let serverSeparator = " - "

    /// The dictFolders keys in NewsBlurAppDelegate.m that hold sites but aren't folders a classifier can scope to.
    /// "everything" is the server's " " folder of sites outside any folder.
    private static let nonFolderKeys: Set<String> = [
        "everything", "dashboard", "infrequent", "daily_briefing", "read_stories", "saved_searches", "saved_stories",
        "river_global", "river_blurblogs", "widget_stories",
    ]

    static func isFolder(_ nativePath: String) -> Bool {
        !nativePath.isEmpty && !nonFolderKeys.contains(nativePath) && !nativePath.hasPrefix("trending:")
    }

    /// "Tech ▸ Swift" becomes "Tech - Swift".
    static func serverPath(fromNative nativePath: String) -> String {
        nativePath.replacingOccurrences(of: nativeSeparator, with: serverSeparator)
    }

    /// The server path of the folder holding the site itself, or "" for a site outside any folder. A parent folder
    /// also lists its subfolders' sites, so it only counts when none of its subfolders hold the site.
    static func serverPath(forFeed feedId: String, folderOrder: [String], folders: [String: Any]) -> String {
        let holding = folderOrder.filter { isFolder($0) && feedIds(in: folders[$0]).contains(feedId) }
        let innermost = holding.first { folder in !holding.contains { $0.hasPrefix(folder + nativeSeparator) } }
        return innermost.map(serverPath(fromNative:)) ?? ""
    }

    /// The native folders a folder scope covers: the folder its server path names and every subfolder inside it.
    static func nativeFolders(coveredBy serverPath: String, in nativePaths: [String]) -> [String] {
        let roots = nativePaths.filter { isFolder($0) && self.serverPath(fromNative: $0) == serverPath }
        return nativePaths.filter { path in roots.contains { path == $0 || path.hasPrefix($0 + nativeSeparator) } }
    }

    /// A dictFolders entry's site ids, which arrive as numbers or strings.
    static func feedIds(in folder: Any?) -> [String] {
        (folder as? [Any] ?? []).map { "\($0)" }
    }
}

enum ClassifierScopeResolver {
    static func overrideKey(type: String, name: String) -> String {
        "\(type):\(name)"
    }

    static func effectiveScope(
        overrides: [String: ClassifierScope],
        type: String,
        name: String,
        default defaultScope: ClassifierScope
    ) -> ClassifierScope {
        overrides[overrideKey(type: type, name: name)] ?? defaultScope
    }

    /// apps/analyzer/models.py get_classifiers_for_user files a regex's scope with its plain classifiers' scopes.
    static func metadataKey(for classifierKey: String) -> String {
        switch classifierKey {
        case "titles", "title_regex":
            return "titles_scope"
        case "texts", "text_regex":
            return "texts_scope"
        case "urls", "url_regex":
            return "urls_scope"
        case "authors", "author_regex":
            return "authors_scope"
        case "tags":
            return "tags_scope"
        default:
            return "\(classifierKey)_scope"
        }
    }

    static func resolveInfo(
        from classifiers: [AnyHashable: Any]?,
        classifierKey: String,
        name: String
    ) -> ClassifierScopeInfo {
        guard let metadata = classifiers?[metadataKey(for: classifierKey)] as? [AnyHashable: Any],
              let info = metadata[name] as? [AnyHashable: Any],
              let rawScope = info["scope"] as? String,
              let scope = ClassifierScope(rawValue: rawScope) else {
            return ClassifierScopeInfo()
        }

        return ClassifierScopeInfo(
            scope: scope,
            folderName: info["folder_name"] as? String ?? ""
        )
    }
}
