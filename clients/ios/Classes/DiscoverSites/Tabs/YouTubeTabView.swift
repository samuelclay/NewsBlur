//
//  YouTubeTabView.swift
//  NewsBlur
//
//  Created by Claude on 2026-03-05.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, *)
struct YouTubeTabView: View {
    @ObservedObject var viewModel: DiscoverSitesViewModel
    var onTryFeed: ((DiscoverPopularFeed) -> Void)?
    var onAddFeed: ((DiscoverPopularFeed) -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                DiscoverSearchBarView(
                    placeholder: "Search YouTube channels...",
                    text: $viewModel.youtubeState.searchQuery,
                    isLoading: viewModel.youtubeState.isSearching,
                    onSubmit: {
                        viewModel.searchFeeds(type: "youtube", query: viewModel.youtubeState.searchQuery)
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if !viewModel.youtubeState.categories.isEmpty && viewModel.youtubeState.searchQuery.isEmpty {
                    DiscoverCategoryPillsView(
                        categories: viewModel.youtubeState.categories,
                        selectedCategory: $viewModel.youtubeState.selectedCategory,
                        selectedSubcategory: $viewModel.youtubeState.selectedSubcategory
                    )
                    .onChange(of: viewModel.youtubeState.selectedCategory) { _ in
                        reloadFeeds()
                    }
                    .onChange(of: viewModel.youtubeState.selectedSubcategory) { _ in
                        reloadFeeds()
                    }
                }

                feedsList
            }
        }
        .background(DiscoverColors.background)
        .onAppear {
            if !viewModel.youtubeState.isCategoriesLoaded {
                viewModel.loadPopularFeeds(type: "youtube", category: nil, subcategory: nil, offset: 0)
            }
        }
    }

    @ViewBuilder
    private var feedsList: some View {
        let feeds = viewModel.youtubeState.searchQuery.isEmpty
            ? viewModel.youtubeState.feeds
            : viewModel.youtubeState.searchResults

        LazyVStack(spacing: 12) {
            ForEach(feeds) { feed in
                DiscoverFeedCardView(
                    feed: feed,
                    onTryFeed: onTryFeed,
                    onAddFeed: onAddFeed
                )
                .onAppear {
                    if viewModel.youtubeState.searchQuery.isEmpty &&
                        feed.id == viewModel.youtubeState.feeds.last?.id &&
                        viewModel.youtubeState.hasMore &&
                        !viewModel.youtubeState.isLoading {
                        loadMore()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)

        if viewModel.youtubeState.isLoading {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DiscoverColors.accent))
                .padding(.vertical, 20)
        }
    }

    private func reloadFeeds() {
        viewModel.loadPopularFeeds(
            type: "youtube",
            category: viewModel.youtubeState.selectedCategory?.name,
            subcategory: viewModel.youtubeState.selectedSubcategory?.name,
            offset: 0
        )
    }

    private func loadMore() {
        viewModel.loadPopularFeeds(
            type: "youtube",
            category: viewModel.youtubeState.selectedCategory?.name,
            subcategory: viewModel.youtubeState.selectedSubcategory?.name,
            offset: viewModel.youtubeState.offset
        )
    }
}
