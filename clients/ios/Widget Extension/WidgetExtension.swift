//
//  WidgetExtension.swift
//  WidgetExtension
//
//  Created by David Sinclair on 2021-08-05.
//  Copyright © 2021 NewsBlur. All rights reserved.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    let cache = WidgetCache()
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), cache: cache, isPlaceholder: true)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), cache: cache, isPlaceholder: false)
        
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let operation = WidgetDebugTimer.start("🚧 getTimeline")
        
        cache.loadCachedStories()
        
        WidgetDebugTimer.print(operation, step: "loadCachedStories")
        
        if context.isPreview && !cache.stories.isEmpty {
            return
        }
        
        cache.load {
            WidgetDebugTimer.print(operation, step: "cache.load()")
            
            var entries: [SimpleEntry] = []
            
            // Generate a timeline consisting of five entries an hour apart, starting from the current date.
            let currentDate = Date()
            for hourOffset in 0 ..< 5 {
                #if DEBUG
                let units = Calendar.Component.minute
                #else
                let units = Calendar.Component.hour
                #endif
                let entryDate = Calendar.current.date(byAdding: units, value: hourOffset, to: currentDate)!
                let entry = SimpleEntry(date: entryDate, cache: cache, isPlaceholder: false)
                entries.append(entry)
            }
            
            let timeline = Timeline(entries: entries, policy: .atEnd)
            
            WidgetDebugTimer.print(operation, step: "making timeline")
            
            let imageRequestGroup = DispatchGroup()
            let storyFeeds = cache.stories.map { $0.feed }
            let feeds = cache.feeds.filter { storyFeeds.contains($0.id) }
            
            for feed in feeds {
                imageRequestGroup.enter()
                
                cache.feedImage(for: feed.id) { image, feed in
                    imageRequestGroup.leave()
                }
            }
            
            imageRequestGroup.notify(queue: .main) {
                WidgetDebugTimer.print(operation, step: "requesting favicons")
                
                completion(timeline)
            }
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let cache: WidgetCache
    let isPlaceholder: Bool
}

struct WidgetEntryView : View {
    var entry: Provider.Entry
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) private var family
    
    var isCompact: Bool {
        family != .systemLarge
    }
    
    var body: some View {
        ZStack {
            Color("WidgetBackground")
                .ignoresSafeArea()
            
            if let error = entry.cache.error {
                Link(destination: URL(string: "newsblurwidget://?error=\(error)")!) {
                        Text(message(for: error))
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 0, content: {
                    ForEach(entry.cache.stories(count: isCompact ? 3 : 6)) { story in
                        Link(destination: URL(string: entry.isPlaceholder ? "newsblurwidget://open" : "newsblurwidget://?feedId=\(story.feed)&storyHash=\(story.id)")!) {
                            WidgetStoryView(cache: entry.cache, story: story)
                        }
                        Divider()
                    }
                })
                    .widgetURL(URL(string: "newsblurwidget://open"))
            }
        }
    }
    
    func message(for error: WidgetCacheError) -> String {
        switch error {
        case .notLoggedIn:
            return "Please log in to NewsBlur"
        case .loading:
            return "Tap to set up in NewsBlur"
        case .noFeeds:
            return "Please choose sites to show"
        case .noStories:
            return "No stories for selected sites"
        }
    }
}

@main
struct WidgetExtension: Widget {
    let kind: String = "Latest"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("NewsBlur")
        .description("The latest stories from NewsBlur.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct WidgetExtension_Previews: PreviewProvider {
    static let cache: WidgetCache = {
        let cache = WidgetCache()
        
        cache.loadCachedStories()
        
//        cache.error = WidgetCacheError.loading
        
        let sample1 = "sample"
        let sample2 = "another"
        
        if cache.feeds.isEmpty {
            cache.feeds.append(Feed(sample: sample1, title: "Sample Feed"))
            cache.feeds.append(Feed(sample: sample2, title: "Another One"))
        }
        
        if cache.stories.isEmpty {
            cache.stories.append(Story(sample: "This is an example story", feed: sample1))
            cache.stories.append(Story(sample: "A second sample", feed: sample1))
            cache.stories.append(Story(sample: "But for a real test, we need one with a very long title, to make sure that displays sensibly", feed: sample2))
            cache.stories.append(Story(sample: "How about another sample, for good measure?", feed: sample2))
        }
        
        return cache
    }()
    
    static var previews: some View {
        WidgetEntryView(entry: SimpleEntry(date: Date(), cache: cache, isPlaceholder: true))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .colorScheme(.light)
        WidgetEntryView(entry: SimpleEntry(date: Date(), cache: cache, isPlaceholder: false))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .colorScheme(.dark)
        WidgetEntryView(entry: SimpleEntry(date: Date(), cache: cache, isPlaceholder: false))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .colorScheme(.light)
        WidgetEntryView(entry: SimpleEntry(date: Date(), cache: cache, isPlaceholder: false))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .colorScheme(.dark)
    }
}
