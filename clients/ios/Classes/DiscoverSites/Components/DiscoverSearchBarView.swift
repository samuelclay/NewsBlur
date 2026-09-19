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

            if let viewMode = viewMode {
                Picker("View Mode", selection: viewMode) {
                    Image(systemName: "square.grid.2x2")
                        .tag(DiscoverSitesFeedViewMode.grid)
                    Image(systemName: "list.bullet")
                        .tag(DiscoverSitesFeedViewMode.list)
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
                .accessibilityIdentifier("discover-view-mode")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
