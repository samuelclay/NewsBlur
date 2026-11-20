//
//  DiscoverCategoryPillsView.swift
//  NewsBlur
//
//  Created by Claude on 2026-03-05.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, *)
struct DiscoverCategoryPillsView: View {
    let categories: [DiscoverCategory]
    @Binding var selectedCategory: DiscoverCategory?
    @Binding var selectedSubcategory: DiscoverSubcategory?
    var viewMode: Binding<DiscoverSitesFeedViewMode>?

    var body: some View {
        VStack(spacing: 6) {
            if let viewMode {
                if #available(iOS 16.0, *) {
                    ViewThatFits(in: .horizontal) {
                        categoryControls(viewMode: viewMode)
                        stackedCategoryControls(viewMode: viewMode)
                    }
                    .padding(.horizontal, 16)
                } else {
                    stackedCategoryControls(viewMode: viewMode)
                        .padding(.horizontal, 16)
                }
            } else {
                categoryRow.padding(.horizontal, 16)
            }

            if let category = selectedCategory, !category.subcategories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        pillButton(label: NBLocalization.text("All"), count: nil, isActive: selectedSubcategory == nil) {
                            selectedSubcategory = nil
                        }

                        ForEach(category.subcategories) { sub in
                            pillButton(
                                label: sub.name,
                                count: sub.feedCount,
                                isActive: selectedSubcategory?.id == sub.id
                            ) {
                                if selectedSubcategory?.id == sub.id {
                                    selectedSubcategory = nil
                                } else {
                                    selectedSubcategory = sub
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .accessibilityIdentifier("discover-subcategory-row")
            }
        }
        .padding(.vertical, 12)
    }

    private func categoryControls(viewMode: Binding<DiscoverSitesFeedViewMode>) -> some View {
        HStack(spacing: 8) {
            // DiscoverCategoryPillsView.swift measures the scroll viewport, not every tag, when choosing a row layout.
            categoryRow.frame(minWidth: 88, idealWidth: 88, maxWidth: .infinity)
            DiscoverViewModePicker(viewMode: viewMode)
                .layoutPriority(1)
        }
    }

    private func stackedCategoryControls(viewMode: Binding<DiscoverSitesFeedViewMode>) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            // DiscoverCategoryPillsView.swift keeps both controls reachable when enlarged labels cannot fit beside tags.
            DiscoverViewModePicker(viewMode: viewMode)
            categoryRow
        }
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pillButton(label: NBLocalization.text("All"), count: nil, isActive: selectedCategory == nil) {
                    selectedCategory = nil
                    selectedSubcategory = nil
                }

                ForEach(categories) { category in
                    pillButton(
                        label: category.name,
                        count: category.feedCount,
                        isActive: selectedCategory?.id == category.id
                    ) {
                        if selectedCategory?.id == category.id {
                            selectedCategory = nil
                            selectedSubcategory = nil
                        } else {
                            selectedCategory = category
                            selectedSubcategory = nil
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("discover-category-row")
    }

    private func pillButton(label: String, count: Int?, isActive: Bool, action: @escaping () -> Void)
        -> some View
    {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                if let count = count, count > 0 {
                    Text("(\(count))")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(isActive ? DiscoverColors.accent : DiscoverColors.cardBackground)
            .foregroundColor(isActive ? .white : DiscoverColors.textSecondary)
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(isActive ? Color.clear : DiscoverColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
