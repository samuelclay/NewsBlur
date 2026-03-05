//
//  DiscoverFeedsView.swift
//  NewsBlur
//
//  Created by Claude on 2025-02-11.
//  Copyright 2025 NewsBlur. All rights reserved.
//

import SwiftUI

// MARK: - Main View

@available(iOS 15.0, *)
struct DiscoverFeedsView: View {
    @ObservedObject var viewModel: DiscoverFeedsViewModel
    @StateObject private var themeObserver = AskAIThemeObserver()
    var onDismiss: () -> Void
    var onTryFeed: ((DiscoverFeed) -> Void)?
    var onAddFeed: ((DiscoverFeed) -> Void)?
    var onUpgrade: (() -> Void)?

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

            Text("Related sites")
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

    // MARK: - Archive Upgrade Banner

    @ViewBuilder
    private var archiveUpgradeBanner: some View {
        if let appDelegate = NewsBlurAppDelegate.shared(), !appDelegate.isPremiumArchive {
            let counts = discoverIndexedCounts
            let feedCount = counts.total
            let indexedCount = counts.indexed
            let progressPct = feedCount > 0 ? Double(indexedCount) / Double(feedCount) : 0

            Button(action: { onUpgrade?() }) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.39, green: 0.40, blue: 0.95),
                                             Color(red: 0.55, green: 0.36, blue: 0.96)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("Unlock full discovery")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(DiscoverColors.textPrimary)

                                Text("Premium Archive")
                                    .font(.system(size: 9, weight: .semibold))
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        LinearGradient(
                                            colors: [Color(red: 0.39, green: 0.40, blue: 0.95),
                                                     Color(red: 0.55, green: 0.36, blue: 0.96)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(3)
                            }

                            Text("Only \(indexedCount) of your \(feedCount) sites are indexed for discovery. Upgrade to index all your sites and get personalized recommendations.")
                                .font(.system(size: 12))
                                .foregroundColor(DiscoverColors.textSecondary)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Progress bar
                    VStack(alignment: .trailing, spacing: 4) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(DiscoverColors.bannerProgressBackground)
                                    .frame(height: 6)

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0.39, green: 0.40, blue: 0.95),
                                                     Color(red: 0.55, green: 0.36, blue: 0.96)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * progressPct, height: 6)
                            }
                        }
                        .frame(height: 6)

                        Text("\(indexedCount) of \(feedCount) sites indexed")
                            .font(.system(size: 11))
                            .foregroundColor(DiscoverColors.bannerProgressLabel)
                    }

                    // CTA button
                    Text("Upgrade to Premium Archive")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.39, green: 0.40, blue: 0.95),
                                         Color(red: 0.55, green: 0.36, blue: 0.96)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(6)
                }
                .padding(14)
                .background(DiscoverColors.bannerBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DiscoverColors.bannerBorder, lineWidth: 1)
                )
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var discoverIndexedCounts: (total: Int, indexed: Int) {
        guard let appDelegate = NewsBlurAppDelegate.shared(),
              let dictFeeds = appDelegate.dictFeeds as? [String: Any] else {
            return (0, 0)
        }

        var total = 0
        var indexed = 0
        for (_, value) in dictFeeds {
            guard let feedDict = value as? [String: Any] else { continue }
            total += 1
            if let discoverIndexed = feedDict["discover_indexed"] as? Bool, discoverIndexed {
                indexed += 1
            } else if let discoverIndexed = feedDict["discover_indexed"] as? NSNumber, discoverIndexed.boolValue {
                indexed += 1
            }
        }
        return (total, indexed)
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
                archiveUpgradeBanner

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
                            (Text("\(feed.numSubscribers)")
                                .font(.system(size: 11, weight: .semibold))
                            + Text(" \(feed.numSubscribers == 1 ? "subscriber" : "subscribers")")
                                .font(.system(size: 11)))
                                .lineLimit(1)
                        }
                        .foregroundColor(DiscoverColors.textSecondary)

                        HStack(spacing: 3) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 10))
                            (Text("\(feed.averageStoriesPerMonth)")
                                .font(.system(size: 11, weight: .semibold))
                            + Text(" \(feed.averageStoriesPerMonth == 1 ? "story" : "stories")/mo")
                                .font(.system(size: 11)))
                                .lineLimit(1)
                        }
                        .foregroundColor(DiscoverColors.textSecondary)
                    }
                    .fixedSize()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isSubscribed(feed) {
                    Label("Subscribed", systemImage: "checkmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DiscoverColors.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .fixedSize()
                } else {
                    HStack(spacing: 6) {
                        Button(action: { onTryFeed?(feed) }) {
                            Text("Try")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DiscoverColors.tryButtonText)
                                .padding(.horizontal, 10)
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
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(DiscoverColors.accent)
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .fixedSize()
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
