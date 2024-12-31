//
//  FeedDetailDashListView.swift
//  NewsBlur
//
//  Created by David Sinclair on 2024-10-29.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import Foundation
import SwiftUI

/// List view within the Dashboard.
struct DashListView: View {
    let cache: StoryCache
    
    let dash: DashList
    
    let interaction: FeedDetailInteraction
    
    var body: some View {
        VStack {
            DashListHeaderView(cache: cache, dash: dash, interaction: interaction)
            DashListStoriesView(cache: cache, dash: dash, interaction: interaction)
        }
    }
}

struct DashListHeaderView: View {
    let cache: StoryCache
    
    let dash: DashList
    
    let interaction: FeedDetailInteraction
    
    var body: some View {
        ZStack {
            Color.themed([0xFFFDEF, 0xEEECCD, 0x303A40, 0x303030])
            
            HStack {
                Spacer()
                
                if let image = dash.image {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .padding(.leading, cache.settings.spacing == .compact ? 20 : 24)
                }
                
                Text(dash.name)
                    .lineLimit(1)
                    .foregroundColor(Color.themed([0x404040, 0x404040, 0xC0C0C0, 0xB0B0B0]))
                
                Spacer()
            }
        }
        .font(.custom("WhitneySSm-Medium", size: 14, relativeTo: .body))
        .foregroundColor(Color.themed([0x686868, 0xA0A0A0]))
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
//            interaction.hid(story: story)
        }
    }
}

struct DashListStoriesView: View {
    let cache: StoryCache
    
    let dash: DashList
    
    let interaction: FeedDetailInteraction
    
    var body: some View {
        VStack(alignment: .center) {
            if dash.isLoaded {
                ForEach(dash.stories) { story in
                    CardView(feedDetailInteraction: interaction, cache: cache, story: story)
                }
            } else {
                ProgressView()
                    .padding([.top, .bottom], 200)
            }
        }
        .font(.custom("WhitneySSm-Medium", size: 14, relativeTo: .body))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
//            interaction.hid(story: story)
        }
    }
}
