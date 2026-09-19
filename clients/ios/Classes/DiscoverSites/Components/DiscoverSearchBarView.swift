//
//  DiscoverSearchBarView.swift
//  NewsBlur
//
//  Created by Claude on 2026-03-05.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, *)
struct DiscoverSearchBarView: View {
    var placeholder: String = "Search..."
    @Binding var text: String
    var isLoading: Bool = false
    var onSubmit: (() -> Void)?
    var viewMode: Binding<DiscoverSitesFeedViewMode>?

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(DiscoverColors.textSecondary)

                TextField(placeholder, text: $text)
                    .font(.body)
                    .foregroundColor(DiscoverColors.textPrimary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .onSubmit { onSubmit?() }
                    .accessibilityIdentifier("discover-search-field")

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DiscoverColors.textSecondary))
                        .scaleEffect(0.8)
                } else if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(DiscoverColors.textSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Clear search")
                    .frame(minWidth: 32, minHeight: 44)
                }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(DiscoverColors.textFieldBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DiscoverColors.border, lineWidth: 1)
            )

            if let viewMode {
                DiscoverViewModePicker(viewMode: viewMode)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 15.0, *)
struct DiscoverViewModePicker: View {
    @Binding var viewMode: DiscoverSitesFeedViewMode

    var body: some View {
        HStack(spacing: 2) {
            modeButton(.grid, title: "Grid", icon: "square.grid.2x2")
            modeButton(.list, title: "List", icon: "list.bullet")
        }
        .padding(3)
        .background(DiscoverColors.border.opacity(0.35), in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("View mode")
    }

    private func modeButton(_ mode: DiscoverSitesFeedViewMode, title: String, icon: String) -> some View {
        Button { viewMode = mode } label: {
            Label(title, systemImage: icon)
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .foregroundColor(viewMode == mode ? DiscoverColors.textPrimary : DiscoverColors.textSecondary)
                .background(viewMode == mode ? DiscoverColors.cardBackground : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("discover-view-mode-\(mode == .grid ? "grid" : "list")")
        .accessibilityAddTraits(viewMode == mode ? .isSelected : [])
    }
}
