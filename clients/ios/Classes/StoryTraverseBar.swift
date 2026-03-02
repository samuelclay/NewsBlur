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
    /// Manual label and chevron for the Next button on Catalyst (Configuration layout is broken).
    private var nextLabelView: UILabel?
    private var nextChevronView: UIImageView?

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

    /// Extra horizontal padding needed on Mac Catalyst where buttons render tighter.
    private var macPadding: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 8
        #else
        return 0
        #endif
    }

    /// Additional inset for the outermost edge of each pill group on Catalyst.
    private var macEdgePadding: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 8
        #else
        return 0
        #endif
    }

    /// Extra gap near separators and the progress circle on Catalyst.
    private var macInnerPadding: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 8
        #else
        return 0
        #endif
    }

    // MARK: - Highlight Colors

    private var highlightColor: UIColor? {
        ThemeManager.shared?.color(fromLightRGB: 0xCDD2C8, sepiaRGB: 0xDDD0C0, mediumRGB: 0x555555, darkRGB: 0x3A3A3A)
    }

    private static let highlightTag = 9999

    private func installHighlightHandler(_ button: UIButton) {
        // Insert a plain UIView behind the button content for the press highlight.
        // UIButton.Configuration and button.backgroundColor are unreliable on Catalyst,
        // but a child UIView always renders its backgroundColor correctly.
        let hv = UIView()
        hv.translatesAutoresizingMaskIntoConstraints = false
        hv.backgroundColor = .clear
        hv.isUserInteractionEnabled = false
        hv.tag = StoryTraverseBar.highlightTag
        button.insertSubview(hv, at: 0)
        NSLayoutConstraint.activate([
            hv.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hv.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hv.topAnchor.constraint(equalTo: button.topAnchor),
            hv.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])

        button.addTarget(self, action: #selector(highlightDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(highlightUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @objc private func highlightDown(_ sender: UIButton) {
        sender.viewWithTag(StoryTraverseBar.highlightTag)?.backgroundColor = highlightColor
    }

    @objc private func highlightUp(_ sender: UIButton) {
        let hv = sender.viewWithTag(StoryTraverseBar.highlightTag)
        UIView.animate(withDuration: 0.15) {
            hv?.backgroundColor = .clear
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
        installHighlightHandler(textButton)
        installHighlightHandler(sendButton)
        installHighlightHandler(previousButton)
        installHighlightHandler(nextButton)

        // On Catalyst, buttons are inset from the pill edge; round their corners
        // so the highlight background matches the pill's inner curve.
        if macEdgePadding > 0 {
            let innerRadius: CGFloat = max(4, 12 - macEdgePadding)
            for btn in [textButton, sendButton, previousButton, nextButton] {
                btn.layer.cornerRadius = innerRadius
                btn.layer.cornerCurve = .continuous
                btn.clipsToBounds = true
            }
        }

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
        textConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 14 + macPadding, bottom: 0, trailing: 14 + macPadding)
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

        // Previous story button (icon only with generous padding)
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
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        var nextConfig = UIButton.Configuration.plain()
        nextConfig.title = "Next"
        nextConfig.titleTextAttributesTransformer = fontTransformer()
        #if targetEnvironment(macCatalyst)
        // UIButton.Configuration ignores layout on Catalyst (contentInsets,
        // contentHorizontalAlignment, imagePlacement all broken). Keep a Configuration
        // with invisible text so the button sizes properly; manual label/chevron provide
        // the visible content positioned via constraints.
        nextConfig.title = "Next"
        nextConfig.baseForegroundColor = .clear
        nextConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 6 + macPadding, bottom: 0, trailing: 14 + macPadding)
        nextButton.configuration = nextConfig
        nextButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        #else
        nextConfig.image = sym("chevron.right", size: 12, weight: .semibold)
        nextConfig.imagePlacement = .trailing
        nextConfig.imagePadding = 4
        nextConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 6 + macPadding, bottom: 0, trailing: 14 + macPadding)
        nextButton.configuration = nextConfig
        #endif
        rightGroupView.addSubview(nextButton)

        #if targetEnvironment(macCatalyst)
        // Label and chevron in rightGroupView on top of the invisible button.
        // isUserInteractionEnabled = false so taps pass through to the button.
        let nextLabel = UILabel()
        nextLabel.text = "Next"
        nextLabel.font = buttonFont
        nextLabel.translatesAutoresizingMaskIntoConstraints = false
        nextLabel.isUserInteractionEnabled = false
        rightGroupView.addSubview(nextLabel)
        nextLabelView = nextLabel

        let chevron = UIImageView(image: sym("chevron.right", size: 12, weight: .semibold))
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.contentMode = .scaleAspectFit
        chevron.isUserInteractionEnabled = false
        rightGroupView.addSubview(chevron)
        nextChevronView = chevron
        #endif
    }

    // MARK: - Constraints

    private func buildLayout(in container: UIView) {
        let groupHeight: CGFloat = 40

        NSLayoutConstraint.activate([
            // -- Left group positioning --
            leftGroupView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            leftGroupView.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -2),
            leftGroupView.heightAnchor.constraint(equalToConstant: groupHeight),

            // Text button fills left side (extra inset on Catalyst for visual balance)
            textButton.leadingAnchor.constraint(equalTo: leftGroupView.leadingAnchor, constant: macEdgePadding + (macEdgePadding > 0 ? 4 : 0)),
            textButton.topAnchor.constraint(equalTo: leftGroupView.topAnchor),
            textButton.bottomAnchor.constraint(equalTo: leftGroupView.bottomAnchor),

            // Text active highlight — anchored to the pill edge, not the button frame,
            // so it extends properly when the button is inset on Catalyst.
            textActiveHighlight.leadingAnchor.constraint(equalTo: leftGroupView.leadingAnchor, constant: 4),
            textActiveHighlight.trailingAnchor.constraint(equalTo: leftSeparator.leadingAnchor, constant: -4),
            textActiveHighlight.topAnchor.constraint(equalTo: leftGroupView.topAnchor, constant: 4),
            textActiveHighlight.bottomAnchor.constraint(equalTo: leftGroupView.bottomAnchor, constant: -4),

            // Left separator (extra gap after Text label on Catalyst)
            leftSeparator.leadingAnchor.constraint(equalTo: textButton.trailingAnchor, constant: macInnerPadding + (macInnerPadding > 0 ? 4 : 0)),
            leftSeparator.topAnchor.constraint(equalTo: leftGroupView.topAnchor, constant: 8),
            leftSeparator.bottomAnchor.constraint(equalTo: leftGroupView.bottomAnchor, constant: -8),
            leftSeparator.widthAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),

            // Send button (inset horizontally from pill edge on Catalyst)
            sendButton.leadingAnchor.constraint(equalTo: leftSeparator.trailingAnchor),
            sendButton.topAnchor.constraint(equalTo: leftGroupView.topAnchor),
            sendButton.bottomAnchor.constraint(equalTo: leftGroupView.bottomAnchor),
            sendButton.trailingAnchor.constraint(equalTo: leftGroupView.trailingAnchor, constant: -macEdgePadding),
            sendButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),

            // -- Right group positioning --
            rightGroupView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            rightGroupView.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -2),
            rightGroupView.heightAnchor.constraint(equalToConstant: groupHeight),
            rightGroupView.leadingAnchor.constraint(greaterThanOrEqualTo: leftGroupView.trailingAnchor, constant: 12),

            // Previous button (inset horizontally from pill edge on Catalyst)
            previousButton.leadingAnchor.constraint(equalTo: rightGroupView.leadingAnchor, constant: macEdgePadding),
            previousButton.topAnchor.constraint(equalTo: rightGroupView.topAnchor),
            previousButton.bottomAnchor.constraint(equalTo: rightGroupView.bottomAnchor),
            previousButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),

            // Right separator
            rightSeparator.leadingAnchor.constraint(equalTo: previousButton.trailingAnchor),
            rightSeparator.topAnchor.constraint(equalTo: rightGroupView.topAnchor, constant: 8),
            rightSeparator.bottomAnchor.constraint(equalTo: rightGroupView.bottomAnchor, constant: -8),
            rightSeparator.widthAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),

            // Progress circle (extra gap before circle on Catalyst)
            circularProgressView.leadingAnchor.constraint(equalTo: rightSeparator.trailingAnchor, constant: 8 + macInnerPadding),
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

            // Next button (inset horizontally from pill edge on Catalyst)
            nextButton.leadingAnchor.constraint(equalTo: circularProgressView.trailingAnchor, constant: 2),
            nextButton.topAnchor.constraint(equalTo: rightGroupView.topAnchor),
            nextButton.bottomAnchor.constraint(equalTo: rightGroupView.bottomAnchor),
        ])

        // Button extends to pill edge on both platforms
        NSLayoutConstraint.activate([
            nextButton.trailingAnchor.constraint(equalTo: rightGroupView.trailingAnchor, constant: -macEdgePadding),
        ])

        if let nextLabel = nextLabelView, let chevron = nextChevronView {
            // Catalyst: anchor from pill trailing edge backward to guarantee padding
            NSLayoutConstraint.activate([
                chevron.trailingAnchor.constraint(equalTo: rightGroupView.trailingAnchor, constant: -(10 + macEdgePadding)),
                chevron.centerYAnchor.constraint(equalTo: rightGroupView.centerYAnchor),
                chevron.widthAnchor.constraint(equalToConstant: 10),
                chevron.heightAnchor.constraint(equalToConstant: 12),
                nextLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -6),
                nextLabel.centerYAnchor.constraint(equalTo: rightGroupView.centerYAnchor),
                nextLabel.leadingAnchor.constraint(greaterThanOrEqualTo: circularProgressView.trailingAnchor, constant: 8),
            ])
        }
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
                #if targetEnvironment(macCatalyst)
                // Keep nextButton text invisible; manual label provides visible text
                if btn != nextButton {
                    config.baseForegroundColor = tint
                }
                #else
                config.baseForegroundColor = tint
                #endif
                btn.configuration = config
            }
        }
        nextLabelView?.textColor = tint
        nextChevronView?.tintColor = tint

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
        let tint = ThemeManager.shared?.color(fromLightRGB: 0x555555, sepiaRGB: 0x6A5A4A, mediumRGB: 0xAAAAAA, darkRGB: 0xAAAAAA)

        #if targetEnvironment(macCatalyst)
        nextLabelView?.text = showDone ? "Done" : "Next"
        nextLabelView?.textColor = tint
        nextChevronView?.image = showDone ? sym("checkmark", size: 12, weight: .semibold) : sym("chevron.right", size: 12, weight: .semibold)
        nextChevronView?.tintColor = tint
        #else
        guard var config = nextButton.configuration else { return }
        config.title = showDone ? "Done" : "Next"
        config.image = showDone ? sym("checkmark", size: 12, weight: .semibold) : sym("chevron.right", size: 12, weight: .semibold)
        config.imagePlacement = .trailing
        config.imagePadding = 4
        config.baseForegroundColor = tint
        nextButton.configuration = config
        #endif
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
