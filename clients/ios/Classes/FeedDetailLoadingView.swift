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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack {
        if feedDetailInteraction.hasNoMoreStories {
            VStack {
                if let image = UIImage(named: "fleuron.png") {
                    Image(uiImage: image)
                }

                if feedDetailInteraction.isPremiumRestriction {
                    Text(NBLocalization.text("Reading by folder is only available to"))
                        .font(.system(size: 14))
                        .foregroundColor(Color.themed([0x0c0c0c]))
                        .padding(.top)
                    Text(NBLocalization.text("premium subscribers"))
                        .font(.system(size: 14))
                        .foregroundColor(Color.themed([0x2030C0]))
                }
            }
            .padding(cache.isGrid ? 0 : 20)
            .modifier(ReaderEntrance(session: cache.motionSession, key: "end-of-stories"))
            .transition(.opacity.combined(with: .offset(y: 10)))
            .onTapGesture {
                if feedDetailInteraction.isPremiumRestriction {
                    feedDetailInteraction.openPremiumDialog()
                }
            }
        } else if cache.isGrid {
            RoundedRectangle(cornerRadius: 10)
                .fill(animate ? Color.themed([0x5C89C9, 0x666666]) : Color.themed([0xE1EBFF, 0x222222]))
                .frame(height: 120)
                .onAppear { animate.toggle() }
                .animation(reduceMotion ? nil : .easeInOut(duration: 1).repeatForever(autoreverses: true), value: animate)
                .transition(.opacity.combined(with: .offset(y: 10)))
                .modifier(ReaderEntrance(session: cache.motionSession, key: "loading-\(cache.before.count + cache.after.count)"))
        } else {
            Rectangle()
                .fill(animate ? Color.themed([0x5C89C9, 0x666666]) : Color.themed([0xE1EBFF, 0x222222]))
                .frame(height: 120)
                .padding(-20)
                .onAppear { animate.toggle() }
                .animation(reduceMotion ? nil : .easeInOut(duration: 1).repeatForever(autoreverses: true), value: animate)
                .transition(.opacity.combined(with: .offset(y: 10)))
                .modifier(ReaderEntrance(session: cache.motionSession, key: "loading-\(cache.before.count + cache.after.count)"))
        }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.24), value: feedDetailInteraction.hasNoMoreStories)
    }
}
