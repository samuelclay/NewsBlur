//
//  DiscoverColors.swift
//  NewsBlur
//
//  Created by Claude on 2026-03-05.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, *)
struct DiscoverColors {
    static var background: Color {
        themedColor(light: 0xEAECE6, sepia: 0xF3E2CB, medium: 0x3D3D3D, dark: 0x1A1A1A)
    }

    static var cardBackground: Color {
        themedColor(light: 0xFFFFFF, sepia: 0xFAF5ED, medium: 0x4A4A4A, dark: 0x2A2A2A)
    }

    static var border: Color {
        themedColor(light: 0xD0D2CC, sepia: 0xD4C8B8, medium: 0x5A5A5A, dark: 0x404040)
    }

    static var textPrimary: Color {
        themedColor(light: 0x5E6267, sepia: 0x5C4A3D, medium: 0xE0E0E0, dark: 0xE8E8E8)
    }

    static var textSecondary: Color {
        themedColor(light: 0x697168, sepia: 0x8B7B6B, medium: 0xA0A0A0, dark: 0xB0B0B0)
    }

    static var textFieldBackground: Color {
        themedColor(light: 0xFFFFFF, sepia: 0xFAF5ED, medium: 0x555555, dark: 0x333333)
    }

    static var errorText: Color {
        themedColor(light: 0xCC0000, sepia: 0xCC0000, medium: 0xFF4444, dark: 0xFF4444)
    }

    static let accent = Color(red: 0.26, green: 0.46, blue: 0.18)

    static func freshnessDot(_ status: DiscoverFeedFreshness.Status) -> Color {
        switch status {
        case .active: return colorFromHex(0x4CAF50)
        case .stale: return colorFromHex(0xF9A825)
        case .noStories: return colorFromHex(0x90A4AE)
        }
    }

    static func freshnessText(_ status: DiscoverFeedFreshness.Status) -> Color {
        // DiscoverColors.swift follows reader.css and darkmode.css freshness labels in every iOS theme.
        switch status {
        case .active: return themedColor(light: 0x4CAF50, sepia: 0x4CAF50, medium: 0x66BB6A, dark: 0x66BB6A)
        case .stale: return themedColor(light: 0xB8860B, sepia: 0xB8860B, medium: 0xFFB74D, dark: 0xFFB74D)
        case .noStories: return themedColor(light: 0x90A4AE, sepia: 0x90A4AE, medium: 0x78909C, dark: 0x78909C)
        }
    }

    static var tryButtonBackground: Color {
        themedColor(light: 0xF0F1ED, sepia: 0xF0E8DC, medium: 0x555555, dark: 0x3A3A3A)
    }

    static var tryButtonText: Color {
        themedColor(light: 0x5E6267, sepia: 0x5C4A3D, medium: 0xD0D0D0, dark: 0xD8D8D8)
    }

    static var addButtonBackground: Color {
        themedColor(light: 0x6F8299, sepia: 0x6F8299, medium: 0x5A7090, dark: 0x4A6080)
    }

    static var subcategoryBackground: Color {
        themedColor(light: 0xDFE2DA, sepia: 0xE8D9C4, medium: 0x434343, dark: 0x232323)
    }

    static var bannerBackground: Color {
        themedColor(light: 0xF0F0FA, sepia: 0xF0EAFA, medium: 0x3A3A4A, dark: 0x242430)
    }

    static var bannerBorder: Color {
        themedColor(light: 0xD8D8F0, sepia: 0xD0C8E0, medium: 0x4A4A60, dark: 0x3A3A50)
    }

    static var bannerProgressBackground: Color {
        themedColor(light: 0xE0E0F0, sepia: 0xE0D8EE, medium: 0x404055, dark: 0x303040)
    }

    static var bannerProgressLabel: Color {
        themedColor(light: 0x8B8B8B, sepia: 0x8B7B6B, medium: 0x707070, dark: 0x707070)
    }

    static var linkColor: Color {
        themedColor(light: 0x405BA8, sepia: 0x405BA8, medium: 0x3B7CC5, dark: 0x3B7CC5)
    }

    // DiscoverColors.swift follows the .NB-describe-score pills in reader.css and darkmode.css.
    static func scoreBackground(_ tone: DescribeResult.ScoreTone) -> Color {
        switch tone {
        case .high: return themedColor(light: 0xE3F3DB, sepia: 0xE3F3DB, medium: 0x2F4A25, dark: 0x2F4A25)
        case .medium: return themedColor(light: 0xFFF1D6, sepia: 0xFFF1D6, medium: 0x4A3A1A, dark: 0x4A3A1A)
        case .low: return themedColor(light: 0xF2F2F2, sepia: 0xF0E8DC, medium: 0x333333, dark: 0x333333)
        case .pending: return themedColor(light: 0xEEF2F8, sepia: 0xEEF2F8, medium: 0x2A3443, dark: 0x2A3443)
        }
    }

    static func scoreText(_ tone: DescribeResult.ScoreTone) -> Color {
        switch tone {
        case .high: return themedColor(light: 0x2F6B17, sepia: 0x2F6B17, medium: 0x9FD67F, dark: 0x9FD67F)
        case .medium: return themedColor(light: 0x8A5A00, sepia: 0x8A5A00, medium: 0xF0C56B, dark: 0xF0C56B)
        case .low: return themedColor(light: 0x777777, sepia: 0x8B7B6B, medium: 0x999999, dark: 0x999999)
        case .pending: return themedColor(light: 0x5C89C9, sepia: 0x5C89C9, medium: 0x8FB4EA, dark: 0x8FB4EA)
        }
    }

    // DiscoverColors.swift follows the .NB-describe-source badges: blue for the web, grey for the index.
    static func sourceBackground(fromWeb: Bool) -> Color {
        fromWeb ? themedColor(light: 0xEAF0FB, sepia: 0xEAF0FB, medium: 0x27354A, dark: 0x27354A)
                : themedColor(light: 0xF2F4F6, sepia: 0xF0E8DC, medium: 0x333333, dark: 0x333333)
    }

    static func sourceText(fromWeb: Bool) -> Color {
        fromWeb ? themedColor(light: 0x2F5F9E, sepia: 0x2F5F9E, medium: 0x8FB4EA, dark: 0x8FB4EA)
                : themedColor(light: 0x777777, sepia: 0x8B7B6B, medium: 0x999999, dark: 0x999999)
    }

    // DiscoverColors.swift follows the .NB-describe-step states: green once done, blue while current, grey ahead.
    static var stepDone: Color {
        themedColor(light: 0x5BA03A, sepia: 0x5BA03A, medium: 0x7CC45A, dark: 0x7CC45A)
    }

    static var stepCurrent: Color {
        themedColor(light: 0x5C89C9, sepia: 0x5C89C9, medium: 0x8FB4EA, dark: 0x8FB4EA)
    }

    static var stepUpcoming: Color {
        themedColor(light: 0xD0D4D8, sepia: 0xD4C8B8, medium: 0x5A5A5A, dark: 0x404040)
    }

    static func themedColor(light: Int, sepia: Int, medium: Int, dark: Int) -> Color {
        guard let themeManager = ThemeManager.shared else {
            return colorFromHex(light)
        }

        let effectiveTheme = themeManager.effectiveTheme

        let hex: Int
        if effectiveTheme == ThemeStyleMedium || effectiveTheme == "medium" {
            hex = medium
        } else if effectiveTheme == ThemeStyleDark || effectiveTheme == "dark" {
            hex = dark
        } else if effectiveTheme == ThemeStyleSepia || effectiveTheme == "sepia" {
            hex = sepia
        } else {
            hex = light
        }
        return colorFromHex(hex)
    }

    static func colorFromHex(_ hex: Int) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}
