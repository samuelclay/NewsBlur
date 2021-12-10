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
        ZStack {
            if let feed = cache.feed(for: story) {
                WidgetBarView(leftColor: feed.leftColor, rightColor: feed.rightColor)
            }
            HStack {
                VStack(alignment: .leading) {
                    if let feed = cache.feed(for: story) {
                        HStack {
                            if let image = cache.cachedFeedImage(for: feed.id) {
                                Image(uiImage: image)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            }
                            
                            Text(feed.title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Text(cache.cleaned(story.title))
                        .font(isCompact ? .footnote : .subheadline)
                        .lineLimit(2)
                    Text(cache.cleaned(story.content))
                        .font(isCompact ? .footnote : .subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .padding([.bottom], isCompact ? 0 : 1)
                    HStack {
                        Text(cache.cleaned(story.author))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(story.date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding([.leading, .trailing])
                .padding([.top, .bottom], 5)
                
                if let image = cache.cachedStoryImage(for: story.id) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 70)
                        .clipped()
                        .padding([.leading], -15)
                }
            }
        }
    }
}

struct WidgetStoryView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetStoryView(cache: WidgetCache(), story: Story(sample: "Example", feed: "sample"))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
