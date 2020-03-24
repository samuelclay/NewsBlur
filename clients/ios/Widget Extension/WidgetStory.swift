//
//  WidgetStory.swift
//  Widget Extension
//
//  Created by David Sinclair on 2019-11-29.
//  Copyright © 2019 NewsBlur. All rights reserved.
//

import UIKit

/// A story to display in the widget.
struct Story: Codable, Identifiable {
    /// The version number.
    let version = 1
    
    /// The story hash.
    let id: String
    
    /// The feed ID.
    let feed: String
    
    /// The date and/or time as a string.
    let date: String
    
    /// The author of the story.
    let author: String
    
    /// The title of the story.
    let title: String
    
    /// The content of the story.
    let content: String
    
    /// The URL of the image, or `nil` if none.
    let imageURL: URL?
    
    /// Keys for the dictionary representation.
    struct DictionaryKeys {
        static let id = "story_hash"
        static let feed = "story_feed_id"
        static let date = "short_parsed_date"
        static let author = "story_authors"
        static let title = "story_title"
        static let content = "story_content"
        static let imageURLs = "image_urls"
        static let secureImageURLs = "secure_image_thumbnails"
    }
    
    /// Initializer from a dictionary.
    ///
    /// - Parameter dictionary: Dictionary from the server.
    init(from dictionary: [String : Any]) {
        id = dictionary[DictionaryKeys.id] as? String ?? ""
        feed = dictionary[DictionaryKeys.feed] as? String ?? "\(dictionary[DictionaryKeys.feed] as? Int ?? 0)"
        date = dictionary[DictionaryKeys.date] as? String ?? ""
        author = dictionary[DictionaryKeys.author] as? String ?? ""
        title = dictionary[DictionaryKeys.title] as? String ?? ""
        content = dictionary[DictionaryKeys.content] as? String ?? ""
        
        if let imageURLs = dictionary[DictionaryKeys.imageURLs] as? [String], let first = imageURLs.first, let secureImages = dictionary[DictionaryKeys.secureImageURLs] as? [String : String], let url = secureImages[first] {
            imageURL = URL(string: url)
        } else {
            imageURL = nil
        }
    }
    
    /// Keys for the codable representation.
    enum CodingKeys: String, CodingKey {
        case version = "version"
        case id = "id"
        case feed = "feed"
        case date = "date"
        case author = "author"
        case title = "title"
        case content = "content"
        case imageURL = "imageURL"
    }
    
    /// Initializer to load from the JSON data.
    ///
    /// - Parameter decoder: The decoder from which to read data.
    /// - Throws: An error if the data is invalid.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        feed = try container.decode(String.self, forKey: .feed)
        date = try container.decode(String.self, forKey: .date)
        author = try container.decode(String.self, forKey: .author)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
    }
    
    /// Encodes the story into the given encoder.
    ///
    /// - Parameter encoder: The encoder to which to write data.
    /// - Throws: An error if the data is invalid.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(version, forKey: .version)
        try container.encode(id, forKey: .id)
        try container.encode(feed, forKey: .feed)
        try container.encode(date, forKey: .date)
        try container.encode(author, forKey: .author)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
    }
}

extension Story: Equatable {
    static func ==(lhs: Story, rhs: Story) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Story: CustomStringConvertible {
    var description: String {
        return "Story \(title) by \(author) (\(id))"
    }
}
