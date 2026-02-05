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
            Color.themed([0xFFFDEF, 0xEEECCD, 0x606060, 0x505050])
            
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
            Button {
                interaction.changeDashboard(dash: dash)
            } label: {
                Text("Change Story List")
            }
            
            Divider()
            
            Button {
                interaction.addDashboard(before: true, dash: dash)
            } label: {
                Text("Add Story List Before")
            }
            
            Button {
                interaction.addDashboard(before: false, dash: dash)
            } label: {
                Text("Add Story List After")
            }
            
            Divider()
            
            Button {
                if isSingle && dash.order <= 0 {
                    cache.moveBetweenSides(dash: dash)
                } else {
                    cache.moveEarlier(dash: dash)
                }
            } label: {
                Text(moveEarlierTitle)
            }
            .disabled(dash.order <= 0 && (!isSingle || dash.side == .left))
            
            Button {
                if isSingle && dash.order >= dashboardForSide.count - 1 {
                    cache.moveBetweenSides(dash: dash)
                } else {
                    cache.moveLater(dash: dash)
                }
            } label: {
                Text(moveLaterTitle)
            }
            .disabled(dash.order >= dashboardForSide.count - 1 && (!isSingle || dash.side == .right))
            
            if !isSingle {
                Button {
                    cache.moveBetweenSides(dash: dash)
                } label: {
                    Text(moveBetweenSidesTitle)
                }
            }
            
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
            .onChange(of: dash.numberOfStories) { newValue in
                interaction.reloadOneDash(with: dash)
            }
            
            Picker("Ordered", selection: $dash.activeOrder) {
                Text("Newest first").tag("newest")
                Text("Oldest first").tag("oldest")
            }
            .onChange(of: dash.activeOrder) { newValue in
                interaction.reloadOneDash(with: dash)
            }
            
            Picker("Include", selection: $dash.activeReadFilter) {
                Text("All stories").tag("all")
                Text("Unread only").tag("unread")
            }
            .onChange(of: dash.activeReadFilter) { newValue in
                interaction.reloadOneDash(with: dash)
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
    
    var isSingle: Bool {
        return cache.settings.dashboardLayout == .single
    }
    
    var isHorizontal: Bool {
        return cache.settings.dashboardLayout == .horizontal
    }
    
    var isVertical: Bool {
        return cache.settings.dashboardLayout == .vertical
    }
    
    var dashboardForSide: [DashList] {
        return dash.side == .left ? cache.dashboardLeft : cache.dashboardRight
    }
    
    var moveEarlierTitle: String {
        if isHorizontal {
            return "Move This List Left"
        } else {
            return "Move This List Up"
        }
    }
    
    var moveLaterTitle: String {
        if isHorizontal {
            return "Move This List Right"
        } else {
            return "Move This List Down"
        }
    }
    
    var moveBetweenSidesTitle: String {
        if isHorizontal {
            return "Move This List \(dash.side == .left ? "Down" : "Up")"
        } else {
            return "Move This List \(dash.side == .left ? "Right" : "Left")"
        }
    }
}

struct DashListStoriesView: View {
    let cache: StoryCache
    
    let dash: DashList
    
    let interaction: FeedDetailInteraction
    
    var body: some View {
        VStack(alignment: .center, spacing: 1) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
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
