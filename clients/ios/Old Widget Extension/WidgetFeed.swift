//
//  WidgetFeed.swift
//  Widget Extension
//
//  Created by David Sinclair on 2019-12-23.
//  Copyright © 2019 NewsBlur. All rights reserved.
//

import UIKit

/// A feed to display in the widget.
struct Feed: Identifiable {
    /// The feed ID.
    let id: String
    
    /// The name of the feed.
    let title: String
    
    /// The left bar color.
    let leftColor: UIColor
    
    /// The right bar color.
    let rightColor: UIColor
    
    /// Keys for the dictionary representation.
    struct DictionaryKeys {
        static let id = "id"
        static let title = "feed_title"
        static let leftColor = "favicon_color"
        static let rightColor = "favicon_fade"
    }
    
    /// A dictionary representation of the feed.
    typealias Dictionary = [String : Any]
    
    /// Initializer from a dictionary.
    ///
    /// - Parameter dictionary: Dictionary representation.
    init(from dictionary: Dictionary) {
        id = dictionary[DictionaryKeys.id] as? String ?? ""
        title = dictionary[DictionaryKeys.title] as? String ?? ""
        
        if let fadeHex = dictionary[DictionaryKeys.leftColor] as? String {
            leftColor = Self.from(hexString: fadeHex)
        } else {
            leftColor = Self.from(hexString: "707070")
        }
        
        if let otherHex = dictionary[DictionaryKeys.rightColor] as? String {
            rightColor = Self.from(hexString: otherHex)
        } else {
            rightColor = Self.from(hexString: "505050")
        }
    }
    
    /// Given a hex string, returns the corresponding color.
    ///
    /// - Parameter hexString: The hex string.
    /// - Returns: The color equivalent.
    static func from(hexString: String) -> UIColor {
        var red: Double = 0
        var green: Double = 0
        var blue: Double = 0
        var alpha: Double = 1
        let length = hexString.count
        let scanner = Scanner(string: hexString)
        var hex: UInt64 = 0
        
        scanner.scanHexInt64(&hex)
        
        if length == 8 {
            red = Double((hex & 0xFF000000) >> 24) / 255
            green = Double((hex & 0x00FF0000) >> 16) / 255
            blue = Double((hex & 0x0000FF00) >>  8) / 255
            alpha = Double( hex & 0x000000FF) / 255
        } else if length == 6 {
            red = Double((hex & 0xFF0000) >> 16) / 255
            green = Double((hex & 0x00FF00) >>  8) / 255
            blue = Double( hex & 0x0000FF) / 255
        }
        
        print("Reading color from '\(hexString)': red: \(red), green: \(green), blue: \(blue), alpha: \(alpha)")
        
        return UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }
}

extension Feed: Equatable {
    static func ==(lhs: Feed, rhs: Feed) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Feed: CustomStringConvertible {
    var description: String {
        return "Feed \(title) (\(id))"
    }
}
