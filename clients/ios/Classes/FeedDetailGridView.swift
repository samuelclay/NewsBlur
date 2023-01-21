//
//  FeedDetailGridView.swift
//  NewsBlur
//
//  Created by David Sinclair on 2023-01-19.
//  Copyright © 2023 NewsBlur. All rights reserved.
//

import SwiftUI

// NOTE: this code is rather untidy, as it is experimental; it'll get cleaned up later.

class Story: Identifiable {
    let id = UUID()
    let index: Int
//    lazy var title: String = {
//       return "lazy story #\(index)"
//    }()
    
    var dictionary: [String : Any]?
    
    var feedID = ""
    var feedName = ""
    var title = ""
    var content = ""
    var dateString = ""
    var timestamp = 0
    var isSaved = false
    var isShared = false
    var hash = ""
    var author = ""
    
    var dateAndAuthor: String {
        let date = Utilities.formatShortDate(fromTimestamp: timestamp) ?? ""
        
        return author.isEmpty ? date : "\(date) · \(author)"
    }
    
    var feedColorBar: UIColor?
    var feedColorBarTopBorder: UIColor?
    
    var isSelected: Bool {
        return index == NewsBlurAppDelegate.shared!.storiesCollection.indexOfActiveStory()
    }
    
    init(index: Int) {
        self.index = index
    }
    
    private func string(for key: String) -> String {
        guard let dictionary else {
            return ""
        }
        
        return dictionary[key] as? String ?? ""
    }
    
    func load() {
        guard let appDelegate = NewsBlurAppDelegate.shared, let storiesCollection = appDelegate.storiesCollection,
              index < storiesCollection.activeFeedStoryLocations.count,
              let row = storiesCollection.activeFeedStoryLocations[index] as? Int,
              let story = storiesCollection.activeFeedStories[row] as? [String : Any] else {
            return
        }
        
        dictionary = story
        
        feedID = appDelegate.feedIdWithoutSearchQuery(string(for: "story_feed_id"))
        feedName = string(for: "feed_title")
        title = (string(for: "story_title") as NSString).decodingHTMLEntities()
        content = String(string(for: "story_content").convertHTML().decodingXMLEntities().decodingHTMLEntities().replacingOccurrences(of: "\n", with: " ").prefix(500))
        author = string(for: "story_authors").replacingOccurrences(of: "\"", with: "")
        dateString = string(for: "short_parsed_date")
        timestamp = dictionary?["story_timestamp"] as? Int ?? 0
        isSaved = dictionary?["starred"] as? Bool ?? false
        isShared = dictionary?["shared"] as? Bool ?? false
        hash = string(for: "story_hash")
        
        //TODO: 🚧 might make some of these lazy computed properties
//        // feed color bar border
//        unsigned int colorBorder = 0;
//        NSString *faviconColor = [feed valueForKey:@"favicon_fade"];
//
//        if ([faviconColor class] == [NSNull class] || !faviconColor) {
//            faviconColor = @"707070";
//        }
//        NSScanner *scannerBorder = [NSScanner scannerWithString:faviconColor];
//        [scannerBorder scanHexInt:&colorBorder];
//
//        cell.feedColorBar = UIColorFromFixedRGB(colorBorder);
//
//        // feed color bar border
//        NSString *faviconFade = [feed valueForKey:@"favicon_color"];
//        if ([faviconFade class] == [NSNull class] || !faviconFade) {
//            faviconFade = @"505050";
//        }
//        scannerBorder = [NSScanner scannerWithString:faviconFade];
//        [scannerBorder scanHexInt:&colorBorder];
//        cell.feedColorBarTopBorder =  UIColorFromFixedRGB(colorBorder);
//
//        // favicon
//        cell.siteFavicon = [appDelegate getFavicon:feedIdStr];
//        cell.hasAlpha = NO;
//
//        // undread indicator
//
//        int score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
//        cell.storyScore = score;
//
//        cell.isRead = ![storiesCollection isStoryUnread:story];
//        cell.isReadAvailable = ![storiesCollection.activeFolder isEqualToString:@"saved_stories"];
//        cell.textSize = self.textSize;
//        cell.isShort = NO;
//
//        UIInterfaceOrientation orientation = self.view.window.windowScene.interfaceOrientation;
//        if (!self.isPhoneOrCompact &&
//            !appDelegate.detailViewController.storyTitlesOnLeft &&
//            UIInterfaceOrientationIsPortrait(orientation)) {
//            cell.isShort = YES;
//        }
//
//        cell.isRiverOrSocial = NO;
//        if (storiesCollection.isRiverView ||
//            storiesCollection.isSavedView ||
//            storiesCollection.isReadView ||
//            storiesCollection.isWidgetView ||
//            storiesCollection.isSocialView ||
//            storiesCollection.isSocialRiverView) {
//            cell.isRiverOrSocial = YES;
//        }
    }
}

extension Story: Equatable {
    static func == (lhs: Story, rhs: Story) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Story: CustomDebugStringConvertible {
    var debugDescription: String {
        return "Story \"\(title)\" in \(feedName)"
    }
}

class StoryCache: ObservableObject {
    let appDelegate = NewsBlurAppDelegate.shared!
    
    var isGrid: Bool {
        return appDelegate.detailViewController.layout == .grid
    }
    
    @Published var before = [Story]()
    @Published var selected: Story?
    @Published var after = [Story]()
    
    func appendStories(beforeSelection: [Int], selectedIndex: Int, afterSelection: [Int]) {
        before = beforeSelection.map { Story(index: $0) }
        selected = selectedIndex >= 0 ? Story(index: selectedIndex) : nil
        after = afterSelection.map { Story(index: $0) }
    }
}

struct CardView: View {
    let cache: StoryCache
    
    let story: Story
    
    var previewImage: UIImage? {
        guard let image = cache.appDelegate.cachedImage(forStoryHash: story.hash), image.isKind(of: UIImage.self) else {
            return nil
        }
        
        return image
    }
    
    var body: some View {
        if cache.isGrid {
            ZStack {
                RoundedRectangle(cornerRadius: 12).foregroundColor(.init(white: 0.9))
                
                VStack {
                    //                RoundedRectangle(cornerRadius: 12).foregroundColor(.random)
                    //                    .frame(height: 200)
                    
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
//                            .clipped()
//                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .cornerRadius(12, corners: [.topLeft, .topRight])
                            .padding(0)
                    }
                    
                    CardContentView(story: story)
                        .frame(maxHeight: .infinity, alignment: .leading)
                        .padding(10)
                        .padding(.leading, 20)
                }
            }
        } else {
            ZStack {
                if story.isSelected {
                    RoundedRectangle(cornerRadius: 12).foregroundColor(.init(white: 0.9))
                }
                
                HStack {
                    CardContentView(story: story)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 20)
                    
                    if let previewImage {
                        //                    RoundedRectangle(cornerRadius: 12).foregroundColor(.random)
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        //                        .clipped()
                    }
                }
                .if(story.isSelected) { view in
                    view.padding(10)
                }
            }
        }
    }
}

//struct CardView_Previews: PreviewProvider {
//    static var previews: some View {
//        CardView(cache: StoryCache(), story: Story(index: 0))
//    }
//}

struct CardContentView: View {
    let story: Story
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(story.title)
                .font(.custom("WhitneySSm-Medium", size: 18, relativeTo: .caption).bold())
            Text(story.content.prefix(400))
                .font(.custom("WhitneySSm-Book", size: 13, relativeTo: .caption))
                .padding(.top, 5)
            Spacer()
            Text(story.dateAndAuthor)
                .font(.custom("WhitneySSm-Medium", size: 10, relativeTo: .caption))
                .padding(.top, 5)
        }
    }
}

struct StoryPagesView: UIViewControllerRepresentable {
    typealias UIViewControllerType = StoryPagesViewController
    
    let appDelegate = NewsBlurAppDelegate.shared!
    
    func makeUIViewController(context: Context) -> StoryPagesViewController {
        appDelegate.detailViewController.prepareStoriesForGridView()
        
        return appDelegate.storyPagesViewController
    }
    
    func updateUIViewController(_ storyPagesViewController: StoryPagesViewController, context: Context) {
        storyPagesViewController.updatePage(withActiveStory: appDelegate.storiesCollection.locationOfActiveStory(), updateFeedDetail: false)
    }
}

struct StoryView: View {
    let story: Story
    
    var body: some View {
        VStack {
            Text(story.title)
            StoryPagesView()
        }
    }
}

extension Color {
    static var random: Color {
        return Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

extension View {
    @ViewBuilder
    func modify<Content: View>(@ViewBuilder _ transform: (Self) -> Content?) -> some View {
        if let view = transform(self), !(view is EmptyView) {
            view
        } else {
            self
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

//extension View {
//    @ViewBuilder
//    func swipe() -> some View {
//        if #available(iOS 15, *) {
//            self.swipeActions {
//                Button("Order") {
//                    print("Awesome!")
//                }
//                .tint(.green)
//            }
//        }
//    }
//}

protocol FeedDetailInteraction {
    func storyAppeared(_ story: Story)
    func storyTapped(_ story: Story)
}

struct FeedDetailGridView: View {
    var feedDetailInteraction: FeedDetailInteraction
    
    @ObservedObject var cache: StoryCache
    
    var columns: [GridItem] {
        if cache.isGrid {
            return [GridItem(.flexible(), spacing: 20),
                    GridItem(.flexible(), spacing: 20),
                    GridItem(.flexible(), spacing: 20),
            ]
        } else {
            return [GridItem(.flexible()),
            ]
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
        //TODO: 🚧 switch based on grid card height
        return 400
    }
    
    var storyHeight: CGFloat {
        //TODO: 🚧 determine ideal height of story view
        return 1000
    }
    
//    let stories: [Story] = StoryCache.stories
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                Section {
                    ForEach(cache.before) { story in
                        makeCardView(for: story, cache: cache)
                    }
                }
                    
                if !cache.isGrid, let story = cache.selected {
                    makeCardView(for: story, cache: cache)
                }
                
                Section(header: makeStoryView(cache: cache)) {
                    ForEach(cache.after) { story in
                        makeCardView(for: story, cache: cache)
                    }
                }
            }
            .padding()
        }
    }
    
    func makeCardView(for story: Story, cache: StoryCache) -> some View {
        return CardView(cache: cache, story: self.loaded(story: story))
            .onAppear {
                feedDetailInteraction.storyAppeared(story)
            }
            .onTapGesture {
                feedDetailInteraction.storyTapped(story)
            }
            .if(cache.isGrid) { view in
                view.frame(height: cardHeight)
            }
    }
    
    @ViewBuilder
    func makeStoryView(cache: StoryCache) -> some View {
        if cache.isGrid, let story = cache.selected {
            StoryView(story: story)
                .frame(height: storyHeight)
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
