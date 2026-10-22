//
//  ListenTheme.swift
//  NewsBlur
//
//  Created by Claude on 2026-10-21.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import SwiftUI
import UIKit

/// ListenTheme.swift gives the Listen screens colors for each NewsBlur theme (light, warm, medium, dark).
enum ListenColors {
    static var sheetBackground: Color { themed(light: 0xF0F2ED, sepia: 0xF3E8D8, medium: 0x2C2C2E, dark: 0x111111) }
    static var card: Color { themed(light: 0xFFFFFF, sepia: 0xFAF5ED, medium: 0x3A3A3C, dark: 0x1E1E1E) }
    static var miniBar: Color { themed(light: 0xFFFFFF, sepia: 0xFBF6EE, medium: 0x48484A, dark: 0x262626) }
    static var textPrimary: Color { themed(light: 0x1C1C1E, sepia: 0x3C3226, medium: 0xF2F2F7, dark: 0xE8E8E8) }
    static var textSecondary: Color { themed(light: 0x6E6E73, sepia: 0x8B7B6B, medium: 0xAEAEB2, dark: 0x8F8F94) }
    static var border: Color { themed(light: 0xD1D1D6, sepia: 0xD4C8B8, medium: 0x545458, dark: 0x333333) }
    static var track: Color { themed(light: 0xE3E5E0, sepia: 0xE6D8C4, medium: 0x5A5A5E, dark: 0x3A3A3A) }
    static var accent: Color { themed(light: 0x709E5D, sepia: 0x6E865F, medium: 0x8BBF74, dark: 0x8BBF74) }
    static var error: Color { themed(light: 0xC0392B, sepia: 0xB0412E, medium: 0xFF7B6B, dark: 0xFF7B6B) }
    static var errorBackground: Color { themed(light: 0xFCEBE9, sepia: 0xF6DDD3, medium: 0x4A3533, dark: 0x2E1C1A) }
    static var archivePurple: Color { Color(red: 0.55, green: 0.35, blue: 0.85) }
    static var archivePurpleLight: Color { Color(red: 0.75, green: 0.55, blue: 0.95) }

    static var colorScheme: ColorScheme { isDark ? .dark : .light }

    static var interfaceStyle: UIUserInterfaceStyle { isDark ? .dark : .light }

    static var isDark: Bool {
        let theme = ThemeManager.shared?.effectiveTheme ?? ThemeStyleLight
        return theme == ThemeStyleMedium || theme == ThemeStyleDark
    }

    static func uiColor(light: Int, sepia: Int, medium: Int, dark: Int) -> UIColor {
        UIColor(hex(light: light, sepia: sepia, medium: medium, dark: dark))
    }

    private static func themed(light: Int, sepia: Int, medium: Int, dark: Int) -> Color {
        hex(light: light, sepia: sepia, medium: medium, dark: dark)
    }

    private static func hex(light: Int, sepia: Int, medium: Int, dark: Int) -> Color {
        let theme = ThemeManager.shared?.effectiveTheme ?? ThemeStyleLight
        let value: Int
        if theme == ThemeStyleMedium {
            value = medium
        } else if theme == ThemeStyleDark {
            value = dark
        } else if theme == ThemeStyleSepia {
            value = sepia
        } else {
            value = light
        }
        return Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
                     blue: Double(value & 0xFF) / 255)
    }
}

/// Lets the Listen SwiftUI views redraw when the NewsBlur theme changes (SplitViewController.swift updateTheme).
final class ListenThemeObserver: ObservableObject {
    static let shared = ListenThemeObserver()
    static let didChange = Notification.Name("ListenThemeDidChange")

    @Published private(set) var version = 0

    func themeChanged() {
        version += 1
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }
}

/// Formats Listen times as 1:05 or 1:02:05 (ListenTheme.swift).
enum ListenFormat {
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds.isFinite ? seconds : 0).rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let remainder = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%d:%02d", minutes, remainder)
    }

    /// "2 hr 5 min" in the interface language, for monthly allowances.
    static func allowance(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .short
        formatter.zeroFormattingBehavior = .dropAll
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: NBLocalization.resolvedLanguage)
        formatter.calendar = calendar
        return formatter.string(from: max(0, seconds)) ?? ListenFormat.clock(seconds)
    }

    static func speed(_ speed: Double) -> String {
        String(format: NBLocalization.text("%@×"), ListenPreferences.numberString(speed))
    }

    /// "2nd" in the interface language, for a story's place in Up Next.
    static func ordinal(_ position: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        formatter.locale = Locale(identifier: NBLocalization.resolvedLanguage)
        return formatter.string(from: NSNumber(value: position)) ?? NBLocalization.formattedCount(position)
    }
}
