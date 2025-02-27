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
    
    var body: some View {
        GeometryReader { reader in
            ScrollView {
                ScrollViewReader { scroller in
                    switch cache.settings.dashboardLayout {
                        case .none:
                            EmptyView()
                        case .single:
                            VStack(alignment: .leading, spacing: 10) {
                                makeDashSection(for: $cache.dashboardLeft)
                                makeDashSection(for: $cache.dashboardRight)
                            }
                        case .vertical:
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 10) {
                                    makeDashSection(for: $cache.dashboardLeft)
                                }
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    makeDashSection(for: $cache.dashboardRight)
                                }
                            }
                        case .horizontal:
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top, spacing: 10) {
                                    makeDashSection(for: $cache.dashboardLeft)
                                }
                                
                                HStack(alignment: .top, spacing: 10) {
                                    makeDashSection(for: $cache.dashboardRight)
                                }
                            }
                    }
                }
            }
        }
        .background(Color.themed([0xE0E0E0, 0xFFF8CA, 0x363636, 0x101010]))
        .padding(10)
    }
    
    @ViewBuilder
    func makeDashSection(for dashes: Binding<[DashList]>) -> some View {
        Section {
            ForEach(dashes, id: \.id) { dash in
                makeDashListView(for: dash)
            }
        }
    }
    
    @ViewBuilder
    func makeDashListView(for dash: Binding<DashList>) -> some View {
        DashListView(cache: cache, dash: dash, interaction: feedDetailInteraction)
    }
}
