//
//  DiscoverFeedsView.swift
//  NewsBlur
//
//  Created by Claude on 2025-02-11.
//  Copyright 2025 NewsBlur. All rights reserved.
//

import SwiftUI

// MARK: - Theme Colors (reuse AskAI pattern)

@available(iOS 15.0, *)
private struct DiscoverColors {
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
        themedColor(light: 0x90928B, sepia: 0x8B7B6B, medium: 0xA0A0A0, dark: 0xB0B0B0)
    }

    static let accent = Color(red: 0.416, green: 0.659, blue: 0.310) // #6AA84F

    static var tryButtonBackground: Color {
        themedColor(light: 0xF0F1ED, sepia: 0xF0E8DC, medium: 0x555555, dark: 0x3A3A3A)
    }

    static var tryButtonText: Color {
        themedColor(light: 0x5E6267, sepia: 0x5C4A3D, medium: 0xD0D0D0, dark: 0xD8D8D8)
    }

    private static func themedColor(light: Int, sepia: Int, medium: Int, dark: Int) -> Color {
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

    private static func colorFromHex(_ hex: Int) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

// MARK: - Main View

@available(iOS 15.0, *)
struct DiscoverFeedsView: View {
    @ObservedObject var viewModel: DiscoverFeedsViewModel
    @StateObject private var themeObserver = AskAIThemeObserver()
    var onDismiss: () -> Void
    var onTryFeed: ((DiscoverFeed) -> Void)?
    var onAddFeed: ((DiscoverFeed) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            headerView
            contentView
        }
        .background(DiscoverColors.background)
        .id(themeObserver.themeVersion)
        .onAppear {
            viewModel.loadInitialPage()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image("discover")
                .renderingMode(.template)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundColor(Color(UIColor(red: 0x95/255.0, green: 0x96/255.0, blue: 0x8F/255.0, alpha: 1.0)))

            Text("Discover sites")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(DiscoverColors.textPrimary)

            Spacer()

            Picker("View Mode", selection: Binding(
                get: { viewModel.viewMode },
                set: { viewModel.setViewMode($0) }
            )) {
                Image(systemName: "square.grid.2x2")
                    .tag(DiscoverFeedsViewMode.grid)
                Image(systemName: "list.bullet")
                    .tag(DiscoverFeedsViewMode.list)
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(DiscoverColors.cardBackground)
    }

    // MARK: - Content

    private var contentView: some View {
        Group {
            if viewModel.feeds.isEmpty && viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error, viewModel.feeds.isEmpty {
                errorView(error)
            } else {
                feedListView
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DiscoverColors.accent))
            Text("Finding related sites...")
                .font(.system(size: 14))
                .foregroundColor(DiscoverColors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundColor(DiscoverColors.textSecondary)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(DiscoverColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var feedListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.feeds) { feed in
                    feedCardView(feed)
                }

                if viewModel.hasMorePages {
                    loadMoreIndicator
                }
            }
            .padding(12)
        }
    }

    private var loadMoreIndicator: some View {
        HStack {
            Spacer()
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: DiscoverColors.accent))
                    .padding(.vertical, 16)
            } else {
                Color.clear
                    .frame(height: 1)
                    .onAppear {
                        viewModel.loadNextPage()
                    }
            }
            Spacer()
        }
    }

    // MARK: - Feed Card

    private func feedCardView(_ feed: DiscoverFeed) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Feed header
            HStack(spacing: 10) {
                faviconView(feed)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(feed.feedTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DiscoverColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Image(systemName: "person.2")
                                .font(.system(size: 10))
                            Text("\(feed.numSubscribers)")
                                .font(.system(size: 11, weight: .semibold))
                            + Text(" \(feed.numSubscribers == 1 ? "subscriber" : "subscribers")")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(DiscoverColors.textSecondary)

                        HStack(spacing: 3) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 10))
                            Text("\(feed.averageStoriesPerMonth)")
                                .font(.system(size: 11, weight: .semibold))
                            + Text(" \(feed.averageStoriesPerMonth == 1 ? "story" : "stories")/mo")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(DiscoverColors.textSecondary)
                    }
                }

                Spacer()

                if isSubscribed(feed) {
                    Label("Subscribed", systemImage: "checkmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DiscoverColors.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                } else {
                    HStack(spacing: 8) {
                        Button(action: { onTryFeed?(feed) }) {
                            Text("Try")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DiscoverColors.tryButtonText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(DiscoverColors.tryButtonBackground)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(DiscoverColors.border, lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: { onAddFeed?(feed) }) {
                            Text("Add")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(DiscoverColors.accent)
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(12)

            // Stories list (only in list mode)
            if viewModel.viewMode == .list && !feed.stories.isEmpty {
                Rectangle()
                    .fill(DiscoverColors.border.opacity(0.5))
                    .frame(height: 1)
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(feed.stories.prefix(3)) { story in
                        storyRow(story)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(DiscoverColors.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(DiscoverColors.border.opacity(0.6), lineWidth: 1)
        )
    }

    // MARK: - Favicon

    private func faviconView(_ feed: DiscoverFeed) -> some View {
        Group {
            if let faviconUrl = feed.faviconUrl, let url = URL(string: faviconUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    default:
                        Color.clear
                    }
                }
            } else {
                Color.clear
            }
        }
    }

    // MARK: - Story Row

    private func storyRow(_ story: DiscoverStory) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(DiscoverColors.accent)
                .frame(width: 5, height: 5)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(story.title)
                    .font(.system(size: 13))
                    .foregroundColor(DiscoverColors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    if !story.authors.isEmpty {
                        Text(story.authors)
                            .font(.system(size: 11))
                            .foregroundColor(DiscoverColors.textSecondary)
                            .lineLimit(1)
                    }

                    if !story.authors.isEmpty && story.date != nil {
                        Text("\u{00B7}")
                            .font(.system(size: 11))
                            .foregroundColor(DiscoverColors.textSecondary)
                    }

                    if let date = story.date {
                        Text(relativeDate(date))
                            .font(.system(size: 11))
                            .foregroundColor(DiscoverColors.textSecondary)
                    }
                }
            }

            Spacer(minLength: 0)

            if let imageUrl = story.imageUrls.first, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    default:
                        Color.clear
                            .frame(width: 48, height: 48)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func isSubscribed(_ feed: DiscoverFeed) -> Bool {
        guard let appDelegate = NewsBlurAppDelegate.shared() else { return false }
        return appDelegate.dictFeeds?.object(forKey: feed.id) != nil
    }
}
