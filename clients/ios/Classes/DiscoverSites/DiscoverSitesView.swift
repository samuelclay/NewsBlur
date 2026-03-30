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

            tabContent
        }
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
