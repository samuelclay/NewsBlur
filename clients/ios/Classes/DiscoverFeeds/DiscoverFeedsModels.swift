//
//  DiscoverFeedsModels.swift
//  NewsBlur
//
//  Created by Claude on 2025-02-11.
//  Copyright 2025 NewsBlur. All rights reserved.
//

import Foundation

struct DiscoverStory: Identifiable {
    let id: String
    let title: String
    let excerpt: String
    let authors: String
    let date: Date?
    let permalink: String
    let imageUrls: [String]

    init?(dict: [String: Any]) {
        guard let hash = dict["story_hash"] as? String else { return nil }
        self.id = hash
        self.title = Self.previewText(from: dict["story_title"] as? String ?? "")
        self.excerpt = Self.previewText(from: dict["story_content"] as? String ?? "")
        self.authors = dict["story_authors"] as? String ?? ""
        self.permalink = dict["story_permalink"] as? String ?? ""

        if let dateString = dict["story_date"] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            self.date = formatter.date(from: dateString)
        } else {
            self.date = nil
        }

        if let images = dict["image_urls"] as? [String] {
            self.imageUrls = images
        } else {
            self.imageUrls = []
        }
    }

    private static func previewText(from html: String) -> String {
        guard !html.isEmpty else { return "" }

        // DiscoverFeedsModels.swift bounds preview parsing and reuses NSString+HTML's non-rendering scanner.
        let visibleHTML = String(html.prefix(12_000))
            .replacingOccurrences(of: "(?is)<(script|style)\\b[^>]*>.*?(?:</\\1\\s*>|\\z)",
                                  with: " ", options: .regularExpression)
            .replacingOccurrences(of: "(?i)<(?:br|hr)\\b[^>]*>",
                                  with: " ", options: .regularExpression)
            .replacingOccurrences(of: "<(?=\\s|\\d)", with: "&lt;", options: .regularExpression)
        let plainText = (visibleHTML as NSString).convertingHTMLToPlainText() ?? ""
        let normalized = plainText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(normalized.prefix(500))
    }
}
