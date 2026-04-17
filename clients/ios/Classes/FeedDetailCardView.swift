//
//  FeedDetailCardView.swift
//  NewsBlur
//
//  Created by David Sinclair on 2023-02-01.
//  Copyright © 2023 NewsBlur. All rights reserved.
//

import SwiftUI

/// Card view within the feed detail view, representing a story row in list layout or a story card in grid layout.
struct CardView: View {
    let feedDetailInteraction: FeedDetailInteraction
    
    let cache: StoryCache
    
    let dash: DashList?
    
    let story: Story
    
    @State private var swipeDragOffset: CGFloat = 0
    @State private var settledSwipeOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            if story.isClusterStory {
                clusterCardBody
                    .contentShape(Rectangle())
                    .onTapGesture {
                        feedDetailInteraction.tapped(story: story, in: dash)
                    }
            } else if cache.isNonGridStoryTitlesLayout {
                swipeableStandardCardBody
            } else {
                standardCardBody
                    .contentShape(Rectangle())
                    .onTapGesture {
                        feedDetailInteraction.tapped(story: story, in: dash)
                    }
            }
        }
        .if(!story.isClusterStory && !cache.isNonGridStoryTitlesLayout) { view in
            view.swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button {
                    toggleReadState()
                } label: {
                    Label(story.isRead ? "Mark Unread" : "Mark Read",
                          image: story.isRead ? "indicator-unread" : "indicator-read")
                }
                .tint(Color.themed([story.isRead ? 0xD4A020 : 0x4CAF50,
                                    story.isRead ? 0xC89628 : 0x4A9648,
                                    story.isRead ? 0xBF8C1C : 0x2E7D32,
                                    story.isRead ? 0xA67C00 : 0x1B5E20]))

                Button {
                    toggleSavedState()
                } label: {
                    Label(story.isSaved ? "Unsave" : "Save", image: "saved-stories")
                }
                .tint(Color.themed([story.isSaved ? 0x00838F : 0x26C6DA,
                                    story.isSaved ? 0x007A86 : 0x1FB5C8,
                                    story.isSaved ? 0x00636E : 0x0FA3B5,
                                    story.isSaved ? 0x004A52 : 0x0B8FA0]))

                Button {
                    shareStory()
                } label: {
                    Label("Share", image: "email")
                }
                .tint(Color.themed([0x8E8E93, 0x847A6E, 0x545458, 0x48484A]))
            }
        }
        .if(!story.isClusterStory) { view in
            view.contextMenu {
                if !cache.isDashboard {
                    Button {
                        cache.appDelegate.storiesCollection.toggleStoryUnread(story.dictionary)
                        cache.appDelegate.feedDetailViewController.reload()
                    } label: {
                        Label(story.isRead ? "Mark as unread" : "Mark as read", image: "mark-read")
                    }

                    Button {
                        cache.appDelegate.activeStory = story.dictionary
                        cache.appDelegate.feedDetailViewController.markFeedsRead(fromTimestamp: story.timestamp, andOlder: false)
                        cache.appDelegate.feedDetailViewController.reload()
                    } label: {
                        Label("Mark newer stories read", image: "mark-read")
                    }

                    Button {
                        cache.appDelegate.activeStory = story.dictionary
                        cache.appDelegate.feedDetailViewController.markFeedsRead(fromTimestamp: story.timestamp, andOlder: true)
                        cache.appDelegate.feedDetailViewController.reload()
                    } label: {
                        Label("Mark older stories read", image: "mark-read")
                    }

                    Divider()

                    Button {
                        cache.appDelegate.storiesCollection.toggleStorySaved(story.dictionary)
                        cache.appDelegate.feedDetailViewController.reload()
                    } label: {
                        Label(story.isSaved ? "Unsave this story" : "Save this story", image: "saved-stories")
                    }
                }

                Button {
                    cache.appDelegate.activeStory = story.dictionary
                    cache.appDelegate.showSend(to: cache.appDelegate.feedDetailViewController, sender: cache.appDelegate.feedDetailViewController.view)
                } label: {
                    Label("Send this story to…", image: "email")
                }

                Button {
                    cache.appDelegate.activeStory = story.dictionary
                    cache.appDelegate.openTrainStory(cache.appDelegate.feedDetailViewController.view)
                } label: {
                    Label("Train this story", image: "train")
                }
            }
        }
        .accessibilityIdentifier(storyAccessibilityIdentifier)
        .accessibilityElement(children: .contain)
    }

    private var storyAccessibilityIdentifier: String {
        "story-row-\(story.hash.isEmpty ? story.id : story.hash)"
    }

    private var standardCardBody: some View {
        ZStack(alignment: .leading) {
            if story.isSelected || cache.isGrid || cache.isDashboard {
                if cache.isNonGridStoryTitlesLayout || cache.isDashboard {
                    Rectangle().foregroundColor(highlightColor)
                } else {
                    RoundedRectangle(cornerRadius: 10).foregroundColor(highlightColor)
                }
                
                CardFeedBarView(cache: cache, story: story)
                    .padding(.leading, 2)
            } else {
                CardFeedBarView(cache: cache, story: story)
                    .padding(.leading, 2)
            }
            
            VStack(spacing: 0) {
                if cache.isGrid, let previewImage {
                    gridPreview(image: previewImage)
                }
                
                HStack {
                    if !cache.isGrid, cache.settings.preview.isLeft, let previewImage {
                        listPreview(image: previewImage)
                    }
                    
                    CardContentView(cache: cache, story: story)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .padding(.leading, cache.isNonGridStoryTitlesLayout ? 8 : (cache.settings.spacing == .compact ? 8 : 14))
                        .padding(.trailing, cache.isNonGridStoryTitlesLayout ? 6 : (cache.settings.spacing == .compact ? 6 : 8))
                        .padding([.top, .bottom], cache.isNonGridStoryTitlesLayout ? (cache.settings.spacing == .compact ? 8 : 10) : (cache.settings.spacing == .compact ? 10 : 15))
                    
                    if !cache.isGrid, !cache.settings.preview.isLeft, let previewImage {
                        listPreview(image: previewImage)
                    }
                }
            }
        }
        .opacity(cache.isNonGridStoryTitlesLayout ? 1 : (story.isRead ? 0.7 : 1))
        .if(cache.isGrid || cache.isDashboard) { view in
            view.clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .if(story.isSelected && !cache.isNonGridStoryTitlesLayout) { view in
            view.padding(10)
        }
    }

    private var swipeableStandardCardBody: some View {
        ZStack(alignment: .trailing) {
            if areSwipeActionsVisible {
                swipeActionButtons
            }

            standardCardBody
                .background(nonGridRowBackgroundColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: swipeOffset)
                .allowsHitTesting(!isSwipeRowOpen)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isSwipeRowOpen {
                        closeSwipeActions()
                    } else {
                        feedDetailInteraction.tapped(story: story, in: dash)
                    }
                }
        }
        .clipped()
        .onChange(of: cache.openSwipeStoryID) { newValue in
            guard newValue != story.id else { return }

            swipeDragOffset = 0
            settledSwipeOffset = 0
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .local)
                .onChanged { value in
                    guard shouldTrackSwipe(for: value) else { return }

                    if cache.openSwipeStoryID != story.id {
                        cache.openSwipeStoryID = story.id
                        settledSwipeOffset = 0
                    }

                    swipeDragOffset = value.translation.width
                }
                .onEnded { value in
                    handleSwipeEnded(for: value)
                }
        )
    }

    private var clusterCardBody: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .foregroundColor(clusterListBackgroundColor)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cache.settings.spacing == .compact ? 6 : 8)
                    .foregroundColor(clusterBackgroundColor)

                CardFeedBarView(cache: cache, story: story)
                    .padding(.leading, 2)

                HStack(spacing: 8) {
                    if let indicatorImage = clusterIndicatorImage {
                        Image(uiImage: indicatorImage)
                            .resizable()
                            .frame(width: story.score == 0 ? 10 : 12, height: story.score == 0 ? 10 : 12)
                            .opacity(story.isRead ? 0.15 : 1)
                    }

                    if let favicon = story.feed?.image {
                        Image(uiImage: favicon)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .opacity(story.isRead ? 0.4 : 1)
                    }

                    Text(story.title)
                        .font(Font.custom("WhitneySSm-Medium", size: 13, relativeTo: .caption))
                        .foregroundColor(clusterTitleColor)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if !clusterBadgeText.isEmpty {
                        Text(clusterBadgeText)
                            .font(Font.custom("WhitneySSm-Medium", size: 9, relativeTo: .caption2))
                            .foregroundColor(clusterBadgeColor)
                            .kerning(0.45)
                            .padding(.horizontal, 7)
                            .frame(height: 16)
                            .overlay(
                                Capsule()
                                    .stroke(clusterBadgeColor, lineWidth: 1)
                            )
                    }

                    Spacer(minLength: 4)

                    if let previewImage = clusterPreviewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 24, height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .opacity(story.isRead ? 0.55 : 1)
                    }

                    Text(story.dateString)
                        .font(Font.custom("WhitneySSm-Medium", size: 10, relativeTo: .caption2))
                        .foregroundColor(clusterMetaColor)
                        .lineLimit(1)
                }
                .padding(.leading, 13)
                .padding(.trailing, 12)
            }
            .padding(.leading, 18)
            .padding(.trailing, 10)
        }
        .frame(height: cache.settings.spacing == .compact ? 36 : 42)
    }
    
    var highlightColor: Color {
        if cache.isGrid || cache.isDashboard {
            return Color.themed([0xFDFCFA, 0xFAF5ED, 0x4F4F4F, 0x000000])
        } else {
            return Color.themed([0xFFFDEF, 0xEEE0CE, 0x303A40, 0x000000])
        }
    }
    
    var previewImage: UIImage? {
        guard cache.settings.preview != .none, let image = cache.appDelegate.cachedImage(forStoryHash: story.hash), image.isKind(of: UIImage.self) else {
            return nil
        }

        return image
    }

    var clusterPreviewImage: UIImage? {
        guard let image = cache.appDelegate.cachedImage(forStoryHash: story.hash), image.isKind(of: UIImage.self) else {
            return nil
        }

        return image
    }

    var clusterIndicatorImage: UIImage? {
        UIImage(named: StoryClusterDisplayDecision.indicatorImageName(forScore: story.score))
    }

    var clusterBadgeText: String {
        StoryClusterDisplayDecision.clusterTierLabel(forValue: story.clusterTier).uppercased()
    }

    var clusterListBackgroundColor: Color {
        Color.themed([0xF4F4F4, 0xF3E2CB, 0x4F4F4F, 0x000000])
    }

    var clusterBackgroundColor: Color {
        Color.themed([0xE8F0F8, 0xECDEC9, 0x363C43, 0x101418])
    }

    var clusterTitleColor: Color {
        if story.isRead {
            return Color.themed([0x585858, 0x585858, 0x989898, 0x888888])
        } else {
            return Color.themed([0x202020, 0x333333, 0xD8D8D8, 0xD0D0D0])
        }
    }

    var clusterMetaColor: Color {
        if story.isRead {
            return Color.themed([0x9A9A9A, 0x8B7B6B, 0x7F7F7F, 0x707070])
        } else {
            return Color.themed([0x808080, 0x8B7B6B, 0xA0A0A0, 0x8F8F8F])
        }
    }

    var clusterBadgeColor: Color {
        if story.clusterTier == "title" {
            return Color.themed([0x5A8C6A, 0x6E865F, 0x7DC99A, 0x7DC99A])
        } else {
            return Color.themed([0xA88246, 0x9B7540, 0xD2A76B, 0xD2A76B])
        }
    }

    private var swipeOffset: CGFloat {
        clampedSwipeOffset(displayedSettledSwipeOffset + swipeDragOffset)
    }

    private var swipeActionWidth: CGFloat {
        84
    }

    private var maxSwipeOffset: CGFloat {
        swipeActionWidth * 3
    }

    private var openSwipeThreshold: CGFloat {
        maxSwipeOffset * 0.45
    }

    private var fullSwipeThreshold: CGFloat {
        maxSwipeOffset * 0.9
    }

    private var swipeAnimation: Animation {
        .spring(response: 0.28, dampingFraction: 0.88)
    }

    private var isSwipeRowOpen: Bool {
        cache.openSwipeStoryID == story.id && settledSwipeOffset != 0
    }

    private var displayedSettledSwipeOffset: CGFloat {
        cache.openSwipeStoryID == story.id ? settledSwipeOffset : 0
    }

    private var areSwipeActionsVisible: Bool {
        swipeOffset < -1
    }

    private var nonGridRowBackgroundColor: Color {
        Color.themed([0xE0E0E0, 0xF3E2CB, 0x363636, 0x000000])
    }

    private var swipeActionButtons: some View {
        HStack(spacing: 0) {
            swipeActionButton(title: story.isRead ? "Mark Unread" : "Mark Read",
                              imageName: story.isRead ? "indicator-unread" : "indicator-read",
                              tint: Color.themed([story.isRead ? 0xD4A020 : 0x4CAF50,
                                                  story.isRead ? 0xC89628 : 0x4A9648,
                                                  story.isRead ? 0xBF8C1C : 0x2E7D32,
                                                  story.isRead ? 0xA67C00 : 0x1B5E20]),
                              action: toggleReadState)

            swipeActionButton(title: story.isSaved ? "Unsave" : "Save",
                              imageName: "saved-stories",
                              tint: Color.themed([story.isSaved ? 0x00838F : 0x26C6DA,
                                                  story.isSaved ? 0x007A86 : 0x1FB5C8,
                                                  story.isSaved ? 0x00636E : 0x0FA3B5,
                                                  story.isSaved ? 0x004A52 : 0x0B8FA0]),
                              action: toggleSavedState)

            swipeActionButton(title: "Share",
                              imageName: "email",
                              tint: Color.themed([0x8E8E93, 0x847A6E, 0x545458, 0x48484A]),
                              action: shareStory)
        }
        .frame(width: maxSwipeOffset)
        .frame(maxHeight: .infinity, alignment: .trailing)
    }

    private func swipeActionButton(title: String, imageName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
            closeSwipeActions()
        } label: {
            VStack(spacing: 4) {
                if let image = UIImage(named: imageName) {
                    Image(uiImage: image)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                }

                Text(title)
                    .font(Font.custom("WhitneySSm-Medium", size: 11, relativeTo: .caption2))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(.white)
            .frame(width: swipeActionWidth)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(tint)
    }

    private func shouldTrackSwipe(for value: DragGesture.Value) -> Bool {
        let horizontal = value.translation.width
        let vertical = value.translation.height

        guard abs(horizontal) > abs(vertical) else { return false }
        if !isSwipeRowOpen {
            return horizontal < 0
        }

        return true
    }

    private func handleSwipeEnded(for value: DragGesture.Value) {
        defer {
            swipeDragOffset = 0
        }

        guard shouldTrackSwipe(for: value) else {
            if value.translation.width > 32, isSwipeRowOpen {
                closeSwipeActions()
            }
            return
        }

        let proposedOffset = clampedSwipeOffset(displayedSettledSwipeOffset + value.translation.width)
        let predictedOffset = clampedSwipeOffset(displayedSettledSwipeOffset + value.predictedEndTranslation.width)

        if predictedOffset <= -fullSwipeThreshold {
            toggleReadState()
            closeSwipeActions()
            return
        }

        withAnimation(swipeAnimation) {
            if proposedOffset <= -openSwipeThreshold {
                cache.openSwipeStoryID = story.id
                settledSwipeOffset = -maxSwipeOffset
            } else {
                closeSwipeActions(animated: false)
            }
        }
    }

    private func closeSwipeActions() {
        closeSwipeActions(animated: true)
    }

    private func closeSwipeActions(animated: Bool) {
        let update = {
            if cache.openSwipeStoryID == story.id {
                cache.openSwipeStoryID = nil
            }

            swipeDragOffset = 0
            settledSwipeOffset = 0
        }

        guard animated else {
            update()
            return
        }

        withAnimation(swipeAnimation) {
            update()
        }
    }

    private func clampedSwipeOffset(_ candidate: CGFloat) -> CGFloat {
        min(0, max(-maxSwipeOffset, candidate))
    }

    private func toggleReadState() {
        cache.appDelegate.storiesCollection.toggleStoryUnread(story.dictionary)
        cache.appDelegate.feedDetailViewController.reload()
    }

    private func toggleSavedState() {
        cache.appDelegate.storiesCollection.toggleStorySaved(story.dictionary)
        cache.appDelegate.feedDetailViewController.reload()
    }

    private func shareStory() {
        cache.appDelegate.activeStory = story.dictionary
        cache.appDelegate.showSend(to: cache.appDelegate.feedDetailViewController,
                                   sender: cache.appDelegate.feedDetailViewController.view)
    }
    
    @ViewBuilder
    func gridPreview(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(height: cache.settings.gridHeight / 3)
            .cornerRadius(10, corners: .topRight)
            .padding(0)
            .padding(.leading, 8)
    }
    
    @ViewBuilder
    func listPreview(image: UIImage) -> some View {
        let isLeft = cache.settings.preview.isLeft
        
        if cache.isNonGridStoryTitlesLayout {
            if cache.settings.preview.isSmall {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.vertical, 14)
                    .padding(.leading, isLeft ? 14 : 0)
                    .padding(.trailing, isLeft ? 0 : 14)
                    .opacity(story.isRead ? 0.34 : 1)
            } else {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: listPreviewWidth)
                    .frame(maxHeight: .infinity)
                    .clipped()
                    .padding(.leading, isLeft ? 2 : 0)
                    .opacity(story.isRead ? 0.34 : 1)
            }
        } else if cache.settings.preview.isSmall {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: listPreviewWidth)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding([.top, .bottom], 10)
                .padding(.leading, isLeft ? 15 : -10)
                .padding(.trailing, isLeft ? -10 : 10)
        } else {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: listPreviewWidth + 10)
                .clipped()
                .padding(.leading, isLeft ? 8 : -10)
                .padding(.trailing, isLeft ? -10 : 0)
        }
    }
    
    var listPreviewWidth: CGFloat {
        if cache.isMagazine {
            switch cache.settings.content {
                case .title:
                    return 150
                case .short:
                    return 200
                case .medium:
                    return 300
                case .long:
                    return 350
            }
        } else {
            return 80
        }
    }
}

struct CardContentView: View {
    let cache: StoryCache
    
    let story: Story
    
    var body: some View {
        VStack(alignment: .leading) {
            if let feed = story.feed, feed.isRiverOrSocial, let feedImage = feed.image {
                HStack {
                    Image(uiImage: feedImage)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .padding(.leading, cache.settings.spacing == .compact ? 20 : 24)
                    
                    Text(feed.name)
                        .font(font(named: "WhitneySSm-Medium", size: 12))
                        .lineLimit(1)
                        .foregroundColor(feedColor)
                }
            }
            
            HStack(alignment: .top) {
                if let unreadImage {
                    Image(uiImage: unreadImage)
                        .resizable()
                        .opacity(story.isRead ? 0.15 : 1)
                        .frame(width: 10, height: 10)
                        .padding(.top, 4)
                        .padding(.leading, 5)
                }
                
                VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        if story.isSaved, let image = UIImage(named: "saved-stories") {
                            Image(uiImage: image)
                                .resizable()
                                .opacity(story.isRead ? 0.15 : 1)
                                .frame(width: 16, height: 16)
                                .padding(.top, 3)
                        }
                        
                        if story.isShared, let image = UIImage(named: "share") {
                            Image(uiImage: image)
                                .resizable()
                                .opacity(story.isRead ? 0.15 : 1)
                                .frame(width: 16, height: 16)
                                .padding(.top, 3)
                        }
                        
                        Text(story.title)
                            .font(font(named: "WhitneySSm-Medium", size: 16).bold())
                            .foregroundColor(titleColor)
                            .lineLimit(titleLimit)
                            .truncationMode(.tail)
                        
                        if !cache.isDashboard, cache.isList {
                            Spacer()
                            
                            Text(story.dateAndAuthor)
                                .font(font(named: "WhitneySSm-Medium", size: 12))
                                .foregroundColor(dateAndAuthorColor)
                                .padding([.top, .leading, .trailing], 5)
                        }
                    }
                    .padding(.bottom, cache.settings.spacing == .compact ? -5 : 0)
                    
                    if cache.isGrid || cache.settings.content != .title {
                        Text(content)
                            .font(font(named: "WhitneySSm-Book", size: 14))
                            .foregroundColor(contentColor)
                            .lineLimit(contentLimit)
                            .truncationMode(.tail)
                            .padding(.top, 5)
                            .padding(.bottom, cache.settings.spacing == .compact ? -5 : 0)
                    }
                    
                    if cache.isDashboard || !cache.isList {
                        Spacer()
                        
                        Text(story.dateAndAuthor)
                            .font(font(named: "WhitneySSm-Medium", size: 12))
                            .foregroundColor(dateAndAuthorColor)
                            .padding(.top, 5)
                    }
                }.padding(.leading, -4)
            }
        }
    }
    
    var unreadImage: UIImage? {
        guard story.isReadAvailable else {
            return nil
        }
        
        switch story.score {
        case -1:
            return UIImage(named: "indicator-hidden")
        case 1:
            return UIImage(named: "indicator-focus")
        default:
            return UIImage(named: "indicator-unread")
        }
    }
    
    func font(named: String, size: CGFloat) -> Font {
        return Font.custom(named, size: size + cache.settings.fontSize.offset, relativeTo: .caption)
    }
    
    var titleLimit: Int {
        if cache.isDashboard {
            return cache.settings.content.baseLimit * 2
        } else if cache.isList {
            return cache.settings.content.baseLimit
        } else if cache.isMagazine {
            return cache.settings.content.baseLimit * 4
        } else if cache.isGrid {
            return StorySettings.Content.titleLimit
        } else {
            return cache.settings.content.baseLimit * 2
        }
    }
    
    var contentLimit: Int {
        if cache.isDashboard {
            return cache.settings.content.baseLimit * 2
        } else if cache.isList {
            return cache.settings.content.baseLimit
        } else if cache.isMagazine {
            return cache.settings.content.baseLimit * 4
        } else if cache.isGrid {
            return StorySettings.Content.contentLimit
        } else {
            return cache.settings.content.baseLimit * 2
        }
    }
    
    var content: String {
        if cache.isMagazine {
            return story.longContent
        } else {
            return story.shortContent
        }
    }
    
    var feedColor: Color {
        return contentColor
    }
    
    var titleColor: Color {
        if story.isSelected {
            return Color.themed([0x686868, 0xA0A0A0])
        } else if story.isRead {
            return Color.themed([0x585858, 0x585858, 0x989898, 0x888888])
        } else {
            return Color.themed([0x111111, 0x333333, 0xD0D0D0, 0xCCCCCC])
        }
    }
    
    var contentColor: Color {
        if story.isSelected, story.isRead {
            return Color.themed([0xB8B8B8, 0xB8B8B8, 0xA0A0A0, 0x707070])
        } else if story.isSelected {
            return Color.themed([0x888785, 0x686868, 0xA9A9A9, 0x989898])
        } else if story.isRead {
            return Color.themed([0xB8B8B8, 0xB8B8B8, 0xA0A0A0, 0x707070])
        } else {
            return Color.themed([0x404040, 0x404040, 0xC0C0C0, 0xB0B0B0])
        }
    }
    
    var dateAndAuthorColor: Color {
        return contentColor
    }
}

struct CardFeedBarView: View {
    let cache: StoryCache
    
    let story: Story
    
    var body: some View {
        GeometryReader { geometry in
            if let colorBar {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                }
                .stroke(Color(colorBar.left), lineWidth: 4)
                
                Path { path in
                    path.move(to: CGPoint(x: 4, y: 0))
                    path.addLine(to: CGPoint(x: 4, y: geometry.size.height))
                }
                .stroke(Color(colorBar.right), lineWidth: 4)
            }
        }
    }
    
    var colorBar: (left: UIColor, right: UIColor)? {
        guard let feed = story.feed, let left = feed.colorBarLeft, let right = feed.colorBarRight else {
            return nil
        }
        
        if story.isRead {
            return (left: left.withAlphaComponent(0.4), right: right.withAlphaComponent(0.4))
        } else {
            return (left: left, right: right)
        }
    }
}
