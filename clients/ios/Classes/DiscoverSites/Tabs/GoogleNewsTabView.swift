//
//  GoogleNewsTabView.swift
//  NewsBlur
//
//  Created by Claude on 2026-03-05.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, *)
struct GoogleNewsTabView: View {
    @ObservedObject var viewModel: DiscoverSitesViewModel
    var onTryFeed: ((DiscoverPopularFeed) -> Void)?
    var onAddFeed: ((DiscoverPopularFeed) -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.googleNewsState.isLoading && !viewModel.googleNewsState.isDataLoaded {
                    loadingSection
                } else if viewModel.googleNewsState.selectedTopic == nil {
                    topicGridSection
                    searchSubscribeSection
                } else {
                    topicDetailSection
                    searchSubscribeSection
                }

                if let errorMessage = viewModel.googleNewsState.errorMessage {
                    errorSection(errorMessage)
                }

                if viewModel.addedSuccess && viewModel.addedFeedUrl != nil {
                    successSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(DiscoverColors.background)
        .onAppear {
            if !viewModel.googleNewsState.isDataLoaded {
                viewModel.loadGoogleNewsData()
            }
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DiscoverColors.accent))

            Text("Loading Google News topics...")
                .font(.system(size: 14))
                .foregroundColor(DiscoverColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Topic Grid

    private var topicGridSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose a Topic")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DiscoverColors.textPrimary)


            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(viewModel.googleNewsState.topics) { topic in
                    topicCard(topic)
                }
            }
        }
    }

    private func topicCard(_ topic: GoogleNewsTopic) -> some View {
        Button(action: {
            viewModel.googleNewsState.selectedTopic = topic
        }) {
            VStack(spacing: 8) {
                Image(systemName: topic.sfSymbol)
                    .font(.system(size: 24))
                    .foregroundColor(DiscoverColors.accent)

                Text(topic.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DiscoverColors.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(DiscoverColors.cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(DiscoverColors.border.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Topic Detail

    private var topicDetailSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Back button
            Button(action: {
                viewModel.googleNewsState.selectedTopic = nil
                viewModel.googleNewsState.selectedCategory = nil
                viewModel.googleNewsState.selectedSubcategory = nil
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .medium))
                    Text("All Topics")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(DiscoverColors.accent)
            }
            .buttonStyle(PlainButtonStyle())

            if let topic = viewModel.googleNewsState.selectedTopic {
                // Topic header
                HStack(spacing: 8) {
                    Image(systemName: topic.sfSymbol)
                        .font(.system(size: 18))
                        .foregroundColor(DiscoverColors.accent)

                    Text(topic.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(DiscoverColors.textPrimary)
                }


                // Categories for this topic
                if !viewModel.googleNewsState.categories.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.googleNewsState.categories) { category in
                            categoryRow(category)
                        }
                    }
                }

                // Subcategory pills when category selected
                if let category = viewModel.googleNewsState.selectedCategory, !category.subcategories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            subcategoryPill(label: "All", isActive: viewModel.googleNewsState.selectedSubcategory == nil) {
                                viewModel.googleNewsState.selectedSubcategory = nil
                            }

                            ForEach(category.subcategories, id: \.self) { subcategory in
                                subcategoryPill(label: subcategory, isActive: viewModel.googleNewsState.selectedSubcategory == subcategory) {
                                    if viewModel.googleNewsState.selectedSubcategory == subcategory {
                                        viewModel.googleNewsState.selectedSubcategory = nil
                                    } else {
                                        viewModel.googleNewsState.selectedSubcategory = subcategory
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func categoryRow(_ category: GoogleNewsCategory) -> some View {
        let isSelected = viewModel.googleNewsState.selectedCategory?.id == category.id

        return Button(action: {
            if isSelected {
                viewModel.googleNewsState.selectedCategory = nil
                viewModel.googleNewsState.selectedSubcategory = nil
            } else {
                viewModel.googleNewsState.selectedCategory = category
                viewModel.googleNewsState.selectedSubcategory = nil
            }
        }) {
            HStack {
                Text(category.name)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? DiscoverColors.accent : DiscoverColors.textPrimary)

                Spacer()

                if !category.subcategories.isEmpty {
                    Text("\(category.subcategories.count)")
                        .font(.system(size: 12))
                        .foregroundColor(DiscoverColors.textSecondary)
                }

                Image(systemName: isSelected ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(DiscoverColors.textSecondary)
            }
            .padding(12)
            .background(isSelected ? DiscoverColors.accent.opacity(0.1) : DiscoverColors.cardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? DiscoverColors.accent.opacity(0.4) : DiscoverColors.border.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func subcategoryPill(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isActive ? DiscoverColors.accent : DiscoverColors.cardBackground)
                .foregroundColor(isActive ? .white : DiscoverColors.textSecondary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? Color.clear : DiscoverColors.border, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Search and Subscribe

    private var searchSubscribeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(DiscoverColors.border.opacity(0.5))
                .frame(height: 1)


            // Custom query
            VStack(alignment: .leading, spacing: 4) {
                Text("Custom Search Query")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DiscoverColors.textSecondary)

                TextField("Enter a custom search query...", text: $viewModel.googleNewsState.searchQuery)
                    .font(.system(size: 14))
                    .foregroundColor(DiscoverColors.textPrimary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(DiscoverColors.textFieldBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DiscoverColors.border, lineWidth: 1)
                    )
            }

            // Language
            VStack(alignment: .leading, spacing: 4) {
                Text("Language")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DiscoverColors.textSecondary)

                TextField("en", text: $viewModel.googleNewsState.language)
                    .font(.system(size: 14))
                    .foregroundColor(DiscoverColors.textPrimary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(DiscoverColors.textFieldBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DiscoverColors.border, lineWidth: 1)
                    )
            }

            // Subscribe button
            Button(action: {
                let topic = resolvedTopicId
                let query = viewModel.googleNewsState.searchQuery.isEmpty ? nil : viewModel.googleNewsState.searchQuery
                viewModel.subscribeGoogleNews(
                    query: query,
                    topic: topic,
                    language: viewModel.googleNewsState.language
                )
            }) {
                HStack {
                    if viewModel.googleNewsState.isSubscribing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }

                    Text(viewModel.googleNewsState.isSubscribing ? "Subscribing..." : "Subscribe to Google News Feed")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    subscribeDisabled
                        ? DiscoverColors.accent.opacity(0.5)
                        : DiscoverColors.accent
                )
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(subscribeDisabled)
        }
    }

    // MARK: - Error / Success

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

    private var successSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(DiscoverColors.accent)

            Text("Successfully subscribed to Google News feed")
                .font(.system(size: 14))
                .foregroundColor(DiscoverColors.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(DiscoverColors.accent.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Helpers

    private var resolvedTopicId: String? {
        if let subcategory = viewModel.googleNewsState.selectedSubcategory {
            return subcategory
        }
        if let category = viewModel.googleNewsState.selectedCategory {
            return category.id
        }
        return viewModel.googleNewsState.selectedTopic?.id
    }

    private var subscribeDisabled: Bool {
        let hasNoSelection = viewModel.googleNewsState.selectedTopic == nil && viewModel.googleNewsState.searchQuery.isEmpty
        return hasNoSelection || viewModel.googleNewsState.isSubscribing
    }
}
