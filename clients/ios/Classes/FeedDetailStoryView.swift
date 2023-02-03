//
//  FeedDetailStoryView.swift
//  NewsBlur
//
//  Created by David Sinclair on 2023-02-01.
//  Copyright © 2023 NewsBlur. All rights reserved.
//

import SwiftUI

/// Story view within the feed detail, only used in grid layout.
struct StoryView: View {
    let cache: StoryCache
    
    let story: Story
    
    let interaction: FeedDetailInteraction
    
    var body: some View {
        VStack {
            ZStack {
                Color(white: 0.9)
                
                HStack {
                    Text(story.title)
                        .padding()
                    
                    Spacer()
                    
                    if let image = previewImage {
                        gridPreview(image: image)
                    }
                    
                    Text(story.dateString)
                        .padding()
                }
            }
            .font(.custom("WhitneySSm-Medium", size: 14, relativeTo: .body))
            .foregroundColor(.secondary)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture {
                interaction.storyHidden(story)
            }
            
            StoryPagesView()
        }
    }
    
    var previewImage: UIImage? {
        guard cache.settings.listPreview != .none, let image = cache.appDelegate.cachedImage(forStoryHash: story.hash), image.isKind(of: UIImage.self) else {
            return nil
        }
        
        return image
    }
    
    @ViewBuilder
    func gridPreview(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 200, height: 50)
            .clipped()
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
