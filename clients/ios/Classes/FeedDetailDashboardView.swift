//
//  FeedDetailDashboardView.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-10-29.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import SwiftUI

/// The dashboard layout with lists of story cards for the Dashboard view.
struct FeedDetailDashboardView: View {
    var feedDetailInteraction: FeedDetailInteraction
    
    @ObservedObject var cache: StoryCache
    
    var columns: [GridItem] {
        return Array(repeating: GridItem(.flexible(), spacing: 20), count: cache.settings.dashboardColumns)
    }
    
    var body: some View {
        GeometryReader { reader in
            ScrollView {
                ScrollViewReader { scroller in
                    LazyVGrid(columns: columns, spacing: 20) {
                        Section {
                            ForEach(cache.dashboard, id: \.id) { dash in
                                makeDashListView(for: dash)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color.themed([0xE0E0E0, 0xFFF8CA, 0x363636, 0x101010]))
    }
    
    @ViewBuilder
    func makeDashListView(for dash: DashList) -> some View {
        DashListView(cache: cache, dash: dash, interaction: feedDetailInteraction)
    }
}
