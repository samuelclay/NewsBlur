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
    
    @Binding var dash: DashList
    
    let interaction: FeedDetailInteraction
    
    var body: some View {
        VStack {
            DashListHeaderView(cache: cache, dash: $dash, interaction: interaction)
            DashListStoriesView(cache: cache, dash: dash, interaction: interaction)
        }
    }
}

struct DashListHeaderView: View {
    let cache: StoryCache
    
    @Binding var dash: DashList
    
    let interaction: FeedDetailInteraction
    
    var body: some View {
        ZStack {
            Color.themed([0xFFFDEF, 0xEEECCD, 0x303A40, 0x303030])
            
            HStack {
                if dash.isFetching {
                    ProgressView()
                        .padding(.leading, 10)
                }
                
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
                
                DashListActionMenu(cache: cache, dash: $dash, interaction: interaction)
                    .padding(.trailing, 10)
            }
        }
        .font(.custom("WhitneySSm-Medium", size: 14, relativeTo: .body))
        .foregroundColor(Color.themed([0x686868, 0xA0A0A0]))
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            interaction.tapped(dash: dash)
        }
    }
}

struct DashListActionMenu: View {
    let cache: StoryCache
    
    @Binding var dash: DashList
    
    let interaction: FeedDetailInteraction
    
    var body: some View {
        Menu {
            Menu("Change Story List to") {
                Button {
                    //TODO: 🚧
                } label: {
                    Text("Coming Soon!")
                        .disabled(true)
                }
            }
            
            Menu("Add Story List") {
                Button {
                    //TODO: 🚧
                } label: {
                    Text("Coming Soon!")
                        .disabled(true)
                }
            }
            
            Divider()
            
            Button {
                //TODO: 🚧
            } label: {
                Text("Remove This List")
                    .disabled(true)
            }
            
            Divider()
            
            Picker("Show", selection: $dash.numberOfStories) {
                Text("5 stories").tag(5)
                Text("10 stories").tag(10)
                Text("15 stories").tag(15)
                Text("20 stories").tag(20)
            }
            
            Picker("Ordered", selection: $dash.activeOrder) {
                Text("Newest first").tag("newest")
                Text("Oldest first").tag("oldest")
            }
            
            Picker("Include", selection: $dash.activeReadFilter) {
                Text("All stories").tag("all")
                Text("Unread only").tag("unread")
            }
        } label: {
            if #available(iOS 15.0, *) {
                Image(systemName: "ellipsis.circle")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.themed([0x686868, 0xA0A0A0]))
            } else {
                Image(systemName: "ellipsis.circle")
            }
        }
        .modify { view in
            if #available(iOS 16.0, *) {
                view.menuStyle(.button)
                    .menuIndicator(.hidden)
            }
        }
        .buttonStyle(.borderless)
        .font(.custom("WhitneySSm-Medium", size: 14, relativeTo: .body))
    }
}

struct DashListStoriesView: View {
    let cache: StoryCache
    
    let dash: DashList
    
    let interaction: FeedDetailInteraction
    
    var body: some View {
        VStack(alignment: .center) {
            if let stories = dash.stories {
                if stories.isEmpty {
                    Spacer()
                    Text("No Stories")
                        .foregroundColor(.secondary)
                        .font(.custom("WhitneySSm-Medium", size: 24, relativeTo: .body))
                        .frame(minHeight: 300)
                    Spacer()
                } else {
                    ForEach(stories) { story in
                        CardView(feedDetailInteraction: interaction, cache: cache, dash: dash, story: story)
                    }
                }
            } else {
                Spacer()
                Text("Loading…")
                    .foregroundColor(.secondary)
                    .font(.custom("WhitneySSm-Medium", size: 24, relativeTo: .body))
                    .frame(minHeight: 300)
                Spacer()
            }
        }
        .font(.custom("WhitneySSm-Medium", size: 14, relativeTo: .body))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
//            interaction.hid(story: story)
        }
    }
}
