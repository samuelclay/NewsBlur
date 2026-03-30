//
//  DiscoverTabBarView.swift
//  NewsBlur
//
//  Created by Claude on 2026-03-05.
//  Copyright 2026 NewsBlur. All rights reserved.
//

import SwiftUI

@available(iOS 15.0, *)
struct DiscoverTabBarView: View {
    @Binding var activeTab: DiscoverTab

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DiscoverTab.allCases) { tab in
                        tabCapsule(tab)
                            .id(tab)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(DiscoverColors.cardBackground)
            .onChange(of: activeTab) { newTab in
                withAnimation {
                    proxy.scrollTo(newTab, anchor: .center)
                }
            }
        }
    }

    private func tabCapsule(_ tab: DiscoverTab) -> some View {
        Button(action: { activeTab = tab }) {
            HStack(spacing: 5) {
                Image(systemName: tab.sfSymbol)
                    .font(.system(size: 12))
                Text(tab.label)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(tab == activeTab ? DiscoverColors.accent : DiscoverColors.cardBackground)
            .foregroundColor(tab == activeTab ? .white : DiscoverColors.textSecondary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(tab == activeTab ? Color.clear : DiscoverColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
