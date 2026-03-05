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
    var onAddFeed: ((DiscoverPopularFeed) -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
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

                LazyVStack(spacing: 12) {
                    ForEach(viewModel.popularState.feeds) { feed in
                        DiscoverFeedCardView(
                            feed: feed,
                            onTryFeed: onTryFeed,
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

                if viewModel.popularState.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DiscoverColors.accent))
                        .padding(.vertical, 20)
                }
            }
        }
        .background(DiscoverColors.background)
        .onAppear {
            if !viewModel.popularState.isCategoriesLoaded {
                viewModel.loadPopularFeeds(type: "all", category: nil, subcategory: nil, offset: 0)
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
