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
    @EnvironmentObject var discovery: DiscoverSitesViewModel
    let feed: DiscoverPopularFeed
    var showStories: Bool = false
    var onTryFeed: ((DiscoverPopularFeed) -> Void)?
    var onOpenStory: ((DiscoverPopularFeed, DiscoverStory) -> Void)?
    var onAddFeed: ((DiscoverPopularFeed) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                faviconView
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(feed.feedTitle.isEmpty ? feed.feedAddress : feed.feedTitle)
                        .font(.headline)
                        .foregroundColor(DiscoverColors.textPrimary)
                        .lineLimit(2)
                    Text(URL(string: feed.feedLink.isEmpty ? feed.feedAddress : feed.feedLink)?.host ?? feed.feedAddress)
                        .font(.caption)
                        .foregroundColor(DiscoverColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            statisticsView

            if let description = feed.rawFeedDict["description"] as? String, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(DiscoverColors.textSecondary)
                    .lineLimit(3)
            }

            if showStories && !feed.stories.isEmpty {
                Divider()
                ForEach(feed.stories.prefix(3)) { story in
                    Button { onOpenStory?(feed, story) } label: {
                        storyRow(story)
                    }
                    .buttonStyle(DiscoverStoryButtonStyle(isSelected: discovery.selectedPreviewStoryID == story.id))
                    .disabled(discovery.isPreparingPreview)
                    .accessibilityIdentifier("discover-story-\(story.id)")
                    .accessibilityAddTraits(discovery.selectedPreviewStoryID == story.id ? .isSelected : [])
                }
            }

            Divider()
            HStack(spacing: 8) {
                Button(action: { onTryFeed?(feed) }) {
                    Label("Try", systemImage: "doc.text.magnifyingglass")
                        .frame(minWidth: 62, minHeight: 44)
                }
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel("Try \(feed.feedTitle)")
                .accessibilityIdentifier("discover-try-feed-\(feed.id)")
                .disabled(discovery.isPreparingPreview)
                .foregroundColor(DiscoverColors.tryButtonText)
                if isSubscribed {
                    Spacer(minLength: 0)
                    Label("Subscribed", systemImage: "checkmark.circle.fill")
                        .foregroundColor(DiscoverColors.accent)
                        .frame(minHeight: 44)
                } else {
                    Spacer(minLength: 16)
                    DiscoverFolderPicker(viewModel: discovery,
                                         identifier: "discover-folder-picker-\(feed.id)")
                    Button(action: { onAddFeed?(feed) }) {
                        Label("Add", systemImage: "plus")
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .foregroundColor(.white)
                            .background(DiscoverColors.accent, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel("Add \(feed.feedTitle)")
                    .accessibilityIdentifier("discover-add-feed-\(feed.id)")
                    .disabled(discovery.isAdding)
                }
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DiscoverColors.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(DiscoverColors.border.opacity(0.6), lineWidth: 1))
    }

    // MARK: - Statistics

    private var statisticsView: some View {
        Group {
            if let freshness = feed.freshness() {
                if #available(iOS 16.0, *) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            countsView
                            freshnessView(freshness)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        stackedStatistics(freshness)
                    }
                } else {
                    stackedStatistics(freshness)
                }
            } else {
                countsView
            }
        }
        .font(.caption)
        .foregroundColor(DiscoverColors.textSecondary)
    }

    private var countsView: some View {
        HStack(spacing: 12) {
            Label(subscriberLabel, systemImage: "person.2")
                .accessibilityIdentifier("discover-subscribers-\(feed.id)")
            if feed.averageStoriesPerMonth > 0 {
                Text(verbatim: "\(feed.averageStoriesPerMonth.formatted()) \(feed.averageStoriesPerMonth == 1 ? "story" : "stories")/month")
                    .accessibilityIdentifier("discover-story-count-\(feed.id)")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func stackedStatistics(_ freshness: DiscoverFeedFreshness) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            countsView
            freshnessView(freshness)
        }
    }

    private func freshnessView(_ freshness: DiscoverFeedFreshness) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(DiscoverColors.freshnessDot(freshness.status))
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(freshness.label)
                .foregroundColor(DiscoverColors.freshnessText(freshness.status))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("discover-freshness-\(feed.id)")
    }

    // MARK: - Favicon

    @ViewBuilder
    private var faviconView: some View {
        if let faviconData = feed.faviconData,
           !faviconData.isEmpty,
           let data = Data(base64Encoded: faviconData),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else if let faviconUrl = feed.faviconUrl, !faviconUrl.isEmpty, let url = URL(string: faviconUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                case .failure:
                    defaultFavicon
                default:
                    defaultFavicon
                        .opacity(0.4)
                }
            }
        } else {
            defaultFavicon
        }
    }

    private var defaultFavicon: some View {
        Image(systemName: "globe")
            .font(.system(size: 14))
            .foregroundColor(DiscoverColors.textSecondary)
            .frame(width: 24, height: 24)
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
                    .accessibilityIdentifier("discover-story-title-\(story.id)")

                if !story.excerpt.isEmpty {
                    Text(story.excerpt)
                        .font(.system(size: 12))
                        .foregroundColor(DiscoverColors.textSecondary)
                        .lineLimit(2)
                        .accessibilityIdentifier("discover-story-excerpt-\(story.id)")
                }

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
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var subscriberLabel: String {
        "\(feed.numSubscribers.formatted()) \(feed.numSubscribers == 1 ? "subscriber" : "subscribers")"
    }

    private var isSubscribed: Bool {
        if discovery.addedFeedURLs.contains(feed.feedAddress) { return true }

        guard let appDelegate = NewsBlurAppDelegate.shared() else { return false }
        return appDelegate.dictFeeds?.object(forKey: feed.id) != nil
    }
}

@available(iOS 15.0, *)
private struct DiscoverStoryButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(DiscoverColors.accent.opacity(configuration.isPressed ? 0.24 : isSelected ? 0.14 : 0),
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(DiscoverColors.accent.opacity(configuration.isPressed || isSelected ? 0.5 : 0), lineWidth: 1))
    }
}

@available(iOS 15.0, *)
struct DiscoverFolderPicker: View {
    @ObservedObject var viewModel: DiscoverSitesViewModel
    let identifier: String

    var body: some View {
        Menu {
            Button { viewModel.selectedFolder = "" } label: {
                Label("Top Level", systemImage: viewModel.selectedFolder.isEmpty ? "checkmark" : "folder")
            }
            ForEach(viewModel.folders, id: \.self) { folder in
                Button { viewModel.selectedFolder = folder } label: {
                    Label(viewModel.folderDisplayName(folder),
                          systemImage: viewModel.selectedFolder == folder ? "checkmark" : "folder")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(viewModel.selectedFolder.isEmpty ? "Top Level" : viewModel.displayFolder)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(DiscoverColors.textPrimary)
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(DiscoverColors.textFieldBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(DiscoverColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add to folder")
        .accessibilityValue(viewModel.displayFolder)
        .accessibilityIdentifier(identifier)
    }
}
