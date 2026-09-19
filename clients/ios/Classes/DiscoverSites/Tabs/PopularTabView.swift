//
//  PopularTabView.swift
//  NewsBlur
//
//  Created by Claude on 2026-03-05.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, *)
struct PopularTabView: View {
    @ObservedObject var viewModel: DiscoverSitesViewModel
    var onTryFeed: ((DiscoverPopularFeed) -> Void)?
    var onOpenStory: ((DiscoverPopularFeed, DiscoverStory) -> Void)?
    var onAddFeed: ((DiscoverPopularFeed) -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                HStack {
                    Spacer()
                    DiscoverViewModePicker(viewMode: $viewModel.feedViewMode)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if !viewModel.popularState.categories.isEmpty {
                    DiscoverCategoryPillsView(
                        categories: viewModel.popularState.categories,
                        selectedCategory: $viewModel.popularState.selectedCategory,
                        selectedSubcategory: $viewModel.popularState.selectedSubcategory
                    )
                    .onChange(of: viewModel.popularState.selectedCategory) { _ in
                        reloadFeeds()
                    }
                    .onChange(of: viewModel.popularState.selectedSubcategory) { _ in
                        reloadFeeds()
                    }
                }

                LazyVGrid(columns: [viewModel.feedViewMode == .grid ? GridItem(.adaptive(minimum: 300), spacing: 12, alignment: .top) : GridItem(.flexible())], spacing: 12) {
                    ForEach(viewModel.popularState.feeds) { feed in
                        DiscoverFeedCardView(
                            feed: feed,
                            showStories: viewModel.feedViewMode == .list,
                            onTryFeed: onTryFeed,
                            onOpenStory: onOpenStory,
                            onAddFeed: onAddFeed
                        )
                        .onAppear {
                            if feed.id == viewModel.popularState.feeds.last?.id && viewModel.popularState.hasMore && !viewModel.popularState.isLoading {
                                loadMore()
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

                DiscoverResultsStatusView(isLoading: viewModel.popularState.isLoading,
                    isEmpty: viewModel.popularState.feeds.isEmpty,
                    error: viewModel.popularState.errorMessage, isSearching: false, retry: reloadFeeds)

            }
        }
        .background(DiscoverColors.background)
        .onAppear {
            if !viewModel.popularState.isCategoriesLoaded {
                viewModel.loadPopularFeeds(type: "all", category: nil, subcategory: nil, offset: 0)
            }
        }
        .onChange(of: viewModel.feedViewMode) { newMode in
            if newMode == .list && !viewModel.popularState.hasLoadedStories {
                reloadFeeds()
            }
        }
    }

    private func reloadFeeds() {
        viewModel.loadPopularFeeds(
            type: "all",
            category: viewModel.popularState.selectedCategory?.name,
            subcategory: viewModel.popularState.selectedSubcategory?.name,
            offset: 0
        )
    }

    private func loadMore() {
        viewModel.loadPopularFeeds(
            type: "all",
            category: viewModel.popularState.selectedCategory?.name,
            subcategory: viewModel.popularState.selectedSubcategory?.name,
            offset: viewModel.popularState.offset
        )
    }
}
