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
                    },
                    viewMode: $viewModel.feedViewMode
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
                DiscoverResultsStatusView(
                    isLoading: viewModel.youtubeState.isLoading || viewModel.youtubeState.isSearching,
                    isEmpty: viewModel.youtubeState.submittedQuery.isEmpty
                        ? viewModel.youtubeState.feeds.isEmpty : viewModel.youtubeState.searchResults.isEmpty,
                    error: viewModel.youtubeState.errorMessage,
                    isSearching: !viewModel.youtubeState.submittedQuery.isEmpty,
                    retry: {
                        if viewModel.youtubeState.searchQuery.isEmpty {
                            reloadFeeds()
                        } else {
                            viewModel.searchFeeds(type: "youtube", query: viewModel.youtubeState.searchQuery)
                        }
                    }
                )

            }
        }
        .background(DiscoverColors.background)
        .scrollDismissesKeyboard(.interactively)
        .task(id: viewModel.youtubeState.searchQuery) {
            do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
            viewModel.searchFeeds(type: "youtube", query: viewModel.youtubeState.searchQuery)
        }

        .onAppear {
            if !viewModel.youtubeState.isCategoriesLoaded {
                viewModel.loadPopularFeeds(type: "youtube", category: nil, subcategory: nil, offset: 0)
            }
        }
        .onChange(of: viewModel.feedViewMode) { newMode in
            if newMode == .list && !viewModel.youtubeState.hasLoadedStories {
                reloadFeeds()
            }
        }
    }

    @ViewBuilder
    private var feedsList: some View {
        let feeds =
            viewModel.youtubeState.submittedQuery.isEmpty
            ? viewModel.youtubeState.feeds
            : viewModel.youtubeState.searchResults

        LazyVGrid(
            columns: [
                viewModel.feedViewMode == .grid
                    ? GridItem(.adaptive(minimum: 300), spacing: 12, alignment: .top) : GridItem(.flexible())
            ], alignment: .leading, spacing: 12
        ) {
            ForEach(feeds) { feed in
                DiscoverFeedCardView(
                    feed: feed,
                    showStories: viewModel.feedViewMode == .list,
                    onTryFeed: onTryFeed,
                    onAddFeed: onAddFeed
                )
                .onAppear {
                    if viewModel.youtubeState.searchQuery.isEmpty
                        && feed.id == viewModel.youtubeState.feeds.last?.id && viewModel.youtubeState.hasMore
                        && !viewModel.youtubeState.isLoading
                    {
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
