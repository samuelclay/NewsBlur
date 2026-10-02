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
    @ObservedObject var cardActions: DiscoverSitesViewModel
    @StateObject private var themeObserver = AskAIThemeObserver()
    var onDismiss: () -> Void
    var onTryFeed: ((DiscoverPopularFeed) -> Void)?
    var onOpenStory: ((DiscoverPopularFeed, DiscoverStory) -> Void)?
    var onAddFeed: ((DiscoverPopularFeed) -> Void)?
    var onUpgrade: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            headerView
            if cardActions.isAdding || cardActions.isPreparingPreview {
                ProgressView(cardActions.isAdding ? "Adding site…" : "Opening site…")
                    .font(.subheadline)
                    .foregroundColor(DiscoverColors.textPrimary)
                    .padding(12)
            }
            if let error = cardActions.addErrorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(DiscoverColors.errorText)
                    .padding(12)
            }
            if cardActions.addedSuccess {
                Label("Site added", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(DiscoverColors.accent)
                    .padding(12)
                    .accessibilityIdentifier("related-site-added-success")
            }
            contentView
        }
        .environmentObject(cardActions)
        .background(DiscoverColors.background)
        .id(themeObserver.themeVersion)
        .onAppear {
            viewModel.loadInitialPage()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        Group {
            if #available(iOS 16.0, *) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        headerTitle
                        Spacer(minLength: 8)
                        viewModePicker
                        closeButton
                    }
                    stackedHeader
                }
            } else {
                stackedHeader
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(DiscoverColors.cardBackground)
    }

    private var stackedHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                headerTitle
                Spacer()
                closeButton
            }
            viewModePicker
        }
    }

    private var headerTitle: some View {
        HStack {
            Image("discover")
                .renderingMode(.template)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundColor(DiscoverColors.textSecondary)
            Text("Related sites")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(DiscoverColors.textPrimary)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var viewModePicker: some View {
        DiscoverViewModePicker(viewMode: Binding(
            get: { viewModel.viewMode }, set: { viewModel.setViewMode($0) }))
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DiscoverColors.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close Related Sites")
        .hoverEffect(.highlight)
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

                LazyVGrid(columns: [viewModel.viewMode == .grid
                    ? GridItem(.adaptive(minimum: 300), spacing: 12, alignment: .top)
                    : GridItem(.flexible())], spacing: 12) {
                    ForEach(viewModel.feeds) { feed in
                        DiscoverFeedCardView(feed: feed, showStories: viewModel.viewMode == .list,
                                             onTryFeed: onTryFeed, onOpenStory: onOpenStory, onAddFeed: onAddFeed)
                    }
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

}
