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

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(DiscoverColors.textSecondary)

                TextField(placeholder, text: $text)
                    .font(.system(size: 15))
                    .foregroundColor(DiscoverColors.textPrimary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .onSubmit { onSubmit?() }

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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
