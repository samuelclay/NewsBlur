//
//  FeedDetailLoadingView.swift
//  NewsBlur
//
//  Created by David Sinclair on 2023-05-26.
//  Copyright © 2023 NewsBlur. All rights reserved.
//

import SwiftUI

struct FeedDetailLoadingView: View {
    let feedDetailInteraction: FeedDetailInteraction
    
    let cache: StoryCache

    @State private var animate = true
    
    var body: some View {
        if feedDetailInteraction.hasNoMoreStories {
            VStack {
                if let image = UIImage(named: "fleuron.png") {
                    Image(uiImage: image)
                }
                
                if feedDetailInteraction.isPremiumRestriction {
                    Text("Reading by folder is only available to")
                        .font(.system(size: 14))
                        .foregroundColor(Color.themed([0x0c0c0c]))
                        .padding(.top)
                    Text("premium subscribers")
                        .font(.system(size: 14))
                        .foregroundColor(Color.themed([0x2030C0]))
                }
            }
            .padding(cache.isGrid ? 0 : 20)
        } else if cache.isGrid {
            RoundedRectangle(cornerRadius: 10)
                .fill(animate ? Color.themed([0x5C89C9, 0x666666]) : Color.themed([0xE1EBFF, 0x222222]))
                .frame(height: 120)
                .onAppear { animate.toggle() }
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: animate)
        } else {
            Rectangle()
                .fill(animate ? Color.themed([0x5C89C9, 0x666666]) : Color.themed([0xE1EBFF, 0x222222]))
                .frame(height: 120)
                .padding(-20)
                .onAppear { animate.toggle() }
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: animate)
        }
    }
}
