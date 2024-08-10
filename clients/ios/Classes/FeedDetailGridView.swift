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
    var hasNoMoreStories: Bool { get }
    var isPremiumRestriction: Bool { get }
    var isMarkReadOnScroll: Bool { get }
    
    func pullToRefresh()
    func visible(story: Story)
    func tapped(story: Story)
    func reading(story: Story)
    func read(story: Story)
    func unread(story: Story)
    func hid(story: Story)
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
        print("🐓 Story height: \(feedDetailInteraction.storyHeight + 20)")
        
        return feedDetailInteraction.storyHeight + 20
    }
    
    var body: some View {
        GeometryReader { reader in
            ScrollView {
                ScrollViewReader { scroller in
                    LazyVGrid(columns: columns, spacing: cache.isGrid ? 20 : 0) {
                        if cache.isPhone {
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
                            
                            if cache.isGrid && !cache.isPhone {
                                EmptyView()
                                    .id(storyViewID)
                            } else if let story = cache.selected {
                                makeCardView(for: story, reader: reader)
                                    .id(story.id)
                            }
                            
                            Section(header: makeStoryView(), footer: makeLoadingView()) {
                                ForEach(cache.after, id: \.id) { story in
                                    makeCardView(for: story, reader: reader)
                                }
                            }
                        }
                    }
                    .onChange(of: cache.selected) { [oldSelected = cache.selected] newSelected in
                        guard oldSelected?.hash != newSelected?.hash else {
                            return
                        }
                        
                        print("🪿 Selection: '\(oldSelected?.title ?? "none")' -> '\(newSelected?.title ?? "none")'")
                        
                        Task {
                            if newSelected == nil, !cache.isPhone, let oldSelected, let story = cache.story(with: oldSelected.index) {
                                scroller.scrollTo(story.id, anchor: .top)
                            } else if let newSelected, !cache.isGrid {
                                withAnimation(Animation.spring().delay(0.5)) {
                                    scroller.scrollTo(newSelected.id)
                                }
                            } else if !cache.isPhone {
                                withAnimation(Animation.spring().delay(0.5)) {
                                    scroller.scrollTo(storyViewID, anchor: .top)
                                }
                            } else if let newSelected {
                                scroller.scrollTo(newSelected.id, anchor: .top)
                            }
                        }
                    }
                    .onAppear() {
                        if cache.isGrid {
                            scroller.scrollTo(storyViewID, anchor: .top)
                        }
                    }
                    .if(cache.isGrid) { view in
                        view.padding()
                    }
                }
            }
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
        .background(Color.themed([0xE0E0E0, 0xFFF8CA, 0x363636, 0x101010]))
        .if(cache.isGrid) { view in
            view.lazyPop()
        }
    }
    
    @ViewBuilder
    func makeCardView(for story: Story, reader: GeometryProxy) -> some View {
        CardView(feedDetailInteraction: feedDetailInteraction, cache: cache, story: story)
            .transformAnchorPreference(key: CardKey.self, value: .bounds) {
                $0.append(CardFrame(id: "\(story.id)", frame: reader[$1]))
            }
            .onPreferenceChange(CardKey.self) {
                if feedDetailInteraction.isMarkReadOnScroll, let value = $0.first, value.frame.minY < -(value.frame.size.height / 2) {
                    print("🐓 Scrolled off the top: \(story.debugTitle): \($0)")
                    
//                    withAnimation(Animation.spring().delay(2)) {
                        feedDetailInteraction.read(story: story)
//                    }
                }
            }
            .onAppear {
                feedDetailInteraction.visible(story: story)
            }
            .if(cache.isGrid) { view in
                view.frame(height: cardHeight)
            }
            .gesture(DragGesture(minimumDistance: 50.0, coordinateSpace: .local)
                .onEnded { value in
                    switch(value.translation.width, value.translation.height) {
                        case (...0, -30...30):
                            feedDetailInteraction.read(story: story)
                        case (0..., -30...30):
                            feedDetailInteraction.unread(story: story)
//                        case (-100...100, ...0):  print("up swipe")
//                        case (-100...100, 0...):  print("down swipe")
                        default:  break
                    }
                }
            )
    }
    
    @ViewBuilder
    func makeStoryView() -> some View {
        if cache.isGrid, !cache.isPhone, let story = cache.selected {
            StoryView(cache: cache, story: story, interaction: feedDetailInteraction)
        }
    }
    
    @ViewBuilder
    func makeLoadingView() -> some View {
        FeedDetailLoadingView(feedDetailInteraction: feedDetailInteraction, cache: cache)
            .id(UUID())
    }
}

struct CardFrame : Equatable {
    let id : String
    let frame : CGRect
    
    static func == (lhs: CardFrame, rhs: CardFrame) -> Bool {
        lhs.id == rhs.id && lhs.frame == rhs.frame
    }
}

struct CardKey : PreferenceKey {
    typealias Value = [CardFrame]
    
    static var defaultValue: [CardFrame] = []
    
    static func reduce(value: inout [CardFrame], nextValue: () -> [CardFrame]) {
        value.append(contentsOf: nextValue())
    }
}
