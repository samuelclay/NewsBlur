//
//  WidgetStoryView.swift
//  Widget Extension
//
//  Created by David Sinclair on 2021-08-11.
//  Copyright © 2021 NewsBlur. All rights reserved.
//

import WidgetKit
import SwiftUI

struct WidgetStoryView: View {
    var cache: WidgetCache
    
    var story: Story
    
    @Environment(\.widgetFamily) private var family
    
    var isCompact: Bool {
        family != .systemLarge
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let feed = cache.feed(for: story) {
                    WidgetBarView(leftColor: feed.leftColor, rightColor: feed.rightColor)
                }
                HStack {
                    if cache.preview == .largeLeft, let image = story.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 70, height: geometry.size.height)
                            .clipped()
                            .padding([.trailing], -15)
                    }
                    
                    if cache.preview == .smallLeft, let image = story.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: geometry.size.height - 6)
                            .cornerRadius(8)
                            .clipped()
                            .padding([.leading], 16)
                            .padding([.trailing], -15)
                    }
                    
                    VStack(alignment: .leading) {
                        if let feed = cache.feed(for: story) {
                            HStack {
                                if let image = cache.cachedFeedImage(for: feed.id) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .frame(width: 16, height: 16)
                                        .padding([.trailing], -3)
                                }
                                
                                Text(feed.title)
                                    .font(.custom("WhitneySSm-Medium", size: 10))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(story.date)
                                    .font(.custom("WhitneySSm-Medium", size: 10))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                                    .frame(alignment: .trailing)
                            }
                            .padding([.bottom], 0)
                        }
                        
                        Text(cache.cleaned(story.title))
                            .font(.custom("WhitneySSm-Medium", size: isCompact ? 11 : 12))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding([.top], -6)
                    }
                    .padding([.leading, .trailing])
                    
                    if cache.preview == .smallRight, let image = story.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: geometry.size.height - 6)
                            .cornerRadius(8)
                            .clipped()
                            .padding([.leading], -15)
                            .padding([.trailing], 10)
                    }
                    
                    if cache.preview == .largeRight, let image = story.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 70, height: geometry.size.height)
                            .clipped()
                            .padding([.leading], -15)
                    }
                }
            }
            .frame(minHeight: geometry.size.height, maxHeight: geometry.size.height)
        }
    }
}

struct WidgetStoryView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetStoryView(cache: WidgetCache(), story: Story(sample: "Example", feed: "sample"))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
