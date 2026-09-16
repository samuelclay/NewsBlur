//
//  PodcastsTabView.swift
//  NewsBlur
//
//  Created by Claude on 2026-03-05.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, *)
struct PodcastsTabView: View {
    @ObservedObject var viewModel: DiscoverSitesViewModel
    var onTryFeed: ((DiscoverPopularFeed) -> Void)?
    var onAddFeed: ((DiscoverPopularFeed) -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                DiscoverSearchBarView(
                    placeholder: "Search podcasts...",
                    text: $viewModel.podcastsState.searchQuery,
                    isLoading: viewModel.podcastsState.isSearching,
                    onSubmit: {
                        viewModel.searchFeeds(type: "podcast", query: viewModel.podcastsState.searchQuery)
                    },
                    viewMode: $viewModel.feedViewMode
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if !viewModel.podcastsState.categories.isEmpty && viewModel.podcastsState.searchQuery.isEmpty
                {
                    DiscoverCategoryPillsView(
                        categories: viewModel.podcastsState.categories,
                        selectedCategory: $viewModel.podcastsState.selectedCategory,
                        selectedSubcategory: $viewModel.podcastsState.selectedSubcategory
                    )
                    .onChange(of: viewModel.podcastsState.selectedCategory) { _ in
                        reloadFeeds()
                    }
                    .onChange(of: viewModel.podcastsState.selectedSubcategory) { _ in
                        reloadFeeds()
                    }
                }

                feedsList
                DiscoverResultsStatusView(
                    isLoading: viewModel.podcastsState.isLoading || viewModel.podcastsState.isSearching,
                    isEmpty: viewModel.podcastsState.submittedQuery.isEmpty
                        ? viewModel.podcastsState.feeds.isEmpty
                        : viewModel.podcastsState.searchResults.isEmpty,
                    error: viewModel.podcastsState.errorMessage,
                    isSearching: !viewModel.podcastsState.submittedQuery.isEmpty,
                    retry: {
                        if viewModel.podcastsState.searchQuery.isEmpty {
                            reloadFeeds()
                        } else {
                            viewModel.searchFeeds(type: "podcast", query: viewModel.podcastsState.searchQuery)
                        }
                    }
                )

            }
        }
        .background(DiscoverColors.background)
        .scrollDismissesKeyboard(.interactively)
        .task(id: viewModel.podcastsState.searchQuery) {
            do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
            viewModel.searchFeeds(type: "podcast", query: viewModel.podcastsState.searchQuery)
        }

        .onAppear {
            if !viewModel.podcastsState.isCategoriesLoaded {
                viewModel.loadPopularFeeds(type: "podcast", category: nil, subcategory: nil, offset: 0)
            }
        }
        .onChange(of: viewModel.feedViewMode) { newMode in
            if newMode == .list && !viewModel.podcastsState.hasLoadedStories {
                reloadFeeds()
            }
        }
    }

    @ViewBuilder
    private var feedsList: some View {
        let feeds =
            viewModel.podcastsState.submittedQuery.isEmpty
            ? viewModel.podcastsState.feeds
            : viewModel.podcastsState.searchResults

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
                    if viewModel.podcastsState.searchQuery.isEmpty
                        && feed.id == viewModel.podcastsState.feeds.last?.id
                        && viewModel.podcastsState.hasMore && !viewModel.podcastsState.isLoading
                    {
                        loadMore()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)

        if viewModel.podcastsState.isLoading {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DiscoverColors.accent))
                .padding(.vertical, 20)
        }
    }

    private func reloadFeeds() {
        viewModel.loadPopularFeeds(
            type: "podcast",
            category: viewModel.podcastsState.selectedCategory?.name,
            subcategory: viewModel.podcastsState.selectedSubcategory?.name,
            offset: 0
        )
    }

    private func loadMore() {
        viewModel.loadPopularFeeds(
            type: "podcast",
            category: viewModel.podcastsState.selectedCategory?.name,
            subcategory: viewModel.podcastsState.selectedSubcategory?.name,
            offset: viewModel.podcastsState.offset
        )
    }
}
