//
//  ScopeToggleView.swift
//  NewsBlur
//
//  Created by Samuel Clay on 2026-03-03.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import SwiftUI

/// Three small scope icons (feed, folder, global) that let users change classifier scope.
struct ScopeToggleView: View {
    let classifierType: String
    @Binding var activeScope: ClassifierScope
    let score: Feed.Score
    let isPremiumArchive: Bool
    var onScopeChanged: ((ClassifierScope) -> Void)?

    @State private var tooltipText: String?
    @State private var shakeAmount: CGFloat = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(ClassifierScope.allCases, id: \.self) { scope in
                Image(systemName: scope.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(iconColor(for: scope))
                    .opacity(scope == activeScope ? 1.0 : 0.5)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleTap(scope)
                    }
            }
        }
        .modifier(ShakeEffect(amount: shakeAmount))
        .overlay(tooltipOverlay, alignment: .top)
    }

    private func iconColor(for scope: ClassifierScope) -> Color {
        let isActive = scope == activeScope
        let isScored = score == .like || score == .dislike

        if !isActive {
            return isScored ? .white : Color(white: 0.55)
        }

        if isScored {
            return .white
        }

        // Active icon on neutral gray capsule — use bright distinct colors
        return scope.activeColor
    }

    private func handleTap(_ scope: ClassifierScope) {
        if scope == activeScope { return }

        if scope != .feed && !isPremiumArchive {
            withAnimation(.default) {
                shakeAmount = 1
            }
            tooltipText = "Premium Archive"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                shakeAmount = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                tooltipText = nil
            }
            return
        }

        onScopeChanged?(scope)
        activeScope = scope
        tooltipText = scope.label(for: classifierType)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if tooltipText == scope.label(for: classifierType) {
                tooltipText = nil
            }
        }
    }

    @ViewBuilder
    private var tooltipOverlay: some View {
        if let text = tooltipText {
            Text(text)
                .fixedSize()
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(tooltipBackground)
                .cornerRadius(4)
                .offset(y: -22)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: tooltipText)
                .allowsHitTesting(false)
        }
    }

    private var tooltipBackground: Color {
        if tooltipText == "Premium Archive" {
            return Color(red: 0.851, green: 0.467, blue: 0.024) // #D97706 amber
        }
        return Color(white: 0.15).opacity(0.85)
    }
}

/// A shake animation effect for denied scope changes.
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat

    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = sin(amount * .pi * 4) * 4 * amount
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}
