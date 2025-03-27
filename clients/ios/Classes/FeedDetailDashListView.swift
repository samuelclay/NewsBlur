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
            
            Divider()
            
            Menu("Add Story List Before") {
                Button {
                    //TODO: 🚧
                } label: {
                    Text("Coming Soon!")
                }
                .disabled(true)
            }
            
            Menu("Add Story List After") {
                Button {
                    //TODO: 🚧
                } label: {
                    Text("Coming Soon!")
                }
            }
            
            Divider()
            
            Button {
                cache.moveEarlier(dash: dash)
            } label: {
                Text(moveEarlierTitle)
            }
            .disabled(dash.side == .left && dash.order <= 0)
            
            Button {
                cache.moveLater(dash: dash)
            } label: {
                Text(moveLaterTitle)
            }
            .disabled(dash.side == .right && dash.order >= cache.dashboardRight.count - 1)
            
            Divider()
            
            Button {
                cache.remove(dash: dash)
            } label: {
                Text("Remove This List")
            }
            .disabled(cache.dashboardLeft.count + cache.dashboardRight.count <= 1)
            
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
    
    var isHorizontal: Bool {
        return cache.settings.dashboardLayout == .horizontal
    }
    
    var isVertical: Bool {
        return cache.settings.dashboardLayout == .vertical
    }
    
    var isFirstOnLeftSide: Bool {
        return dash.side == .left && dash.order == 0
    }
    
    var isFirstOnRightSide: Bool {
        return dash.side == .right && dash.order == 0
    }
    
    var isLastOnLeftSide: Bool {
        return dash.side == .left && dash.order >= cache.dashboardLeft.count - 1
    }
    
    var isLastOnRightSide: Bool {
        return dash.side == .right && dash.order >= cache.dashboardRight.count - 1
    }
    
    var moveEarlierTitle: String {
        // Using isHorizontal and isVertical as always want to use "Up" for Single layout.
        if (isHorizontal && !isFirstOnRightSide) || (isVertical && isFirstOnRightSide) {
            return "Move This List Left"
        } else {
            return "Move This List Up"
        }
    }
    
    var moveLaterTitle: String {
        // Using isHorizontal and isVertical as always want to use "Down" for Single layout.
        if (isHorizontal && !isLastOnLeftSide) || (isVertical && isLastOnLeftSide) {
            return "Move This List Right"
        } else {
            return "Move This List Down"
        }
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
