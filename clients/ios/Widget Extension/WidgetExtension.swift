//
//  WidgetExtension.swift
//  WidgetExtension
//
//  Created by David Sinclair on 2021-08-05.
//  Copyright © 2021 NewsBlur. All rights reserved.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), cache: WidgetExtension_Previews.cache, isPlaceholder: true)
    }

    func snapshot(for configuration: NewsBlurWidgetConfiguration, in context: Context) async -> SimpleEntry {
        let cache = WidgetCache(source: configuration.source?.id ?? "all")
        cache.loadCachedStories()
        if context.isPreview && cache.stories.isEmpty {
            return placeholder(in: context)
        }
        return SimpleEntry(date: Date(), cache: cache, isPlaceholder: false)
    }

    func timeline(for configuration: NewsBlurWidgetConfiguration, in context: Context) async -> Timeline<SimpleEntry> {
        await WidgetSourceCatalog.refresh()
        // WidgetExtension.swift creates a cache per request, never shared across widget configurations.
        let cache = WidgetCache(source: configuration.source?.id ?? "all")
        cache.loadCachedStories()
        await withCheckedContinuation { continuation in
            cache.load { continuation.resume() }
        }
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let requests = DispatchGroup()
                for feed in Set(cache.stories.map { $0.feed }) {
                    requests.enter()
                    cache.feedImage(for: feed) { _, _ in requests.leave() }
                }
                requests.notify(queue: .main) { continuation.resume() }
            }
        }
        return WidgetTimeline.make { SimpleEntry(date: $0, cache: cache, isPlaceholder: false) }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let cache: WidgetCache
    let isPlaceholder: Bool
}

struct WidgetEntryView : View {
    var entry: Provider.Entry
    
    @Environment(\.widgetRenderingMode) var renderingMode
    @Environment(\.widgetContentMargins) var margins
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) private var family
    
    var isCompact: Bool {
        family != .systemLarge
    }
    
    var body: some View {
        ZStack {
//            switch renderingMode {
//                case .accented:
//                case .fullColor:
//                case .vibrant:
//                    break
//            }
            
            if let error = entry.cache.error {
                Link(destination: URL(string: "newsblurwidget://?error=\(error)")!) {
                        Text(message(for: error))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .containerBackground(.fill, for: .widget)
                }
            } else {
                VStack(alignment: .leading, spacing: 0, content: {
                    let stories = entry.cache.stories(count: isCompact ? 3 : 6)
                    
                    ForEach(Array(stories.enumerated()), id: \.element.id) { index, story in
                        Link(destination: URL(string: entry.isPlaceholder ? "newsblurwidget://open" : "newsblurwidget://?feedId=\(story.feed)&storyHash=\(story.id)")!) {
                            WidgetStoryView(cache: entry.cache, story: story)
                        }
                        if index < stories.count - 1 {
                            Divider()
                        }
                    }
                })
                .padding(.top, 5)
                .padding(.bottom, 5)
                .containerBackground(for: .widget) {
                    Color("WidgetBackground")
                }
                .widgetURL(URL(string: "newsblurwidget://open"))
            }
        }
//        .environment(\.colorScheme, colorScheme)
        .containerBackground(for: .widget) {
            Color("WidgetBackground")
//                .ignoresSafeArea()
        }
    }
    
    func message(for error: WidgetCacheError) -> String {
        switch error {
        case .notLoggedIn:
            return NSLocalizedString("Please log in to NewsBlur", comment: "Widget status")
        case .loading:
            return NSLocalizedString("Unable to refresh stories", comment: "Widget status")
        case .noFeeds:
            return NSLocalizedString("Edit this widget to choose a folder or site", comment: "Widget status")
        case .noStories:
            return NSLocalizedString("No unread stories", comment: "Widget status")
        }
    }
}

@main
struct WidgetExtension: Widget {
    let kind: String = "SourceStories"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: NewsBlurWidgetConfiguration.self, provider: Provider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("NewsBlur")
        .description("The latest stories from NewsBlur.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
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
