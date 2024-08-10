//
//  StorySettings.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-04-04.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import Foundation

class StorySettings {
    let defaults = UserDefaults.standard
    
    enum Content: String, RawRepresentable {
        case title
        case short
        case medium
        case long
        
        static let titleLimit = 6
        
        static let contentLimit = 10
        
        var limit: Int {
            switch self {
                case .title:
                    return 6
                case .short:
                    return 2
                case .medium:
                    return 4
                case .long:
                    return 6
            }
        }
    }
    
    var content: Content {
        if let string = defaults.string(forKey: "story_list_preview_text_size"), let value = Content(rawValue: string) {
            return value
        } else {
            return .short
        }
    }
    
    enum Preview: String, RawRepresentable {
        case none
        case smallLeft = "small_left"
        case largeLeft = "large_left"
        case largeRight = "large_right"
        case smallRight = "small_right"
        
        var isLeft: Bool {
            return [.smallLeft, .largeLeft].contains(self)
        }
        
        var isSmall: Bool {
            return [.smallLeft, .smallRight].contains(self)
        }
    }
    
    var preview: Preview {
        if let string = defaults.string(forKey: "story_list_preview_images_size"), let value = Preview(rawValue: string) {
            return value
        } else {
            return .smallRight
        }
    }
    
    enum FontSize: String, RawRepresentable {
        case xs
        case small
        case medium
        case large
        case xl
        
        var offset: CGFloat {
            switch self {
                case .xs:
                    return -2
                case .small:
                    return -1
                case .medium:
                    return 0
                case .large:
                    return 1
                case .xl:
                    return 2
            }
        }
    }
    
    var fontSize: FontSize {
        if let string = defaults.string(forKey: "feed_list_font_size"), let value = FontSize(rawValue: string) {
            return value
        } else {
            return .medium
        }
    }
    
    enum Spacing: String, RawRepresentable {
        case compact
        case comfortable
    }
    
    var spacing: Spacing {
        if let string = defaults.string(forKey: "feed_list_spacing"), let value = Spacing(rawValue: string) {
            return value
        } else {
            return .comfortable
        }
    }
    
    var gridColumns: Int {
        guard let pref = UserDefaults.standard.string(forKey: "grid_columns"), let columns = Int(pref) else {
            if NewsBlurAppDelegate.shared.isCompactWidth {
                return 1
            } else if NewsBlurAppDelegate.shared.isPortrait || NewsBlurAppDelegate.shared.isPhone {
                return 2
            } else {
                return 4
            }
        }
        
        if NewsBlurAppDelegate.shared.isPortrait, columns > 3 {
            return 3
        }
        
        return columns
    }
    
    var gridHeight: CGFloat {
        guard let pref = UserDefaults.standard.string(forKey: "grid_height") else {
            return 400
        }
        
        switch pref {
            case "xs":
                return 250
            case "short":
                return 300
            case "tall":
                return 500
            case "xl":
                return 600
            default:
                return 400
        }
    }
}
