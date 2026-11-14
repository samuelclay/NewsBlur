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
        Group {
            if let viewMode {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    HStack(spacing: 8) {
                        // DiscoverSearchBarView.swift keeps phone tags full width by fitting an icon picker beside search.
                        searchField.frame(minWidth: 120, maxWidth: .infinity)
                        DiscoverViewModePicker(viewMode: viewMode, compact: true)
                            .fixedSize()
                    }
                } else if #available(iOS 16.0, *) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            // DiscoverSearchBarView.swift reserves editable text width beside the search icon and clear button.
                            searchField.frame(minWidth: 200)
                            DiscoverViewModePicker(viewMode: viewMode)
                        }
                        stackedSearch(viewMode: viewMode)
                    }
                } else {
                    stackedSearch(viewMode: viewMode)
                }
            } else {
                searchField
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stackedSearch(viewMode: Binding<DiscoverSitesFeedViewMode>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            searchField
            DiscoverViewModePicker(viewMode: viewMode)
        }
    }

    private var searchField: some View {
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
                .accessibilityLabel(NBLocalization.text("Clear search"))
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
    }
}

@available(iOS 15.0, *)
struct DiscoverViewModePicker: View {
    @Binding var viewMode: DiscoverSitesFeedViewMode
    var compact = false

    var body: some View {
        Group {
            if compact {
                modeButtons(stackedLabels: false)
            } else if #available(iOS 16.0, *) {
                ViewThatFits(in: .horizontal) {
                    modeButtons(stackedLabels: false)
                    modeButtons(stackedLabels: true)
                }
            } else {
                modeButtons(stackedLabels: true)
            }
        }
        .padding(3)
        .background(DiscoverColors.border.opacity(0.35), in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(NBLocalization.text("View mode"))
    }

    private func modeButtons(stackedLabels: Bool) -> some View {
        HStack(spacing: 2) {
            modeButton(.grid, title: NBLocalization.text("Grid"), icon: "square.grid.2x2", stackedLabel: stackedLabels)
            modeButton(.list, title: NBLocalization.text("List"), icon: "list.bullet", stackedLabel: stackedLabels)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func modeButton(_ mode: DiscoverSitesFeedViewMode, title: String, icon: String, stackedLabel: Bool) -> some View {
        Button { viewMode = mode } label: {
            Group {
                if compact {
                    Image(systemName: icon)
                } else if stackedLabel {
                    VStack(spacing: 4) {
                        Image(systemName: icon)
                        Text(title)
                    }
                } else {
                    Label(title, systemImage: icon)
                        .labelStyle(.titleAndIcon)
                }
            }
            .font(compact ? .system(size: 16, weight: .medium) : .subheadline.weight(.medium))
            .padding(.horizontal, compact ? 0 : 12)
            .frame(minWidth: compact ? 44 : 0, minHeight: 44)
            .foregroundColor(viewMode == mode ? DiscoverColors.textPrimary : DiscoverColors.textSecondary)
            .background(viewMode == mode ? DiscoverColors.cardBackground : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier("discover-view-mode-\(mode == .grid ? "grid" : "list")")
        .accessibilityAddTraits(viewMode == mode ? .isSelected : [])
    }
}
