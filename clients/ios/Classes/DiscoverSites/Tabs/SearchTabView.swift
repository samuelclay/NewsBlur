// SearchTabView.swift presents URL entry and discovery results in the same flow.
import SwiftUI

@available(iOS 15.0, *)
struct SearchTabView: View {
    @ObservedObject var viewModel: DiscoverSitesViewModel
    var onTryFeed: ((DiscoverPopularFeed) -> Void)?
    var onAddFeed: ((DiscoverPopularFeed) -> Void)?

    private var query: String { viewModel.searchState.query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isURL: Bool { !query.contains(" ") && query.contains(".") }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                DiscoverSearchBarView(
                    placeholder: "Site URL or search by name…",
                    text: $viewModel.searchState.query,
                    isLoading: viewModel.searchState.isSearching,
                    onSubmit: { viewModel.searchAutocomplete(query: query) },
                    viewMode: $viewModel.feedViewMode
                )
                .onChange(of: viewModel.searchState.query) { viewModel.searchAutocomplete(query: $0) }

                if isURL {
                    Button {
                        viewModel.addFeed(url: query)
                    } label: {
                        Label(viewModel.isAdding ? "Adding site…" : "Add this site", systemImage: "plus.circle.fill")
                            .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DiscoverColors.accent)
                    .disabled(viewModel.isAdding)
                    .accessibilityIdentifier("discover-add-url")
                }

                if query.isEmpty {
                    Label("Trending Sites", systemImage: "waveform.path")
                        .font(.headline).foregroundColor(DiscoverColors.textPrimary)
                    feedGrid(viewModel.searchState.trendingFeeds)
                    DiscoverResultsStatusView(isLoading: viewModel.searchState.isTrendingLoading,
                        isEmpty: viewModel.searchState.trendingFeeds.isEmpty,
                        error: viewModel.searchState.trendingErrorMessage,
                        isSearching: false, retry: viewModel.loadTrendingFeeds)
                } else {
                    feedGrid(viewModel.searchState.results.map { result in
                        DiscoverPopularFeed(feedId: result.id, feedDict: [
                            "feed_title": result.label, "feed_address": result.value,
                            "feed_link": result.value, "num_subscribers": result.numSubscribers,
                            "favicon": result.favicon ?? ""
                        ])
                    })
                    DiscoverResultsStatusView(isLoading: viewModel.searchState.isSearching,
                        isEmpty: viewModel.searchState.results.isEmpty && !isURL,
                        error: viewModel.searchState.errorMessage,
                        isSearching: true, retry: { viewModel.searchAutocomplete(query: query) })
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(DiscoverColors.background)
        .onAppear {
            if !viewModel.searchState.isTrendingLoaded { viewModel.loadTrendingFeeds() }
        }
    }

    private func feedGrid(_ feeds: [DiscoverPopularFeed]) -> some View {
        LazyVGrid(columns: [viewModel.feedViewMode == .grid
            ? GridItem(.adaptive(minimum: 300), spacing: 12, alignment: .top)
            : GridItem(.flexible())], spacing: 12) {
            ForEach(feeds) { feed in
                DiscoverFeedCardView(feed: feed, showStories: viewModel.feedViewMode == .list,
                    onTryFeed: onTryFeed, onAddFeed: onAddFeed)
            }
        }
    }
}
