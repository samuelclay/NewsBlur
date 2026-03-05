//
//  NewslettersTabView.swift
//  NewsBlur
//
//  Created by Claude on 2026-03-05.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, *)
struct NewslettersTabView: View {
    @ObservedObject var viewModel: DiscoverSitesViewModel
    var onTryFeed: ((DiscoverPopularFeed) -> Void)?
    var onAddFeed: ((DiscoverPopularFeed) -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                DiscoverSearchBarView(
                    placeholder: "Search newsletters...",
                    text: $viewModel.newslettersState.searchQuery,
                    isLoading: viewModel.newslettersState.isSearching,
                    onSubmit: {
                        viewModel.searchFeeds(type: "newsletter", query: viewModel.newslettersState.searchQuery)
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)


                if !viewModel.newslettersState.platformCounts.isEmpty && viewModel.newslettersState.searchQuery.isEmpty {
                    platformPillsSection
                }

                if !viewModel.newslettersState.categories.isEmpty && viewModel.newslettersState.searchQuery.isEmpty {
                    DiscoverCategoryPillsView(
                        categories: viewModel.newslettersState.categories,
                        selectedCategory: $viewModel.newslettersState.selectedCategory,
                        selectedSubcategory: $viewModel.newslettersState.selectedSubcategory
                    )
                    .onChange(of: viewModel.newslettersState.selectedCategory) { _ in
                        reloadFeeds()
                    }
                    .onChange(of: viewModel.newslettersState.selectedSubcategory) { _ in
                        reloadFeeds()
                    }
                }

                feedsList
            }
        }
        .background(DiscoverColors.background)
        .onAppear {
            if !viewModel.newslettersState.isCategoriesLoaded {
                viewModel.loadPopularFeeds(type: "newsletter", category: nil, subcategory: nil, offset: 0)
            }
        }
    }

    // MARK: - Platform Pills

    private var platformPillsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                platformPill(label: "All", count: nil, isActive: viewModel.newslettersState.platformFilter == nil) {
                    viewModel.newslettersState.platformFilter = nil
                    reloadFeeds()
                }

                ForEach(sortedPlatforms, id: \.key) { platform, count in
                    platformPill(label: platform, count: count, isActive: viewModel.newslettersState.platformFilter == platform) {
                        if viewModel.newslettersState.platformFilter == platform {
                            viewModel.newslettersState.platformFilter = nil
                        } else {
                            viewModel.newslettersState.platformFilter = platform
                        }
                        reloadFeeds()
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 6)
    }

    private var sortedPlatforms: [(key: String, value: Int)] {
        viewModel.newslettersState.platformCounts.sorted { $0.value > $1.value }
    }

    private func platformPill(label: String, count: Int?, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                if let count = count, count > 0 {
                    Text("(\(count))")
                        .font(.system(size: 11))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? DiscoverColors.addButtonBackground : DiscoverColors.cardBackground)
            .foregroundColor(isActive ? .white : DiscoverColors.textSecondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color.clear : DiscoverColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Feeds List

    @ViewBuilder
    private var feedsList: some View {
        let feeds = viewModel.newslettersState.searchQuery.isEmpty
            ? viewModel.newslettersState.feeds
            : viewModel.newslettersState.searchResults

        LazyVStack(spacing: 12) {
            ForEach(feeds) { feed in
                DiscoverFeedCardView(
                    feed: feed,
                    onTryFeed: onTryFeed,
                    onAddFeed: onAddFeed
                )
                .onAppear {
                    if viewModel.newslettersState.searchQuery.isEmpty &&
                        feed.id == viewModel.newslettersState.feeds.last?.id &&
                        viewModel.newslettersState.hasMore &&
                        !viewModel.newslettersState.isLoading {
                        loadMore()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)

        if viewModel.newslettersState.isLoading {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DiscoverColors.accent))
                .padding(.vertical, 20)
        }
    }

    // MARK: - Helpers

    private func reloadFeeds() {
        viewModel.loadPopularFeeds(
            type: "newsletter",
            category: viewModel.newslettersState.selectedCategory?.name,
            subcategory: viewModel.newslettersState.selectedSubcategory?.name,
            offset: 0
        )
    }

    private func loadMore() {
        viewModel.loadPopularFeeds(
            type: "newsletter",
            category: viewModel.newslettersState.selectedCategory?.name,
            subcategory: viewModel.newslettersState.selectedSubcategory?.name,
            offset: viewModel.newslettersState.offset
        )
    }
}
