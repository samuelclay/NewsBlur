//
//  WidgetStory.swift
//  Widget Extension
//
//  Created by David Sinclair on 2019-11-29.
//  Copyright © 2021 NewsBlur. All rights reserved.
//

import SwiftUI

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
    
    /// The thumbnail image data, or `nil` if none.
    let imageData: Data?
    
    /// The thumbnail image, or `nil` if none.
    let image: UIImage?
    
    /// Keys for the dictionary representation.
    struct DictionaryKeys {
        static let id = "story_hash"
        static let feed = "story_feed_id"
        static let date = "short_parsed_date"
        static let author = "story_authors"
        static let title = "story_title"
        static let content = "story_content"
        static let imageData = "select_thumbnail_data"
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
        
        if let base64 = dictionary[DictionaryKeys.imageData] as? String {
            imageData = Data(base64Encoded: base64)
        } else {
            imageData = nil
        }
        
        if let data = imageData {
            image = UIImage(data: data)
        } else {
            image = nil
        }
    }
    
    /// Initializer for a sample.
    ///
    /// - Parameter title: The title of the sample.
    /// - Parameter feed: The feed identifier.
    init(sample title: String, feed: String) {
        id = UUID().uuidString
        self.feed = feed
        date = "2021-08-09"
        author = "Sample"
        self.title = title
        content = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur nec ornare dolor. Vivamus porta mi nec libero convallis tempus. Cras semper, ante et pretium vulputate, risus urna venenatis magna, vitae fringilla ipsum ante ut augue. Cras euismod, eros convallis scelerisque congue, massa sem elementum sem, ut condimentum est tortor id mauris."
        imageData = nil
        image = UIImage(systemName: "globe.americas.fill")
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
        case imageData = "imageData"
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
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        
        if let data = imageData {
            image = UIImage(data: data)
        } else {
            image = nil
        }
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
        try container.encodeIfPresent(imageData, forKey: .imageData)
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
