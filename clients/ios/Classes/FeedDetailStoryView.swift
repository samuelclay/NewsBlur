//
//  FeedDetailStoryView.swift
//  NewsBlur
//
//  Created by David Sinclair on 2023-02-01.
//  Copyright © 2023-2024 NewsBlur. All rights reserved.
//

import SwiftUI

/// Story view within the feed detail, only used in grid, list, and magazine layouts.
struct StoryView: View {
    let cache: StoryCache
    
    let story: Story
    
    let interaction: FeedDetailInteraction
    
    var body: some View {
//        Group {
            VStack {
                StoryHeaderView(cache: cache, story: story, interaction: interaction)
                StoryPagesView(story: story, interaction: interaction)
            }
            
        // This looks nice, but sometimes blanks out the grid view, probably due to the web view content magic, so not worth the regression.
//            StoryFeedBarView(cache: cache, story: story)
//        }
    }
}

struct StoryHeaderView: View {
    let cache: StoryCache
    
    let story: Story
    
    let interaction: FeedDetailInteraction
    
    var body: some View {
        ZStack {
            Color.themed([0xFFFDEF, 0xEEE0CE, 0x303A40, 0x303030])
            
            HStack {
                if cache.settings.preview.isLeft, let image = previewImage {
                    gridPreview(image: image)
                        .padding(.leading, 40)
                }
                
                Text(story.title)
                    .padding()
                
                Spacer()
                
                if !cache.settings.preview.isLeft, let image = previewImage {
                    gridPreview(image: image)
                }
                
                Text(story.dateString)
                    .padding()
            }
        }
        .font(.custom("WhitneySSm-Medium", size: 14, relativeTo: .body))
        .foregroundColor(Color.themed([0x686868, 0xA0A0A0]))
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            interaction.hid(story: story)
        }
    }
    
    var previewImage: UIImage? {
        guard cache.settings.preview != .none, let image = cache.appDelegate.cachedImage(forStoryHash: story.hash), image.isKind(of: UIImage.self) else {
            return nil
        }
        
        return image
    }
    
    @ViewBuilder
    func gridPreview(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 76, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct StoryPagesView: UIViewControllerRepresentable {
    typealias UIViewControllerType = StoryPagesViewController
    
    let appDelegate = NewsBlurAppDelegate.shared!
    
    let story: Story
    
    let interaction: FeedDetailInteraction
    
    func makeUIViewController(context: Context) -> StoryPagesViewController {
        appDelegate.detailViewController.prepareStoriesForGridView()
        
        return appDelegate.storyPagesViewController
    }
    
    func updateUIViewController(_ storyPagesViewController: StoryPagesViewController, context: Context) {
        storyPagesViewController.updatePage(withActiveStory: appDelegate.storiesCollection.locationOfActiveStory(), updateFeedDetail: false)
        
        interaction.reading(story: story)
        
        let size = storyPagesViewController.currentPage.webView.scrollView.contentSize
        
        storyPagesViewController.preferredContentSize = CGSize(width: size.width, height: 1000)
        
        storyPagesViewController.currentPage.webView.evaluateJavaScript(
            "document.body.lastChild.getBoundingClientRect().bottom + window.scrollY"
        ) { (result, _) in
            guard let height = result as? CGFloat, height > 0 else {
                return
            }
            
            storyPagesViewController.preferredContentSize = CGSize(width: size.width, height: height + 80)
        }
    }
}

struct StoryFeedBarView: View {
    let cache: StoryCache
    
    let story: Story
    
    var body: some View {
        GeometryReader { geometry in
            if let feed = story.feed, let color = feed.colorBarLeft {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
                }
                .stroke(Color(color), lineWidth: 4)
            }
            
            if let feed = story.feed, let color = feed.colorBarRight {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 4))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: 4))
                }
                .stroke(Color(color), lineWidth: 4)
            }
        }
    }
}
