//
//  SearchTabView.swift
//  NewsBlur
//
//  Created by Claude on 2026-03-05.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, *)
struct SearchTabView: View {
    @ObservedObject var viewModel: DiscoverSitesViewModel
    var onTryFeed: ((DiscoverPopularFeed) -> Void)?
    var onAddFeed: ((DiscoverPopularFeed) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    DiscoverSearchBarView(
                        placeholder: "Search feeds...",
                        text: $viewModel.searchState.query,
                        isLoading: viewModel.searchState.isSearching,
                        viewMode: $viewModel.feedViewMode
                    )
                    .onChange(of: viewModel.searchState.query) { newValue in
                        viewModel.searchAutocomplete(query: newValue)
                    }

                    if viewModel.searchState.query.isEmpty {
                        trendingSection
                    } else if !viewModel.searchState.results.isEmpty {
                        searchResultsSection
                    } else if !viewModel.searchState.isSearching {
                        emptySearchState
                    }
                }
                .frame(width: max(0, geometry.size.width - 32), alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(DiscoverColors.background)
        .onAppear {
            if !viewModel.searchState.isTrendingLoaded {
                viewModel.loadTrendingFeeds()
            }
        }
    }

    // MARK: - Trending Section

    @ViewBuilder
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundColor(DiscoverColors.accent)
                Text("Trending")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DiscoverColors.textPrimary)

                if viewModel.searchState.isTrendingLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(viewModel.searchState.trendingFeeds) { feed in
                DiscoverFeedCardView(
                    feed: feed,
                    showStories: viewModel.feedViewMode == .list,
                    onTryFeed: onTryFeed,
                    onAddFeed: onAddFeed
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Search Results

    private var searchResultsSection: some View {
        ForEach(viewModel.searchState.results) { result in
            searchResultRow(result)
        }
    }

    private func searchResultRow(_ result: AutocompleteResult) -> some View {
        HStack(spacing: 10) {
            faviconView(for: result)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DiscoverColors.textPrimary)
                    .lineLimit(1)

                Text(result.value)
                    .font(.system(size: 12))
                    .foregroundColor(DiscoverColors.textSecondary)
                    .lineLimit(1)

                HStack(spacing: 3) {
                    Image(systemName: "person.2")
                        .font(.system(size: 10))
                    Text("\(result.numSubscribers) \(result.numSubscribers == 1 ? "subscriber" : "subscribers")")
                        .font(.system(size: 11))
                }
                .foregroundColor(DiscoverColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Button(action: {
                    let feed = autocompleteResultToFeed(result)
                    onTryFeed?(feed)
                }) {
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

                Button(action: {
                    let feed = autocompleteResultToFeed(result)
                    onAddFeed?(feed)
                }) {
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
        .padding(12)
        .background(DiscoverColors.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(DiscoverColors.border.opacity(0.6), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty State

    private var emptySearchState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundColor(DiscoverColors.textSecondary)
            Text("No results found")
                .font(.system(size: 15))
                .foregroundColor(DiscoverColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func faviconView(for result: AutocompleteResult) -> some View {
        if let favicon = result.favicon,
           !favicon.isEmpty,
           let data = Data(base64Encoded: favicon),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Image(systemName: "globe")
                .font(.system(size: 14))
                .foregroundColor(DiscoverColors.textSecondary)
                .frame(width: 24, height: 24)
        }
    }

    private func autocompleteResultToFeed(_ result: AutocompleteResult) -> DiscoverPopularFeed {
        let feedDict: [String: Any] = [
            "feed_title": result.label,
            "feed_address": result.value,
            "feed_link": result.value,
            "num_subscribers": result.numSubscribers,
            "favicon_url": result.favicon as Any
        ]
        return DiscoverPopularFeed(feedId: result.id, feedDict: feedDict)
    }
}
