//
//  DiscoverSitesView.swift
//  NewsBlur
//
//  Created by Claude on 2026-03-05.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, *)
struct DiscoverSitesView: View {
    @ObservedObject var viewModel: DiscoverSitesViewModel
    @StateObject private var themeObserver = AskAIThemeObserver()
    var onTryFeed: ((DiscoverPopularFeed) -> Void)?
    var onAddFeed: ((DiscoverPopularFeed) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            DiscoverTabBarView(activeTab: $viewModel.activeTab)

            HStack {
                Image(systemName: "folder")
                Text("Add to")
                Menu {
                    Button("Top Level") { viewModel.selectedFolder = "" }
                    ForEach(viewModel.folders, id: \.self) { folder in
                        Button(viewModel.folderDisplayName(folder)) { viewModel.selectedFolder = folder }
                    }
                } label: {
                    HStack {
                        Text(viewModel.displayFolder).lineLimit(1)
                        Image(systemName: "chevron.down").font(.caption)
                    }
                }
                .accessibilityIdentifier("discover-folder-picker")
                Spacer(minLength: 0)
                if viewModel.isAdding || viewModel.isPreparingPreview { ProgressView() }
            }
            .font(.subheadline)
            .foregroundColor(DiscoverColors.textPrimary)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)

            if viewModel.addedSuccess {
                HStack {
                    Label("Site added", systemImage: "checkmark.circle.fill")
                    Spacer()
                    Button("Dismiss") { viewModel.addedSuccess = false }
                }
                .font(.subheadline)
                .foregroundColor(DiscoverColors.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .accessibilityIdentifier("discover-added-success")
            }
            if let message = viewModel.addErrorMessage {
                Text(message).font(.subheadline).foregroundColor(DiscoverColors.errorText)
                    .padding(.horizontal, 16).padding(.vertical, 8)
            }
            tabContent

        }
        .environmentObject(viewModel)
        .background(DiscoverColors.background)
        .id(themeObserver.themeVersion)
        .onChange(of: viewModel.activeTab) { newTab in
            viewModel.onTabSelected(newTab)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.activeTab {
        case .search:
            SearchTabView(viewModel: viewModel, onTryFeed: onTryFeed, onAddFeed: onAddFeed)
        case .webFeed:
            WebFeedTabView(viewModel: viewModel)
        case .popular:
            PopularTabView(viewModel: viewModel, onTryFeed: onTryFeed, onAddFeed: onAddFeed)
        case .youtube:
            YouTubeTabView(viewModel: viewModel, onTryFeed: onTryFeed, onAddFeed: onAddFeed)
        case .reddit:
            RedditTabView(viewModel: viewModel, onTryFeed: onTryFeed, onAddFeed: onAddFeed)
        case .newsletters:
            NewslettersTabView(viewModel: viewModel, onTryFeed: onTryFeed, onAddFeed: onAddFeed)
        case .podcasts:
            PodcastsTabView(viewModel: viewModel, onTryFeed: onTryFeed, onAddFeed: onAddFeed)
        case .googleNews:
            GoogleNewsTabView(viewModel: viewModel)
        }
    }
}

// DiscoverSitesView.swift: shared feedback keeps every source tab recoverable.
@available(iOS 15.0, *)
struct DiscoverResultsStatusView: View {
    let isLoading: Bool
    let isEmpty: Bool
    let error: String?
    let isSearching: Bool
    var retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if isLoading {
                ProgressView(isSearching ? "Searching…" : "Finding sites…")
            } else if let error {
                Image(systemName: "wifi.exclamationmark").font(.title2)
                Text(error).multilineTextAlignment(.center)
                Button("Try again", action: retry).frame(minHeight: 44)
            } else if isEmpty {
                Image(systemName: "magnifyingglass").font(.title2)
                Text(isSearching ? "No matching sites" : "No sites in this category")
                    .font(.headline)
                Text(isSearching ? "Try another name, or paste a site URL in Search." : "Choose another category to discover more.")
                    .font(.subheadline).multilineTextAlignment(.center)
            }
        }
        .foregroundColor(DiscoverColors.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(isLoading || isEmpty || error != nil ? 24 : 0)
    }
}
