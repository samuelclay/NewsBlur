//
//  StoryTitlesHeaderBar.swift
//  NewsBlur
//
//  Created by Samuel Clay on 2026-02-23.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import UIKit

/// Container view that notifies its owner when bounds change so pills can adapt.
class HeaderContainerView: UIView {
    var onBoundsChange: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onBoundsChange?()
    }
}

/// Builds and manages the story titles header pill bar above the story list.
/// Contains pills for Discover, Options, Search, and Mark Read.
/// When search is active, a search field appears below the pill bar.
@objcMembers
class StoryTitlesHeaderBar: NSObject {

    // MARK: - Public Views

    /// The outer container added to the parent view. Pin content views below this.
    let headerContainer = HeaderContainerView()

    let pillBar = UIView()
    let discoverPill = UIButton(type: .system)
    let optionsPill = UIButton(type: .system)
    let searchPill = UIButton(type: .system)
    let markReadContainer = UIView()
    let markReadExpandButton = UIButton(type: .system)
    let markReadPill = UIButton(type: .system)

    /// Container for the search field, sits below the pill bar.
    let searchContainer = UIView()
    /// Cancel button (X) inside the search container.
    let searchCancelButton = UIButton(type: .system)

    // MARK: - Private Views

    private let pillStack = UIStackView()
    private let spacer = UIView()
    private let markReadDivider = UIView()
    private var faviconViews: [UIImageView] = []
    private var storedFavicons: [UIImage] = []
    private var discoverWidthConstraint: NSLayoutConstraint?
    private var searchWidthConstraint: NSLayoutConstraint?
    private var headerHeightConstraint: NSLayoutConstraint?
    private var isSearchCompact = false

    // MARK: - State

    private(set) var isSearchActive = false

    /// Closure called when the mark-read pill is tapped (marks all read + pops back).
    var markReadTapHandler: (() -> Void)?

    /// Closure called when mark-read menu action is selected, passing number of days (0 = all).
    var markReadHandler: ((Int) -> Void)?

    /// Closure called when mark-read for visible stories is selected (days = -1).
    var markReadVisibleHandler: (() -> Void)?

    // MARK: - Helpers

    private var pillFont: UIFont {
        .systemFont(ofSize: 10, weight: .medium)
    }

    private func sym(_ name: String, size: CGFloat = 12, weight: UIImage.SymbolWeight = .medium) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: weight)
        return UIImage(systemName: name, withConfiguration: config)
    }

    private func pillFontTransformer() -> UIConfigurationTextAttributesTransformer {
        let font = self.pillFont
        return UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = font
            let ps = NSMutableParagraphStyle()
            ps.lineBreakMode = .byClipping
            out.paragraphStyle = ps
            return out
        }
    }

    private func resizedImage(_ image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(.alwaysTemplate)
    }

    // MARK: - Setup

    /// Builds the pill bar and adds it as a fixed view at the top of the parent view.
    /// Returns the headerContainer's bottomAnchor for pinning content views below.
    func setup(in parentView: UIView) {
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.clipsToBounds = true
        parentView.addSubview(headerContainer)

        headerContainer.onBoundsChange = { [weak self] in
            self?.relayoutPills()
        }

        buildPillBar(in: headerContainer)
        buildSearchContainer(in: headerContainer)
        buildLayout(in: headerContainer)
        updateTheme()

        let heightConstraint = headerContainer.heightAnchor.constraint(equalToConstant: 36)
        headerHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: parentView.topAnchor),
            headerContainer.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            heightConstraint,
        ])
    }

    // MARK: - Build Pills

    private func buildPillBar(in container: UIView) {
        pillBar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(pillBar)

        pillStack.axis = .horizontal
        pillStack.spacing = 6
        pillStack.alignment = .center
        pillStack.distribution = .fill
        pillStack.translatesAutoresizingMaskIntoConstraints = false
        pillBar.addSubview(pillStack)

        buildDiscoverPill()
        buildOptionsPill()
        buildSearchPill()

        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        pillStack.addArrangedSubview(spacer)

        buildMarkReadPill()
    }

    private func configurePillAppearance(_ button: UIButton) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 14
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = 1.0 / UIScreen.main.scale
        button.clipsToBounds = true
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.lineBreakMode = .byClipping
    }

    private func buildDiscoverPill() {
        var config = UIButton.Configuration.plain()
        if let discoverAsset = UIImage(named: "discover") {
            config.image = resizedImage(discoverAsset, to: CGSize(width: 14, height: 14))
        }
        config.title = "DISCOVER"
        config.imagePadding = 4
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 6)
        config.titleLineBreakMode = .byClipping
        config.titleTextAttributesTransformer = pillFontTransformer()
        discoverPill.configuration = config
        configurePillAppearance(discoverPill)
        discoverPill.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        pillStack.addArrangedSubview(discoverPill)

        NSLayoutConstraint.activate([
            discoverPill.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    private func buildOptionsPill() {
        var config = UIButton.Configuration.plain()
        config.title = "ALL \u{00B7} NEWEST"
        config.image = sym("chevron.down", size: 8, weight: .bold)
        config.imagePlacement = .trailing
        config.imagePadding = 4
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 6)
        config.titleTextAttributesTransformer = pillFontTransformer()
        optionsPill.configuration = config
        configurePillAppearance(optionsPill)
        optionsPill.setContentCompressionResistancePriority(.required, for: .horizontal)
        pillStack.addArrangedSubview(optionsPill)

        NSLayoutConstraint.activate([
            optionsPill.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    private func buildSearchPill() {
        var config = UIButton.Configuration.plain()
        config.image = sym("magnifyingglass", size: 11)
        config.title = "SEARCH"
        config.imagePadding = 4
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        config.titleTextAttributesTransformer = pillFontTransformer()
        searchPill.configuration = config
        configurePillAppearance(searchPill)
        searchPill.setContentCompressionResistancePriority(.required, for: .horizontal)
        pillStack.addArrangedSubview(searchPill)

        NSLayoutConstraint.activate([
            searchPill.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    private func buildMarkReadPill() {
        // Container with pill styling
        markReadContainer.translatesAutoresizingMaskIntoConstraints = false
        markReadContainer.layer.cornerRadius = 14
        markReadContainer.layer.cornerCurve = .continuous
        markReadContainer.layer.borderWidth = 1.0 / UIScreen.main.scale
        markReadContainer.clipsToBounds = true
        markReadContainer.setContentCompressionResistancePriority(.required, for: .horizontal)
        markReadContainer.setContentHuggingPriority(.required, for: .horizontal)
        pillStack.addArrangedSubview(markReadContainer)

        // Expand button ("+" on left) — tap shows day menu
        var expandConfig = UIButton.Configuration.plain()
        expandConfig.image = sym("plus", size: 9, weight: .bold)
        expandConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 4)
        markReadExpandButton.configuration = expandConfig
        markReadExpandButton.translatesAutoresizingMaskIntoConstraints = false
        markReadExpandButton.showsMenuAsPrimaryAction = true
        markReadContainer.addSubview(markReadExpandButton)

        // Thin vertical divider
        markReadDivider.translatesAutoresizingMaskIntoConstraints = false
        markReadContainer.addSubview(markReadDivider)

        // Main button (mark-read icon on right) — tap marks all read
        var mainConfig = UIButton.Configuration.plain()
        if let markReadAsset = UIImage(named: "mark-read") {
            mainConfig.image = resizedImage(markReadAsset, to: CGSize(width: 22, height: 22))
        }
        mainConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        markReadPill.configuration = mainConfig
        markReadPill.translatesAutoresizingMaskIntoConstraints = false
        // Menu without showsMenuAsPrimaryAction = long press shows menu
        markReadContainer.addSubview(markReadPill)

        // Tap on main button fires markReadTapHandler
        markReadPill.addTarget(self, action: #selector(handleMarkReadTap), for: .touchUpInside)

        NSLayoutConstraint.activate([
            markReadContainer.heightAnchor.constraint(equalToConstant: 28),
            markReadContainer.widthAnchor.constraint(equalToConstant: 82),

            markReadExpandButton.leadingAnchor.constraint(equalTo: markReadContainer.leadingAnchor),
            markReadExpandButton.topAnchor.constraint(equalTo: markReadContainer.topAnchor),
            markReadExpandButton.bottomAnchor.constraint(equalTo: markReadContainer.bottomAnchor),
            markReadExpandButton.widthAnchor.constraint(equalToConstant: 26),

            markReadDivider.leadingAnchor.constraint(equalTo: markReadExpandButton.trailingAnchor),
            markReadDivider.topAnchor.constraint(equalTo: markReadContainer.topAnchor, constant: 6),
            markReadDivider.bottomAnchor.constraint(equalTo: markReadContainer.bottomAnchor, constant: -6),
            markReadDivider.widthAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),

            markReadPill.leadingAnchor.constraint(equalTo: markReadDivider.trailingAnchor),
            markReadPill.topAnchor.constraint(equalTo: markReadContainer.topAnchor),
            markReadPill.bottomAnchor.constraint(equalTo: markReadContainer.bottomAnchor),
            markReadPill.trailingAnchor.constraint(equalTo: markReadContainer.trailingAnchor),
            markReadPill.widthAnchor.constraint(equalToConstant: 54),
        ])

        updateMarkReadMenu(title: "all stories")
    }

    @objc private func handleMarkReadTap() {
        markReadTapHandler?()
    }

    // MARK: - Search Container

    private func buildSearchContainer(in container: UIView) {
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.isHidden = true
        container.addSubview(searchContainer)

        var cancelConfig = UIButton.Configuration.plain()
        cancelConfig.image = sym("xmark", size: 10, weight: .bold)
        cancelConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        searchCancelButton.configuration = cancelConfig
        searchCancelButton.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(searchCancelButton)

        NSLayoutConstraint.activate([
            searchCancelButton.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -4),
            searchCancelButton.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchCancelButton.widthAnchor.constraint(equalToConstant: 32),
            searchCancelButton.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    /// Adds the given search field view to the search container with proper layout.
    func addSearchField(_ field: UIView) {
        field.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(field)

        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 8),
            field.trailingAnchor.constraint(equalTo: searchCancelButton.leadingAnchor, constant: -4),
            field.topAnchor.constraint(equalTo: searchContainer.topAnchor, constant: 2),
            field.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: -6),
        ])
    }

    // MARK: - Layout

    private func buildLayout(in container: UIView) {
        NSLayoutConstraint.activate([
            pillBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pillBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            pillBar.topAnchor.constraint(equalTo: container.topAnchor),
            pillBar.heightAnchor.constraint(equalToConstant: 36),

            pillStack.leadingAnchor.constraint(equalTo: pillBar.leadingAnchor, constant: 8),
            pillStack.trailingAnchor.constraint(equalTo: pillBar.trailingAnchor, constant: -8),
            pillStack.topAnchor.constraint(equalTo: pillBar.topAnchor, constant: 4),
            pillStack.bottomAnchor.constraint(equalTo: pillBar.bottomAnchor, constant: -4),

            spacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 0),

            searchContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            searchContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            searchContainer.topAnchor.constraint(equalTo: pillBar.bottomAnchor),
            searchContainer.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    // MARK: - Theme

    func updateTheme() {
        guard let tm = ThemeManager.shared else { return }

        let barBg = tm.color(fromLightRGB: 0xE3E6E0, sepiaRGB: 0xF3E2CB, mediumRGB: 0x333333, darkRGB: 0x222222)
        pillBar.backgroundColor = barBg
        searchContainer.backgroundColor = barBg

        let pillBg = tm.color(fromLightRGB: 0xE3E6E0, sepiaRGB: 0xEADFD0, mediumRGB: 0x444444, darkRGB: 0x2A2A2A)
        let borderColor = tm.color(fromLightRGB: 0xCED0CC, sepiaRGB: 0xD4C8B8, mediumRGB: 0x555555, darkRGB: 0x3A3A3A)
        let tint = tm.color(fromLightRGB: 0x555555, sepiaRGB: 0x6A5A4A, mediumRGB: 0xAAAAAA, darkRGB: 0xAAAAAA)

        for pill in [discoverPill, optionsPill, searchPill] {
            pill.backgroundColor = pillBg
            pill.layer.borderColor = borderColor?.cgColor

            if var config = pill.configuration {
                config.baseForegroundColor = tint
                pill.configuration = config
            }
        }

        // Mark read compound pill
        markReadContainer.backgroundColor = pillBg
        markReadContainer.layer.borderColor = borderColor?.cgColor
        markReadDivider.backgroundColor = borderColor

        for btn in [markReadExpandButton, markReadPill] {
            if var config = btn.configuration {
                config.baseForegroundColor = tint
                btn.configuration = config
            }
        }

        searchCancelButton.tintColor = tint
    }

    // MARK: - State Updates

    /// Updates the options pill text to reflect current order and read filter.
    func updateOptionsPill(order: String, readFilter: String) {
        let filterText = readFilter == "unread" ? "UNREAD" : "ALL"
        let orderText = order == "oldest" ? "OLDEST" : "NEWEST"
        let title = "\(filterText) \u{00B7} \(orderText)"

        guard var config = optionsPill.configuration else { return }
        config.title = title
        config.titleTextAttributesTransformer = pillFontTransformer()
        optionsPill.configuration = config
    }

    /// Updates the discover pill with favicon images or "DISCOVER" text.
    /// Stores favicons and checks available width; falls back to text if too tight.
    func updateDiscoverPill(favicons: [UIImage]) {
        storedFavicons = favicons
        relayoutPills()

        // Re-check after layout pass when bounds are known
        DispatchQueue.main.async { [weak self] in
            self?.relayoutPills()
        }
    }

    /// Called from ObjC after layout changes (e.g. rotation) to re-check pill fit.
    func relayoutPills() {
        layoutSearchPill()
        layoutDiscoverPill()
    }

    // MARK: - Search Pill Adaptive Layout

    /// Shows or hides the "SEARCH" text based on available width.
    private func layoutSearchPill() {
        let shouldBeCompact = !canFitSearchText()
        guard shouldBeCompact != isSearchCompact else { return }
        isSearchCompact = shouldBeCompact

        searchWidthConstraint?.isActive = false
        searchWidthConstraint = nil

        guard var config = searchPill.configuration else { return }

        if shouldBeCompact {
            // Icon only — wider pill, centered icon
            config.title = nil
            config.image = sym("magnifyingglass", size: 12)
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
        } else {
            // Icon + text
            config.title = "SEARCH"
            config.image = sym("magnifyingglass", size: 11)
            config.imagePadding = 4
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
            config.titleTextAttributesTransformer = pillFontTransformer()
        }
        searchPill.configuration = config
    }

    /// Returns true if the "SEARCH" text fits alongside other pills.
    private func canFitSearchText() -> Bool {
        let availableWidth = headerContainer.bounds.width
        guard availableWidth > 0 else { return true }

        // Calculate width needed with full search text
        let discoverWidth = discoverPill.isHidden ? 0 : estimateDiscoverWidth()
        let optionsWidth = optionsPill.isHidden ? 0 : optionsPill.intrinsicContentSize.width
        let searchFullWidth: CGFloat = 80 // icon + "SEARCH" + padding
        let markReadWidth: CGFloat = 96
        let gaps: CGFloat = 4 * 6
        let edges: CGFloat = 16

        let total = discoverWidth + optionsWidth + searchFullWidth + markReadWidth + gaps + edges
        return total <= availableWidth
    }

    /// Estimates the width the discover pill needs (text or favicon mode).
    private func estimateDiscoverWidth() -> CGFloat {
        if !storedFavicons.isEmpty {
            let maxFavicons = min(storedFavicons.count, 5)
            return CGFloat(maxFavicons) * 14 + 28 + 8
        } else {
            return discoverPill.intrinsicContentSize.width
        }
    }

    // MARK: - Discover Pill Adaptive Layout

    private func layoutDiscoverPill() {
        // Remove old favicon views
        for fv in faviconViews { fv.removeFromSuperview() }
        faviconViews.removeAll()

        // Remove old width constraint
        discoverWidthConstraint?.isActive = false
        discoverWidthConstraint = nil

        guard var config = discoverPill.configuration else { return }

        let favicons = storedFavicons
        let showFavicons = !favicons.isEmpty && canFitFavicons()

        if !showFavicons {
            // Text mode: icon + "DISCOVER"
            if let discoverAsset = UIImage(named: "discover") {
                config.image = resizedImage(discoverAsset, to: CGSize(width: 14, height: 14))
            }
            config.title = "DISCOVER"
            config.imagePadding = 4
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 6)
            config.titleLineBreakMode = .byClipping
            config.titleTextAttributesTransformer = pillFontTransformer()
            discoverPill.configuration = config
            discoverPill.contentHorizontalAlignment = .center
        } else {
            // Favicon mode: icon + up to 5 favicons
            config.title = nil
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 6)
            discoverPill.configuration = config
            discoverPill.contentHorizontalAlignment = .leading

            let maxFavicons = min(favicons.count, 5)
            for i in 0..<maxFavicons {
                let iv = UIImageView(image: favicons[i])
                iv.translatesAutoresizingMaskIntoConstraints = false
                iv.contentMode = .scaleAspectFit
                iv.layer.cornerRadius = 2
                iv.clipsToBounds = true
                iv.alpha = 0.7
                discoverPill.addSubview(iv)

                let offset: CGFloat = CGFloat(i) * 14 + 28
                NSLayoutConstraint.activate([
                    iv.widthAnchor.constraint(equalToConstant: 12),
                    iv.heightAnchor.constraint(equalToConstant: 12),
                    iv.centerYAnchor.constraint(equalTo: discoverPill.centerYAnchor),
                    iv.leadingAnchor.constraint(equalTo: discoverPill.leadingAnchor, constant: offset),
                ])

                faviconViews.append(iv)
            }

            let faviconWidth = CGFloat(maxFavicons) * 14 + 28 + 8
            let wc = discoverPill.widthAnchor.constraint(equalToConstant: faviconWidth)
            wc.isActive = true
            discoverWidthConstraint = wc
        }
    }

    /// Checks whether there is enough horizontal space for the favicon version of the discover pill.
    private func canFitFavicons() -> Bool {
        let availableWidth = headerContainer.bounds.width
        guard availableWidth > 0 else { return true }

        let maxFavicons = min(storedFavicons.count, 5)
        let faviconPillWidth: CGFloat = CGFloat(maxFavicons) * 14 + 28 + 8

        let optionsWidth = optionsPill.isHidden ? 0 : optionsPill.intrinsicContentSize.width
        // Use compact search width if already compact, otherwise estimate
        let searchWidth: CGFloat = isSearchCompact ? 38 : 80
        let markReadWidth: CGFloat = 96
        let gaps: CGFloat = 4 * 6
        let edges: CGFloat = 16

        let totalNeeded = faviconPillWidth + optionsWidth + searchWidth + markReadWidth + gaps + edges
        return totalNeeded <= availableWidth
    }

    /// Shows or hides the discover pill based on feed type.
    func updateDiscoverVisibility(isRiver: Bool, isEverything: Bool, isSocial: Bool, isSaved: Bool, isRead: Bool, isWidget: Bool, isInfrequent: Bool) {
        if !isRiver {
            // Single feed — always show discover
            discoverPill.isHidden = false
        } else {
            let shouldHide = isEverything || isSocial || isSaved || isRead || isWidget || isInfrequent
            discoverPill.isHidden = shouldHide
        }
    }

    /// Enables or disables the mark-read pill.
    func updateMarkReadEnabled(_ enabled: Bool) {
        markReadPill.isEnabled = enabled
        markReadExpandButton.isEnabled = enabled
        markReadContainer.alpha = enabled ? 1.0 : 0.4
    }

    /// Rebuilds the mark-read UIMenu with the given collection title (ObjC-friendly overload).
    func updateMarkReadMenu(title: String) {
        updateMarkReadMenuFull(title: title, showVisibleOption: false, visibleCount: 0)
    }

    /// Rebuilds the mark-read UIMenu with the given collection title.
    func updateMarkReadMenuFull(title: String, showVisibleOption: Bool, visibleCount: Int) {
        var actions: [UIMenuElement] = []

        actions.append(UIAction(title: "Mark \(title) as read", image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
            self?.markReadHandler?(0)
        })

        if showVisibleOption && visibleCount > 0 {
            let visibleTitle = visibleCount == 1 ? "Mark this story as read" : "Mark these \(visibleCount) stories read"
            actions.append(UIAction(title: visibleTitle, image: UIImage(systemName: "eye")) { [weak self] _ in
                self?.markReadVisibleHandler?()
            })
        }

        for days in [1, 3, 7, 14] {
            actions.append(UIAction(title: "Older than \(days) \(days == 1 ? "day" : "days")", image: UIImage(systemName: "calendar")) { [weak self] _ in
                self?.markReadHandler?(days)
            })
        }

        let menu = UIMenu(children: actions)
        markReadExpandButton.menu = menu
        markReadPill.menu = menu
    }

    /// Shows or hides the search field below the pill bar with animation.
    /// Slides the search container in/out by expanding/collapsing the header height.
    func setSearchActive(_ active: Bool) {
        let changed = isSearchActive != active
        isSearchActive = active

        let height: CGFloat = active ? 72 : 36

        if active {
            searchContainer.isHidden = false
            searchContainer.alpha = 1
        }

        // Skip animation when state isn't changing to avoid animating
        // unrelated pending constraint changes (e.g. initial layout).
        if changed {
            UIView.animate(withDuration: 0.3, delay: 0, options: active ? .curveEaseOut : .curveEaseIn) {
                self.headerHeightConstraint?.constant = height
                self.headerContainer.superview?.layoutIfNeeded()
            } completion: { _ in
                if !active {
                    self.searchContainer.isHidden = true
                }
            }
        } else {
            headerHeightConstraint?.constant = height
            if !active {
                searchContainer.isHidden = true
            }
        }
    }
}
