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
            VStack(alignment: .leading) {
                if let feed = cache.feed(for: story) {
                    Text(feed.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(height: 15)
                }
                Text(cache.cleaned(story.title))
                    .font(.subheadline)
                    .frame(height: isCompact ? 18 : 42)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
                Text(cache.cleaned(story.content))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: isCompact ? 25 : 42)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                HStack {
                    Text(cache.cleaned(story.author).uppercased())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(height: 15)
                    Spacer()
                    Text(story.date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding([.leading, .trailing])
            .padding([.top, .bottom], 5)
        }
    }
}

struct WidgetStoryView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetStoryView(cache: WidgetCache(), story: Story(sample: "Example", feed: "sample"))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
