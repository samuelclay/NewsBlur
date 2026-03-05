//
//  WebFeedTabView.swift
//  NewsBlur
//
//  Created by Claude on 2026-03-05.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, *)
struct WebFeedTabView: View {
    @ObservedObject var viewModel: DiscoverSitesViewModel
    var onTryFeed: ((DiscoverPopularFeed) -> Void)?
    var onAddFeed: ((DiscoverPopularFeed) -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                urlInputSection

                if viewModel.webFeedState.isAnalyzing {
                    analyzingSection
                }

                if let errorMessage = viewModel.webFeedState.errorMessage {
                    errorSection(errorMessage)
                }

                if !viewModel.webFeedState.variants.isEmpty {
                    variantsSection
                    configureSection
                    subscribeSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(DiscoverColors.background)
    }

    // MARK: - URL Input

    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Create a feed from any web page")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DiscoverColors.textPrimary)

            Text("Enter any web page URL and NewsBlur will use AI to analyze the page structure, find stories, and create a custom RSS feed that you can subscribe to.")
                .font(.system(size: 13))
                .foregroundColor(DiscoverColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundColor(DiscoverColors.textSecondary)

                    TextField("Enter a web page URL...", text: $viewModel.webFeedState.url)
                        .font(.system(size: 15))
                        .foregroundColor(DiscoverColors.textPrimary)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .submitLabel(.go)
                        .onSubmit {
                            viewModel.analyzeWebFeed(url: viewModel.webFeedState.url)
                        }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(DiscoverColors.textFieldBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DiscoverColors.border, lineWidth: 1)
                )

                Button(action: {
                    viewModel.analyzeWebFeed(url: viewModel.webFeedState.url)
                }) {
                    Text("Analyze")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            viewModel.webFeedState.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.webFeedState.isAnalyzing
                                ? DiscoverColors.accent.opacity(0.5)
                                : DiscoverColors.accent
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.webFeedState.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.webFeedState.isAnalyzing)
            }
        }
    }

    // MARK: - Analyzing

    private var analyzingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DiscoverColors.accent))

            Text(viewModel.webFeedState.progressMessage)
                .font(.system(size: 14))
                .foregroundColor(DiscoverColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(DiscoverColors.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(DiscoverColors.border.opacity(0.6), lineWidth: 1)
        )
    }

    // MARK: - Error

    private func errorSection(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(DiscoverColors.errorText)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(DiscoverColors.errorText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(DiscoverColors.errorText.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Variants

    private var variantsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select a feed variant")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DiscoverColors.textPrimary)

            ForEach(viewModel.webFeedState.variants) { variant in
                variantCard(variant)
            }
        }
    }

    private func variantCard(_ variant: WebFeedVariant) -> some View {
        let isSelected = viewModel.webFeedState.selectedVariantIndex == variant.id

        return Button(action: {
            viewModel.webFeedState.selectedVariantIndex = variant.id
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(variant.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DiscoverColors.textPrimary)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(DiscoverColors.accent)
                    }
                }

                if !variant.stories.isEmpty {
                    Rectangle()
                        .fill(DiscoverColors.border.opacity(0.5))
                        .frame(height: 1)

                    ForEach(variant.stories.prefix(3)) { story in
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

                                Text(story.link)
                                    .font(.system(size: 11))
                                    .foregroundColor(DiscoverColors.textSecondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)

                            if let imageUrl = story.imageUrl, let url = URL(string: imageUrl) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 40, height: 40)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    default:
                                        Color.clear
                                            .frame(width: 40, height: 40)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(12)
            .background(DiscoverColors.cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? DiscoverColors.accent : DiscoverColors.border.opacity(0.6), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Configure

    private var configureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configure")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DiscoverColors.textPrimary)

            // Custom title
            VStack(alignment: .leading, spacing: 4) {
                Text("Feed Title")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DiscoverColors.textSecondary)

                TextField("Custom feed title", text: $viewModel.webFeedState.feedTitle)
                    .font(.system(size: 14))
                    .foregroundColor(DiscoverColors.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(DiscoverColors.textFieldBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DiscoverColors.border, lineWidth: 1)
                    )
            }

            // Staleness slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Check for updates every")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DiscoverColors.textSecondary)

                    Spacer()

                    Text("\(Int(viewModel.webFeedState.stalenessDays)) \(Int(viewModel.webFeedState.stalenessDays) == 1 ? "day" : "days")")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DiscoverColors.accent)
                }

                Slider(
                    value: $viewModel.webFeedState.stalenessDays,
                    in: 1...90,
                    step: 1
                )
                .accentColor(DiscoverColors.accent)
            }

            // Mark unread toggle
            Toggle(isOn: $viewModel.webFeedState.markUnreadOnChange) {
                Text("Mark stories as unread on change")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DiscoverColors.textSecondary)
            }
            .toggleStyle(SwitchToggleStyle(tint: DiscoverColors.accent))

            // Folder picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Folder")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DiscoverColors.textSecondary)

                Menu {
                    Button(action: { viewModel.selectedFolder = "" }) {
                        HStack {
                            Text("-- Top Level --")
                            if viewModel.selectedFolder.isEmpty {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    ForEach(viewModel.folders, id: \.self) { folder in
                        Button(action: { viewModel.selectedFolder = folder }) {
                            HStack {
                                Text(viewModel.folderDisplayName(folder))
                                if viewModel.selectedFolder == folder {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(viewModel.displayFolder)
                            .font(.system(size: 14))
                            .foregroundColor(DiscoverColors.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(DiscoverColors.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(DiscoverColors.textFieldBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DiscoverColors.border, lineWidth: 1)
                    )
                }
            }
        }
        .padding(12)
        .background(DiscoverColors.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(DiscoverColors.border.opacity(0.6), lineWidth: 1)
        )
    }

    // MARK: - Subscribe

    private var subscribeSection: some View {
        Button(action: {
            viewModel.subscribeWebFeed()
        }) {
            HStack {
                if viewModel.webFeedState.isSubscribing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }

                Text(viewModel.webFeedState.isSubscribing ? "Subscribing..." : "Subscribe to Web Feed")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                viewModel.webFeedState.selectedVariantIndex == nil || viewModel.webFeedState.isSubscribing
                    ? DiscoverColors.accent.opacity(0.5)
                    : DiscoverColors.accent
            )
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(viewModel.webFeedState.selectedVariantIndex == nil || viewModel.webFeedState.isSubscribing)
    }
}
