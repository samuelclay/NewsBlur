//
//  StoryTraverseBar.swift
//  NewsBlur
//
//  Created by Samuel Clay on 2026-02-11.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import UIKit

/// Builds and manages the story traversal bar at the bottom of the story detail view.
/// Replaces the old XIB-based traverse buttons with native, theme-aware controls.
@objcMembers
class StoryTraverseBar: NSObject {

    // MARK: - Public Views

    let leftGroupView = UIView()
    let rightGroupView = UIView()

    let textButton = UIButton(type: .system)
    let sendButton = UIButton(type: .system)
    let previousButton = UIButton(type: .system)
    let nextButton = UIButton(type: .system)

    private(set) var circularProgressView: THCircularProgressView!
    let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    /// Tap target overlaying the progress circle.
    let progressTapArea = UIView()

    // MARK: - Private Views

    private let leftSeparator = UIView()
    private let rightSeparator = UIView()
    private let textActiveHighlight = UIView()

    // MARK: - Helpers

    private var buttonFont: UIFont {
        UIFont(name: "WhitneySSm-Medium", size: 13) ?? .systemFont(ofSize: 13, weight: .medium)
    }

    private func sym(_ name: String, size: CGFloat = 13, weight: UIImage.SymbolWeight = .medium) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: weight)
        return UIImage(systemName: name, withConfiguration: config)
    }

    private func fontTransformer() -> UIConfigurationTextAttributesTransformer {
        let font = self.buttonFont
        return UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = font
            return out
        }
    }

    // MARK: - Setup

    /// Builds the traverse bar inside the given container, replacing its existing subviews.
    func setup(in traverseView: UIView) {
        traverseView.subviews.forEach { $0.removeFromSuperview() }
        traverseView.backgroundColor = .clear

        buildLeftGroup(in: traverseView)
        buildRightGroup(in: traverseView)
        buildLayout(in: traverseView)
        updateTheme()
    }

    // MARK: - Left Group (Text + Send)

    private func buildLeftGroup(in container: UIView) {
        leftGroupView.translatesAutoresizingMaskIntoConstraints = false
        leftGroupView.layer.cornerRadius = 12
        leftGroupView.layer.cornerCurve = .continuous
        leftGroupView.clipsToBounds = true
        container.addSubview(leftGroupView)

        // Subtle highlight behind text button when text view is active
        textActiveHighlight.translatesAutoresizingMaskIntoConstraints = false
        textActiveHighlight.alpha = 0
        textActiveHighlight.layer.cornerRadius = 8
        textActiveHighlight.layer.cornerCurve = .continuous
        leftGroupView.addSubview(textActiveHighlight)

        // Text / Story toggle button
        var textConfig = UIButton.Configuration.plain()
        textConfig.image = sym("doc.plaintext")
        textConfig.title = "Text"
        textConfig.imagePadding = 6
        textConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 10)
        textConfig.titleTextAttributesTransformer = fontTransformer()
        textButton.configuration = textConfig
        textButton.translatesAutoresizingMaskIntoConstraints = false
        leftGroupView.addSubview(textButton)

        // Separator
        leftSeparator.translatesAutoresizingMaskIntoConstraints = false
        leftGroupView.addSubview(leftSeparator)

        // Share / Send button
        var sendConfig = UIButton.Configuration.plain()
        sendConfig.image = sym("square.and.arrow.up", size: 14)
        sendConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        sendButton.configuration = sendConfig
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        leftGroupView.addSubview(sendButton)
    }

    // MARK: - Right Group (Prev + Progress + Next)

    private func buildRightGroup(in container: UIView) {
        rightGroupView.translatesAutoresizingMaskIntoConstraints = false
        rightGroupView.layer.cornerRadius = 12
        rightGroupView.layer.cornerCurve = .continuous
        rightGroupView.clipsToBounds = true
        container.addSubview(rightGroupView)

        // Previous story button
        var prevConfig = UIButton.Configuration.plain()
        prevConfig.image = sym("chevron.left", size: 14, weight: .semibold)
        prevConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14)
        previousButton.configuration = prevConfig
        previousButton.translatesAutoresizingMaskIntoConstraints = false
        rightGroupView.addSubview(previousButton)

        // Separator
        rightSeparator.translatesAutoresizingMaskIntoConstraints = false
        rightGroupView.addSubview(rightSeparator)

        // Circular progress indicator
        let radius: CGFloat = 8
        circularProgressView = THCircularProgressView(
            center: CGPoint(x: radius, y: 20),
            radius: radius,
            lineWidth: radius / 4.0,
            progressMode: THProgressModeFill,
            progressColor: UIColor(white: 0.6, alpha: 0.4),
            progressBackgroundMode: THProgressBackgroundModeCircumference,
            progressBackgroundColor: UIColor(white: 0.3, alpha: 0.04),
            percentage: 0
        )
        circularProgressView.translatesAutoresizingMaskIntoConstraints = false
        rightGroupView.addSubview(circularProgressView)

        // Activity spinner (overlays progress when loading)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        rightGroupView.addSubview(loadingIndicator)

        // Tap area over the progress circle
        progressTapArea.translatesAutoresizingMaskIntoConstraints = false
        progressTapArea.backgroundColor = .clear
        rightGroupView.addSubview(progressTapArea)

        // Next / Done button
        var nextConfig = UIButton.Configuration.plain()
        nextConfig.title = "Next"
        nextConfig.image = sym("chevron.right", size: 12, weight: .semibold)
        nextConfig.imagePlacement = .trailing
        nextConfig.imagePadding = 4
        nextConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 14)
        nextConfig.titleTextAttributesTransformer = fontTransformer()
        nextButton.configuration = nextConfig
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        rightGroupView.addSubview(nextButton)
    }

    // MARK: - Constraints

    private func buildLayout(in container: UIView) {
        let groupHeight: CGFloat = 40

        NSLayoutConstraint.activate([
            // -- Left group positioning --
            leftGroupView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            leftGroupView.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -2),
            leftGroupView.heightAnchor.constraint(equalToConstant: groupHeight),

            // Text button fills left side
            textButton.leadingAnchor.constraint(equalTo: leftGroupView.leadingAnchor),
            textButton.topAnchor.constraint(equalTo: leftGroupView.topAnchor),
            textButton.bottomAnchor.constraint(equalTo: leftGroupView.bottomAnchor),

            // Text active highlight inset behind text button
            textActiveHighlight.leadingAnchor.constraint(equalTo: textButton.leadingAnchor, constant: 4),
            textActiveHighlight.trailingAnchor.constraint(equalTo: textButton.trailingAnchor, constant: -2),
            textActiveHighlight.topAnchor.constraint(equalTo: textButton.topAnchor, constant: 4),
            textActiveHighlight.bottomAnchor.constraint(equalTo: textButton.bottomAnchor, constant: -4),

            // Left separator
            leftSeparator.leadingAnchor.constraint(equalTo: textButton.trailingAnchor),
            leftSeparator.topAnchor.constraint(equalTo: leftGroupView.topAnchor, constant: 8),
            leftSeparator.bottomAnchor.constraint(equalTo: leftGroupView.bottomAnchor, constant: -8),
            leftSeparator.widthAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),

            // Send button
            sendButton.leadingAnchor.constraint(equalTo: leftSeparator.trailingAnchor),
            sendButton.topAnchor.constraint(equalTo: leftGroupView.topAnchor),
            sendButton.bottomAnchor.constraint(equalTo: leftGroupView.bottomAnchor),
            sendButton.trailingAnchor.constraint(equalTo: leftGroupView.trailingAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 44),

            // -- Right group positioning --
            rightGroupView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            rightGroupView.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -2),
            rightGroupView.heightAnchor.constraint(equalToConstant: groupHeight),
            rightGroupView.leadingAnchor.constraint(greaterThanOrEqualTo: leftGroupView.trailingAnchor, constant: 12),

            // Previous button
            previousButton.leadingAnchor.constraint(equalTo: rightGroupView.leadingAnchor),
            previousButton.topAnchor.constraint(equalTo: rightGroupView.topAnchor),
            previousButton.bottomAnchor.constraint(equalTo: rightGroupView.bottomAnchor),
            previousButton.widthAnchor.constraint(equalToConstant: 44),

            // Right separator
            rightSeparator.leadingAnchor.constraint(equalTo: previousButton.trailingAnchor),
            rightSeparator.topAnchor.constraint(equalTo: rightGroupView.topAnchor, constant: 8),
            rightSeparator.bottomAnchor.constraint(equalTo: rightGroupView.bottomAnchor, constant: -8),
            rightSeparator.widthAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),

            // Progress circle
            circularProgressView.leadingAnchor.constraint(equalTo: rightSeparator.trailingAnchor, constant: 8),
            circularProgressView.centerYAnchor.constraint(equalTo: rightGroupView.centerYAnchor),
            circularProgressView.widthAnchor.constraint(equalToConstant: 16),
            circularProgressView.heightAnchor.constraint(equalToConstant: 16),

            // Loading indicator (same position)
            loadingIndicator.centerXAnchor.constraint(equalTo: circularProgressView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: circularProgressView.centerYAnchor),

            // Progress tap area
            progressTapArea.leadingAnchor.constraint(equalTo: rightSeparator.trailingAnchor),
            progressTapArea.topAnchor.constraint(equalTo: rightGroupView.topAnchor),
            progressTapArea.bottomAnchor.constraint(equalTo: rightGroupView.bottomAnchor),
            progressTapArea.widthAnchor.constraint(equalToConstant: 32),

            // Next button
            nextButton.leadingAnchor.constraint(equalTo: circularProgressView.trailingAnchor, constant: 2),
            nextButton.topAnchor.constraint(equalTo: rightGroupView.topAnchor),
            nextButton.bottomAnchor.constraint(equalTo: rightGroupView.bottomAnchor),
            nextButton.trailingAnchor.constraint(equalTo: rightGroupView.trailingAnchor),
        ])
    }

    // MARK: - Theme

    func updateTheme() {
        guard let tm = ThemeManager.shared else { return }

        // Group backgrounds
        let groupBg = tm.color(fromLightRGB: 0xE3E6E0, sepiaRGB: 0xEADFD0, mediumRGB: 0x444444, darkRGB: 0x2A2A2A)
        leftGroupView.backgroundColor = groupBg
        rightGroupView.backgroundColor = groupBg

        // Separators
        let sep = tm.color(fromLightRGB: 0xCED0CC, sepiaRGB: 0xD4C8B8, mediumRGB: 0x555555, darkRGB: 0x3A3A3A)
        leftSeparator.backgroundColor = sep
        rightSeparator.backgroundColor = sep

        // Button tint (icon + text color)
        let tint = tm.color(fromLightRGB: 0x555555, sepiaRGB: 0x6A5A4A, mediumRGB: 0xAAAAAA, darkRGB: 0xAAAAAA)
        for btn in [textButton, sendButton, previousButton, nextButton] {
            btn.tintColor = tint
            if var config = btn.configuration {
                config.baseForegroundColor = tint
                btn.configuration = config
            }
        }

        // Text active highlight
        let activeBg = tm.color(fromLightRGB: 0xD0D5CC, sepiaRGB: 0xDDD0C0, mediumRGB: 0x555555, darkRGB: 0x404040)
        textActiveHighlight.backgroundColor = activeBg

        // Progress circle
        let progressTint = tm.color(fromLightRGB: 0x808080, sepiaRGB: 0x8B7B6B, mediumRGB: 0x888888, darkRGB: 0x888888)
        circularProgressView.progressColor = progressTint?.withAlphaComponent(0.5)
        let progressBg = tm.color(fromLightRGB: 0xC0C0C0, sepiaRGB: 0xC0B0A0, mediumRGB: 0x555555, darkRGB: 0x444444)
        circularProgressView.progressBackgroundColor = progressBg?.withAlphaComponent(0.3)

        loadingIndicator.color = tint
    }

    // MARK: - State Updates

    func updatePreviousEnabled(_ enabled: Bool) {
        previousButton.isEnabled = enabled
        previousButton.alpha = enabled ? 1.0 : 0.35
    }

    func updateNextShowDone(_ showDone: Bool) {
        guard var config = nextButton.configuration else { return }
        if showDone {
            config.title = "Done"
            config.image = sym("checkmark", size: 12, weight: .semibold)
        } else {
            config.title = "Next"
            config.image = sym("chevron.right", size: 12, weight: .semibold)
        }
        config.imagePlacement = .trailing
        config.imagePadding = 4

        let tint = ThemeManager.shared?.color(fromLightRGB: 0x555555, sepiaRGB: 0x6A5A4A, mediumRGB: 0xAAAAAA, darkRGB: 0xAAAAAA)
        config.baseForegroundColor = tint
        nextButton.configuration = config
    }

    func updateProgress(_ percentage: Float) {
        circularProgressView.percentage = CGFloat(percentage)
    }

    func updateTextInTextView(_ inTextView: Bool, enabled: Bool) {
        textButton.isEnabled = enabled
        textButton.alpha = enabled ? 1.0 : 0.4

        guard var config = textButton.configuration else { return }
        if inTextView {
            config.title = "Story"
            config.image = sym("doc.richtext")
        } else {
            config.title = "Text"
            config.image = sym("doc.plaintext")
        }

        let tint = ThemeManager.shared?.color(fromLightRGB: 0x555555, sepiaRGB: 0x6A5A4A, mediumRGB: 0xAAAAAA, darkRGB: 0xAAAAAA)
        config.baseForegroundColor = tint
        textButton.configuration = config

        UIView.animate(withDuration: 0.15) {
            self.textActiveHighlight.alpha = inTextView ? 1.0 : 0.0
        }
    }

    func updateSendEnabled(_ enabled: Bool) {
        sendButton.isEnabled = enabled
        sendButton.alpha = enabled ? 1.0 : 0.4
    }
}
