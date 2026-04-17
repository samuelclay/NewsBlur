//
//  FeedDetailGridView.swift
//  NewsBlur
//
//  Created by David Sinclair on 2023-01-19.
//  Copyright © 2023 NewsBlur. All rights reserved.
//

import SwiftUI

/// A protocol of interaction between a card in the grid, and the enclosing feed detail view controller.
@MainActor protocol FeedDetailInteraction {
    var hasNoMoreStories: Bool { get }
    var isPremiumRestriction: Bool { get }
    var isMarkReadOnScroll: Bool { get }

    func pullToRefresh()
    func tapped(dash: DashList)
    func visible(story: Story)
    func tapped(story: Story, in dash: DashList?)
    func changeDashboard(dash: DashList)
    func addFirstDashboard()
    func addDashboard(before: Bool, dash: DashList)
    func reloadOneDash(with dash: DashList)
    func reading(story: Story)
    func read(story: Story)
    func unread(story: Story)
    func hid(story: Story)
    func scrolled(story: Story, offset: CGFloat?)
    func openPremiumDialog()
}

/// A list or grid layout of story cards for the feed detail view.
struct FeedDetailGridView: View {
    var feedDetailInteraction: FeedDetailInteraction
    
    @ObservedObject var cache: StoryCache
    
    @State private var scrollOffset = CGPoint()
    
    let storyViewID = "storyViewID"
    
    var columns: [GridItem] {
        if cache.isGrid {
            return Array(repeating: GridItem(.flexible(), spacing: 20), count: cache.settings.gridColumns)
        } else {
            return [GridItem(.flexible())]
        }
    }
    
    var cardHeight: CGFloat {
        return cache.settings.gridHeight
    }
    
    var body: some View {
        GeometryReader { reader in
            ScrollView {
                ScrollViewReader { scroller in
                    makeCardLayout(reader: reader)
                    .onChange(of: cache.selected) { [oldSelected = cache.selected] newSelected in
                        guard oldSelected?.hash != newSelected?.hash else {
                            return
                        }
                        
                        NSLog("🪿 Selection: '\(oldSelected?.title ?? "none")' -> '\(newSelected?.title ?? "none")'")
                        
                        if newSelected == nil, !cache.isPhoneOrCompact, let oldSelected, let story = cache.story(with: oldSelected.index) {
                            scroller.scrollTo(story.id, anchor: .top)
                        } else if let newSelected, !cache.isGridView {
                            Task {
                                withAnimation(Animation.spring().delay(0.5)) {
                                    scroller.scrollTo(newSelected.id)
                                }
                            }
                        } else if !cache.isPhoneOrCompact {
                            if cache.isGrid {
                                Task {
                                    withAnimation(Animation.spring().delay(0.5)) {
                                        scroller.scrollTo(storyViewID, anchor: .top)
                                    }
                                }
                            } else {
                                scroller.scrollTo(storyViewID, anchor: .top)
                                Task {
                                    scroller.scrollTo(storyViewID, anchor: .top)
                                }
                            }
                        } else if let newSelected {
                            Task {
                                scroller.scrollTo(newSelected.id, anchor: .top)
                            }
                        }
                    }
                    .onAppear() {
                        if cache.isGridView {
                            scroller.scrollTo(storyViewID, anchor: .top)
                        }
                    }
                    .if(cache.isGrid) { view in
                        view.padding()
                    }
                }
            }
            .accessibilityIdentifier("story-titles-scroll")
            .accessibilityElement(children: .contain)
            .modify({ view in
#if !targetEnvironment(macCatalyst)
                if #available(iOS 15.0, *) {
                    view.refreshable {
                        if cache.canPullToRefresh {
                            feedDetailInteraction.pullToRefresh()
                        }
                    }
                }
#endif
            })
        }
        .background(Color.themed([0xE0E0E0, 0xF3E2CB, 0x363636, 0x000000]))
        .if(cache.isGridView && !cache.isCompact) { view in
            view.lazyPop()
        }
    }

    @ViewBuilder
    func makeCardLayout(reader: GeometryProxy) -> some View {
        if cache.isGrid {
            LazyVGrid(columns: columns, spacing: 20) {
                makeCardSections(reader: reader)
            }
        } else {
            LazyVStack(spacing: 0) {
                makeCardSections(reader: reader)
            }
        }
    }

    @ViewBuilder
    func makeCardSections(reader: GeometryProxy) -> some View {
        if cache.isPhoneOrCompact {
            Section(footer: makeLoadingView()) {
                ForEach(cache.before, id: \.id) { story in
                    makeCardView(for: story, reader: reader)
                }

                if let story = cache.selected {
                    makeCardView(for: story, reader: reader)
                        .id(story.id)
                }

                ForEach(cache.after, id: \.id) { story in
                    makeCardView(for: story, reader: reader)
                }
            }
        } else {
            Section {
                ForEach(cache.before, id: \.id) { story in
                    makeCardView(for: story, reader: reader)
                }
            }

            if cache.isGridView && !cache.isPhoneOrCompact {
                EmptyView()
                    .id(storyViewID)
            } else if let story = cache.selected {
                makeCardView(for: story, reader: reader)
                    .id(story.id)
            }

            Section(header: makeStoryView(reader: reader), footer: makeLoadingView()) {
                ForEach(cache.after, id: \.id) { story in
                    makeCardView(for: story, reader: reader)
                }
            }
        }
    }
    
    @ViewBuilder
    func makeCardView(for story: Story, reader: GeometryProxy) -> some View {
        CardView(feedDetailInteraction: feedDetailInteraction, cache: cache, dash: nil, story: story)
            .transformAnchorPreference(key: CardKey.self, value: .bounds) {
                $0.append(CardFrame(id: "\(story.id)", frame: reader[$1]))
            }
            .onPreferenceChange(CardKey.self) {
                if !story.isClusterStory,
                   feedDetailInteraction.isMarkReadOnScroll,
                   StoryScrollReadDecision.shouldMarkRead(storyID: "\(story.id)", frames: $0) {
                    NSLog("🐓 Scrolled off the top: \(story.debugTitle): \($0)")
                    
//                    withAnimation(Animation.spring().delay(2)) {
                        feedDetailInteraction.read(story: story)
//                    }
                }
            }
            .onAppear {
                if !story.isClusterStory {
                    feedDetailInteraction.visible(story: story)
                }
            }
            .if(cache.isGrid) { view in
                view.frame(height: cardHeight)
            }
    }
    
    @ViewBuilder
    func makeStoryView(reader: GeometryProxy) -> some View {
        if cache.isGridView, !cache.isPhoneOrCompact, let story = cache.selected {
            StoryView(cache: cache, story: story, interaction: feedDetailInteraction)
                .transformAnchorPreference(key: CardKey.self, value: .bounds) {
                    $0.append(CardFrame(id: "\(story.id)", frame: reader[$1]))
                }
                .onPreferenceChange(CardKey.self) {
                    if cache.isMagazine,
                       let value = StoryScrollReadDecision.frame(for: "\(story.id)", in: $0) {
                        NSLog("🐓 Magazine story scrolled: \(story.debugTitle): \($0), minY \(value.minY), maxY: \(value.maxY), height: \(value.size.height)")
                        
                        feedDetailInteraction.scrolled(story: story, offset: value.maxY)
                    }
                }
                .onAppear {
                    feedDetailInteraction.scrolled(story: story, offset: nil)
                }
        }
    }
    
    @ViewBuilder
    func makeLoadingView() -> some View {
        FeedDetailLoadingView(feedDetailInteraction: feedDetailInteraction, cache: cache)
            .id(UUID())
    }
}

typealias CardFrame = StoryCardFrame

struct CardKey : @preconcurrency PreferenceKey {
    typealias Value = [CardFrame]
    
    @MainActor static var defaultValue: [CardFrame] = []
    
    static func reduce(value: inout [CardFrame], nextValue: () -> [CardFrame]) {
        value.append(contentsOf: nextValue())
    }
}
