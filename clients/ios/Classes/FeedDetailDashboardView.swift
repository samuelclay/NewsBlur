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
        ScrollView {
            if cache.dashboardAll.isEmpty {
                VStack(alignment: .center) {
                    Text("No Story Lists")
                        .foregroundColor(.secondary)
                        .font(.custom("WhitneySSm-Medium", size: 24, relativeTo: .body))
                        .frame(minHeight: 300)
                    
                    Button {
                        feedDetailInteraction.addFirstDashboard()
                    } label: {
                        Text("Add Story List")
                    }
                }
            }
            
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
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color.themed([0xE0E0E0, 0xFFF8CA, 0x363636, 0x101010]))
        .lazyPop()
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
