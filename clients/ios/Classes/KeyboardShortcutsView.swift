//
//  KeyboardShortcutsView.swift
//  NewsBlur
//
//  Created by Claude on 2026-03-18.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import SwiftUI

// MARK: - Keyboard Shortcuts Colors (Theme-aware)

@available(iOS 15.0, *)
private struct ShortcutsColors {
    static var background: Color {
        themedColor(light: 0xF0F2ED, sepia: 0xF3E2CB, medium: 0x2C2C2E, dark: 0x1C1C1E)
    }

    static var cardBackground: Color {
        themedColor(light: 0xFFFFFF, sepia: 0xFAF5ED, medium: 0x3A3A3C, dark: 0x2C2C2E)
    }

    static var textPrimary: Color {
        themedColor(light: 0x1C1C1E, sepia: 0x3C3226, medium: 0xF2F2F7, dark: 0xF2F2F7)
    }

    static var textSecondary: Color {
        themedColor(light: 0x6E6E73, sepia: 0x8B7B6B, medium: 0xAEAEB2, dark: 0x98989D)
    }

    static var keyBackground: Color {
        themedColor(light: 0xE8E8ED, sepia: 0xE8DED0, medium: 0x48484A, dark: 0x38383A)
    }

    static var keyBorder: Color {
        themedColor(light: 0xC8C8CD, sepia: 0xD4C8B8, medium: 0x636366, dark: 0x545458)
    }

    static var keyShadow: Color {
        themedColor(light: 0xAAAAAF, sepia: 0xB4A898, medium: 0x1C1C1E, dark: 0x000000)
    }

    static var sectionHeader: Color {
        themedColor(light: 0x8F918B, sepia: 0x8B7B6B, medium: 0x8F918B, dark: 0x8F918B)
    }

    static var border: Color {
        themedColor(light: 0xD1D1D6, sepia: 0xD4C8B8, medium: 0x545458, dark: 0x48484A)
    }

    static var tabActive: Color {
        themedColor(light: 0x4A7E47, sepia: 0x4A7E47, medium: 0x6BAD68, dark: 0x6BAD68)
    }

    private static func themedColor(light: Int, sepia: Int, medium: Int, dark: Int) -> Color {
        guard let themeManager = ThemeManager.shared else {
            return colorFromHex(light)
        }

        let hex: Int
        let effectiveTheme = themeManager.effectiveTheme

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

    private static func colorFromHex(_ hex: Int) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

// MARK: - Data Model

@available(iOS 15.0, *)
private struct KeyboardShortcut: Identifiable {
    let id = UUID()
    let keys: [String]
    let description: String
}

@available(iOS 15.0, *)
private struct ShortcutSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let shortcuts: [KeyboardShortcut]
}

// MARK: - Shortcut Data

@available(iOS 15.0, *)
private func shortcutSections() -> [ShortcutSection] {
    [
        ShortcutSection(title: "General", icon: "keyboard", shortcuts: [
            KeyboardShortcut(keys: ["?"], description: "Keyboard shortcuts"),
            KeyboardShortcut(keys: ["\u{21E7}", "D"], description: "Open Dashboard"),
            KeyboardShortcut(keys: ["\u{21E7}", "E"], description: "Open All Stories"),
            KeyboardShortcut(keys: ["\u{2318}", "F"], description: "Find in feed"),
            KeyboardShortcut(keys: ["\u{2318}", "\u{2325}", "F"], description: "Find in sites"),
            KeyboardShortcut(keys: ["\u{2318}", "A"], description: "Add site"),
        ]),
        ShortcutSection(title: "Sites", icon: "list.bullet", shortcuts: [
            KeyboardShortcut(keys: ["\u{2325}", "\u{2193}"], description: "Next site"),
            KeyboardShortcut(keys: ["\u{2325}", "\u{2191}"], description: "Previous site"),
            KeyboardShortcut(keys: ["\u{21E7}", "\u{2193}"], description: "Next folder"),
            KeyboardShortcut(keys: ["\u{21E7}", "\u{2191}"], description: "Previous folder"),
            KeyboardShortcut(keys: ["\u{21E7}", "A"], description: "Mark all as read"),
            KeyboardShortcut(keys: ["\u{21E7}", "T"], description: "Open story trainer"),
        ]),
        ShortcutSection(title: "Stories", icon: "doc.text", shortcuts: [
            KeyboardShortcut(keys: ["\u{2193}"], description: "Next story"),
            KeyboardShortcut(keys: ["J"], description: "Next story"),
            KeyboardShortcut(keys: ["\u{2191}"], description: "Previous story"),
            KeyboardShortcut(keys: ["K"], description: "Previous story"),
            KeyboardShortcut(keys: ["N"], description: "Next unread story"),
            KeyboardShortcut(keys: ["\u{21E7}", "\u{21A9}"], description: "Text view"),
            KeyboardShortcut(keys: ["space"], description: "Page down"),
            KeyboardShortcut(keys: ["\u{21E7}", "space"], description: "Page up"),
            KeyboardShortcut(keys: ["U"], description: "Toggle read/unread"),
            KeyboardShortcut(keys: ["S"], description: "Save/unsave story"),
            KeyboardShortcut(keys: ["O"], description: "Open in browser"),
            KeyboardShortcut(keys: ["\u{21E7}", "S"], description: "Share story"),
            KeyboardShortcut(keys: ["C"], description: "Scroll to comments"),
            KeyboardShortcut(keys: ["T"], description: "Open story trainer"),
        ]),
    ]
}

// MARK: - Key Cap View

@available(iOS 15.0, *)
private struct KeyCapView: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: isWideKey ? 10 : 13, weight: .medium, design: .rounded))
            .foregroundColor(ShortcutsColors.textPrimary)
            .frame(minWidth: isWideKey ? 38 : 24, minHeight: 24)
            .padding(.horizontal, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(ShortcutsColors.keyBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(ShortcutsColors.keyBorder, lineWidth: 1)
            )
            .shadow(color: ShortcutsColors.keyShadow.opacity(0.3), radius: 0, x: 0, y: 1)
    }

    private var isWideKey: Bool {
        label == "space" || label.count > 3
    }
}

// MARK: - Shortcut Row View

@available(iOS 15.0, *)
private struct ShortcutRowView: View {
    let shortcut: KeyboardShortcut

    var body: some View {
        HStack {
            Text(shortcut.description)
                .font(.system(size: 15))
                .foregroundColor(ShortcutsColors.textPrimary)
            Spacer()
            HStack(spacing: 3) {
                ForEach(Array(shortcut.keys.enumerated()), id: \.offset) { _, key in
                    KeyCapView(label: key)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Main View

@available(iOS 15.0, *)
struct KeyboardShortcutsView: View {
    @State private var selectedTab = 0
    let onDismiss: (() -> Void)?

    private let sections = shortcutSections()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                tabBar
                    .padding(.top, 8)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        let section = sections[selectedTab]
                        ForEach(Array(section.shortcuts.enumerated()), id: \.element.id) { index, shortcut in
                            ShortcutRowView(shortcut: shortcut)
                                .padding(.horizontal, 20)

                            if index < section.shortcuts.count - 1 {
                                Divider()
                                    .background(ShortcutsColors.border)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(ShortcutsColors.cardBackground)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .background(ShortcutsColors.background.ignoresSafeArea())
            .navigationTitle("Keyboard Shortcuts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss?()
                    }
                    .foregroundColor(ShortcutsColors.tabActive)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: section.icon)
                            .font(.system(size: 16))
                        Text(section.title)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(selectedTab == index ? ShortcutsColors.tabActive : ShortcutsColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedTab == index ? ShortcutsColors.tabActive.opacity(0.12) : Color.clear)
                    )
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - UIKit Hosting Controller

@available(iOS 15.0, *)
@objcMembers class KeyboardShortcutsHostingController: UIViewController {
    private var hostingController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHostingController()
    }

    private func setupHostingController() {
        let shortcutsView = KeyboardShortcutsView(onDismiss: { [weak self] in
            self?.dismiss(animated: true)
        })

        let hosting = UIHostingController(rootView: shortcutsView)
        hostingController = hosting

        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        hosting.didMove(toParent: self)
    }
}
