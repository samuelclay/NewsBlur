//
//  FeedDetailGridView.swift
//  NewsBlur
//
//  Created by David Sinclair on 2023-01-19.
//  Copyright © 2023 NewsBlur. All rights reserved.
//

import SwiftUI

/// A protocol of interaction between a card in the grid, and the enclosing feed detail view controller.
protocol FeedDetailInteraction {
    var storyHeight: CGFloat { get }
    
    func visible(story: Story)
    func tapped(story: Story)
    func reading(story: Story)
    func hid(story: Story)
}

/// A list or grid layout of story cards for the feed detail view.
struct FeedDetailGridView: View {
    var feedDetailInteraction: FeedDetailInteraction
    
    @ObservedObject var cache: StoryCache
    
    var columns: [GridItem] {
        if cache.isGrid {
            return Array(repeating: GridItem(.flexible(), spacing: 20), count: cache.settings.gridColumns)
        } else {
            return [GridItem(.flexible())]
        }
    }
    
    var isOS15OrLater: Bool {
        if #available(iOS 15.0, *) {
            return true
        } else {
            return false
        }
    }
    
    var cardHeight: CGFloat {
        return cache.settings.gridHeight
    }
    
    var storyHeight: CGFloat {
        print("Story height: \(feedDetailInteraction.storyHeight + 20)")
        
        return feedDetailInteraction.storyHeight + 20
    }
    
//    let stories: [Story] = StoryCache.stories
    
    var body: some View {
        ScrollView {
            ScrollViewReader { scroller in
                LazyVGrid(columns: columns, spacing: cache.isGrid ? 20 : 0) {
                    Section {
                        ForEach(cache.before, id: \.id) { story in
                            makeCardView(for: story, cache: cache)
                        }
                    }
                    
                    if !cache.isGrid, let story = cache.selected {
                        makeCardView(for: story, cache: cache)
                    }
                    
                    Section(header: makeStoryView(cache: cache)) {
                        ForEach(cache.after, id: \.id) { story in
                            makeCardView(for: story, cache: cache)
                        }
                    }
                }
                .onChange(of: cache.selected) { [oldSelected = cache.selected] newSelected in
                    print("\(oldSelected?.title ?? "none") -> \(newSelected?.title ?? "none")")
                    Task {
                        try await Task.sleep(nanoseconds: 3_000_000_000)
                        withAnimation(Animation.spring().delay(0.5)) {
                            scroller.scrollTo(newSelected?.id, anchor: .top)
                        }
                    }
                }
                .if(cache.isGrid) { view in
                    view.padding()
                }
            }
        }
        .background(Color.themed([0xF4F4F4, 0xFFFDEF, 0x4F4F4F, 0x101010]))
    }
    
    @ViewBuilder
    func makeCardView(for story: Story, cache: StoryCache) -> some View {
        CardView(cache: cache, story: loaded(story: story))
            .onAppear {
                feedDetailInteraction.visible(story: story)
            }
            .onTapGesture {
                feedDetailInteraction.tapped(story: story)
            }
            .if(cache.isGrid) { view in
                view.frame(height: cardHeight)
            }
    }
    
    @ViewBuilder
    func makeStoryView(cache: StoryCache) -> some View {
        if cache.isGrid, let story = cache.selected {
            StoryView(cache: cache, story: loaded(story: story), interaction: feedDetailInteraction)
//                .frame(height: storyHeight)
        }
    }
    
    func loaded(story: Story) -> Story {
        story.load()
        return story
    }
}

//struct FeedDetailGridView_Previews: PreviewProvider {
//    static var previews: some View {
//        FeedDetailGridView(feedDetailInteraction: FeedDetailViewController(), storyCache: StoryCache())
//    }
//}
