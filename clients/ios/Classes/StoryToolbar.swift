//
//  StoryToolbar.swift
//  NewsBlur
//
//  Created by Samuel Clay on 2026-02-24.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import UIKit

@objc protocol StoryToolbarDelegate: AnyObject {
    func toolbarDidTapBack()
    func toolbarDidTapSettings()
    func toolbarDidTapBrowser()
}

/// Custom toolbar that replaces the system navigation bar when fullscreen scroll-to-hide is active.
/// Pinned at the top of the view; translated upward via CGAffineTransform to hide.
@objcMembers
class StoryToolbar: UIView {

    // MARK: - Public

    weak var delegate: StoryToolbarDelegate?

    let backButton = UIButton(type: .system)
    let settingsButton = UIButton(type: .system)
    let browserButton = UIButton(type: .system)

    static let toolbarHeight: CGFloat = 44.0

    // MARK: - Private

    private let backImageView = UIImageView()
    private let backChevron = UIImageView()
    private let backLabel = UILabel()
    private let separator = UIView()

    private var buttonFont: UIFont {
        UIFont(name: "WhitneySSm-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
    }

    // MARK: - Setup

    func setup(in parentView: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = true
        parentView.addSubview(self)

        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            topAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.topAnchor),
            heightAnchor.constraint(equalToConstant: StoryToolbar.toolbarHeight),
        ])

        buildBackButton()
        buildRightButtons()
        buildSeparator()
        buildLayout()
        updateTheme()
    }

    // MARK: - Back Button

    private func buildBackButton() {
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        addSubview(backButton)

        // Chevron
        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        backChevron.image = UIImage(systemName: "chevron.left", withConfiguration: chevronConfig)
        backChevron.translatesAutoresizingMaskIntoConstraints = false
        backChevron.contentMode = .scaleAspectFit
        backButton.addSubview(backChevron)

        // Feed/folder icon
        backImageView.translatesAutoresizingMaskIntoConstraints = false
        backImageView.contentMode = .scaleAspectFit
        backButton.addSubview(backImageView)

        // Title label
        backLabel.translatesAutoresizingMaskIntoConstraints = false
        backLabel.font = buttonFont
        backLabel.lineBreakMode = .byTruncatingTail
        backButton.addSubview(backLabel)
    }

    // MARK: - Right Buttons

    private func buildRightButtons() {
        // Settings (gear) button
        let settingsImage = Utilities.imageNamed("settings", sized: 24)?
            .withRenderingMode(.alwaysTemplate)
        settingsButton.setImage(settingsImage, for: .normal)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        settingsButton.accessibilityLabel = "Story settings"
        addSubview(settingsButton)

        // Browser (original story) button
        let browserImage = Utilities.imageNamed("original_button.png", sized: 24)?
            .withRenderingMode(.alwaysTemplate)
        browserButton.setImage(browserImage, for: .normal)
        browserButton.translatesAutoresizingMaskIntoConstraints = false
        browserButton.addTarget(self, action: #selector(browserTapped), for: .touchUpInside)
        browserButton.accessibilityLabel = "Show original story"
        addSubview(browserButton)
    }

    // MARK: - Separator

    private func buildSeparator() {
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)
    }

    // MARK: - Layout

    private func buildLayout() {
        let iconSize: CGFloat = 22

        NSLayoutConstraint.activate([
            // Back button region
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            backButton.topAnchor.constraint(equalTo: topAnchor),
            backButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            backButton.trailingAnchor.constraint(lessThanOrEqualTo: settingsButton.leadingAnchor, constant: -8),

            // Chevron
            backChevron.leadingAnchor.constraint(equalTo: backButton.leadingAnchor, constant: 4),
            backChevron.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            backChevron.widthAnchor.constraint(equalToConstant: 14),
            backChevron.heightAnchor.constraint(equalToConstant: 20),

            // Feed/folder icon
            backImageView.leadingAnchor.constraint(equalTo: backChevron.trailingAnchor, constant: 6),
            backImageView.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            backImageView.widthAnchor.constraint(equalToConstant: iconSize),
            backImageView.heightAnchor.constraint(equalToConstant: iconSize),

            // Title label
            backLabel.leadingAnchor.constraint(equalTo: backImageView.trailingAnchor, constant: 6),
            backLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            backLabel.trailingAnchor.constraint(lessThanOrEqualTo: backButton.trailingAnchor),

            // Settings button
            settingsButton.trailingAnchor.constraint(equalTo: browserButton.leadingAnchor, constant: -4),
            settingsButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 44),
            settingsButton.heightAnchor.constraint(equalToConstant: 44),

            // Browser button
            browserButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            browserButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            browserButton.widthAnchor.constraint(equalToConstant: 44),
            browserButton.heightAnchor.constraint(equalToConstant: 44),

            // Bottom separator
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),
        ])
    }

    // MARK: - Theme

    func updateTheme() {
        guard let tm = ThemeManager.shared else { return }

        let bg = tm.color(fromLightRGB: 0xE3E6E0, sepiaRGB: 0xF3E2CB, mediumRGB: 0x333333, darkRGB: 0x222222)
        backgroundColor = bg

        let tint = tm.color(fromLightRGB: 0x8F918B, sepiaRGB: 0x8B7B6B, mediumRGB: 0xAEAFAF, darkRGB: 0xAEAFAF)
        backChevron.tintColor = tint
        backLabel.textColor = tint
        settingsButton.tintColor = tint
        browserButton.tintColor = tint

        let sepColor = tm.color(fromLightRGB: 0xCED0CC, sepiaRGB: 0xD4C8B8, mediumRGB: 0x555555, darkRGB: 0x3A3A3A)
        separator.backgroundColor = sepColor
    }

    // MARK: - Title

    func updateTitle(image: UIImage?, text: String?) {
        backImageView.image = image
        backImageView.isHidden = image == nil
        backLabel.text = text
    }

    // MARK: - Actions

    @objc private func backTapped() {
        delegate?.toolbarDidTapBack()
    }

    @objc private func settingsTapped() {
        delegate?.toolbarDidTapSettings()
    }

    @objc private func browserTapped() {
        delegate?.toolbarDidTapBrowser()
    }
}
