//
//  RedditTabView.swift
//  NewsBlur
//
//  Created by Claude on 2026-03-05.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, *)
struct RedditTabView: View {
    @ObservedObject var viewModel: DiscoverSitesViewModel
    var onTryFeed: ((DiscoverPopularFeed) -> Void)?
    var onAddFeed: ((DiscoverPopularFeed) -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                DiscoverSearchBarView(
                    placeholder: "Search subreddits...",
                    text: $viewModel.redditState.searchQuery,
                    isLoading: viewModel.redditState.isSearching,
                    onSubmit: {
                        viewModel.searchFeeds(type: "reddit", query: viewModel.redditState.searchQuery)
                    },
                    viewMode: $viewModel.feedViewMode
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if !viewModel.redditState.categories.isEmpty && viewModel.redditState.searchQuery.isEmpty {
                    DiscoverCategoryPillsView(
                        categories: viewModel.redditState.categories,
                        selectedCategory: $viewModel.redditState.selectedCategory,
                        selectedSubcategory: $viewModel.redditState.selectedSubcategory
                    )
                    .onChange(of: viewModel.redditState.selectedCategory) { _ in
                        reloadFeeds()
                    }
                    .onChange(of: viewModel.redditState.selectedSubcategory) { _ in
                        reloadFeeds()
                    }
                }

                feedsList
                DiscoverResultsStatusView(
                    isLoading: viewModel.redditState.isLoading || viewModel.redditState.isSearching,
                    isEmpty: viewModel.redditState.submittedQuery.isEmpty
                        ? viewModel.redditState.feeds.isEmpty : viewModel.redditState.searchResults.isEmpty,
                    error: viewModel.redditState.errorMessage,
                    isSearching: !viewModel.redditState.submittedQuery.isEmpty,
                    retry: {
                        if viewModel.redditState.searchQuery.isEmpty {
                            reloadFeeds()
                        } else {
                            viewModel.searchFeeds(type: "reddit", query: viewModel.redditState.searchQuery)
                        }
                    }
                )

            }
        }
        .background(DiscoverColors.background)
        .scrollDismissesKeyboard(.interactively)
        .task(id: viewModel.redditState.searchQuery) {
            do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
            viewModel.searchFeeds(type: "reddit", query: viewModel.redditState.searchQuery)
        }

        .onAppear {
            if !viewModel.redditState.isCategoriesLoaded {
                viewModel.loadPopularFeeds(type: "reddit", category: nil, subcategory: nil, offset: 0)
            }
        }
        .onChange(of: viewModel.feedViewMode) { newMode in
            if newMode == .list && !viewModel.redditState.hasLoadedStories {
                reloadFeeds()
            }
        }
    }

    @ViewBuilder
    private var feedsList: some View {
        let feeds =
            viewModel.redditState.submittedQuery.isEmpty
            ? viewModel.redditState.feeds
            : viewModel.redditState.searchResults

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
                    if viewModel.redditState.searchQuery.isEmpty
                        && feed.id == viewModel.redditState.feeds.last?.id && viewModel.redditState.hasMore
                        && !viewModel.redditState.isLoading
                    {
                        loadMore()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)

        if viewModel.redditState.isLoading {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DiscoverColors.accent))
                .padding(.vertical, 20)
        }
    }

    private func reloadFeeds() {
        viewModel.loadPopularFeeds(
            type: "reddit",
            category: viewModel.redditState.selectedCategory?.name,
            subcategory: viewModel.redditState.selectedSubcategory?.name,
            offset: 0
        )
    }

    private func loadMore() {
        viewModel.loadPopularFeeds(
            type: "reddit",
            category: viewModel.redditState.selectedCategory?.name,
            subcategory: viewModel.redditState.selectedSubcategory?.name,
            offset: viewModel.redditState.offset
        )
    }
}
