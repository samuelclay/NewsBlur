//
//  DiscoverFeedCardView.swift
//  NewsBlur
//
//  Created by Claude on 2026-03-05.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, *)
struct DiscoverFeedCardView: View {
    let feed: DiscoverPopularFeed
    var showStories: Bool = false
    var onTryFeed: ((DiscoverPopularFeed) -> Void)?
    var onAddFeed: ((DiscoverPopularFeed) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Feed header
            HStack(spacing: 10) {
                faviconView
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(feed.feedTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DiscoverColors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Image(systemName: "person.2")
                                .font(.system(size: 10))
                            (Text("\(feed.numSubscribers)")
                                .font(.system(size: 11, weight: .semibold))
                            + Text(" \(feed.numSubscribers == 1 ? "subscriber" : "subscribers")")
                                .font(.system(size: 11)))
                                .lineLimit(1)
                        }
                        .foregroundColor(DiscoverColors.textSecondary)

                        if feed.averageStoriesPerMonth > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 10))
                                (Text("\(feed.averageStoriesPerMonth)")
                                    .font(.system(size: 11, weight: .semibold))
                                + Text(" \(feed.averageStoriesPerMonth == 1 ? "story" : "stories")/mo")
                                    .font(.system(size: 11)))
                                    .lineLimit(1)
                            }
                            .foregroundColor(DiscoverColors.textSecondary)
                        }
                    }
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.85)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                if isSubscribed {
                    Label("Subscribed", systemImage: "checkmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DiscoverColors.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .fixedSize()
                } else {
                    HStack(spacing: 6) {
                        Button(action: { onTryFeed?(feed) }) {
                            Text("Try")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DiscoverColors.tryButtonText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(DiscoverColors.tryButtonBackground)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(DiscoverColors.border, lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: { onAddFeed?(feed) }) {
                            Text("Add")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(DiscoverColors.accent)
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .fixedSize()
                }
            }
            .padding(12)

            // Stories list
            if showStories && !feed.stories.isEmpty {
                Rectangle()
                    .fill(DiscoverColors.border.opacity(0.5))
                    .frame(height: 1)
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(feed.stories.prefix(3)) { story in
                        storyRow(story)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .background(DiscoverColors.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(DiscoverColors.border.opacity(0.6), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Favicon

    @ViewBuilder
    private var faviconView: some View {
        if let faviconUrl = feed.faviconUrl, let url = URL(string: faviconUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                default:
                    Color.clear
                }
            }
        } else {
            Color.clear
        }
    }

    // MARK: - Story Row

    private func storyRow(_ story: DiscoverStory) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(DiscoverColors.accent)
                .frame(width: 5, height: 5)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(story.title)
                    .font(.system(size: 13))
                    .foregroundColor(DiscoverColors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    if !story.authors.isEmpty {
                        Text(story.authors)
                            .font(.system(size: 11))
                            .foregroundColor(DiscoverColors.textSecondary)
                            .lineLimit(1)
                    }

                    if !story.authors.isEmpty && story.date != nil {
                        Text("\u{00B7}")
                            .font(.system(size: 11))
                            .foregroundColor(DiscoverColors.textSecondary)
                    }

                    if let date = story.date {
                        Text(relativeDate(date))
                            .font(.system(size: 11))
                            .foregroundColor(DiscoverColors.textSecondary)
                    }
                }
            }

            Spacer(minLength: 0)

            if let imageUrl = story.imageUrls.first, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    default:
                        Color.clear
                            .frame(width: 48, height: 48)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var isSubscribed: Bool {
        guard let appDelegate = NewsBlurAppDelegate.shared() else { return false }
        return appDelegate.dictFeeds?.object(forKey: feed.id) != nil
    }
}
