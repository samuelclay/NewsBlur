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

    private let maxHeight: CGFloat = 120

    var body: some View {
        VStack(spacing: 6) {
            ScrollView(.vertical, showsIndicators: false) {
                FlowLayout(spacing: 6) {
                    pillButton(label: "All", count: nil, isActive: selectedCategory == nil) {
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
                .padding(8)
            }
            .frame(maxHeight: maxHeight)
            .background(DiscoverColors.cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(DiscoverColors.border.opacity(0.6), lineWidth: 1)
            )
            .padding(.horizontal, 16)

            if let category = selectedCategory, !category.subcategories.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    FlowLayout(spacing: 6) {
                        pillButton(label: "All", count: nil, isActive: selectedSubcategory == nil) {
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
                    .padding(8)
                }
                .frame(maxHeight: maxHeight)
                .background(DiscoverColors.subcategoryBackground)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(DiscoverColors.border.opacity(0.6), lineWidth: 1)
                )
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 6)
    }

    private func pillButton(label: String, count: Int?, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                if let count = count, count > 0 {
                    Text("(\(count))")
                        .font(.system(size: 11))
                }
            }
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
}

@available(iOS 15.0, *)
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                y += lineHeight + spacing
                x = 0
                lineHeight = 0
            }
            lineHeight = max(lineHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += lineHeight + spacing
                x = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            lineHeight = max(lineHeight, size.height)
            x += size.width + spacing
        }
    }
}
