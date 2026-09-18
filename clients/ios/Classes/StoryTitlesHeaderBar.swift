//
//  StoryTitlesHeaderBar.swift
//  NewsBlur
//
//  Created by Samuel Clay on 2026-02-23.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import UIKit

// StoryTitlesHeaderBar.swift keeps UIKit configuration updates from making toolbar labels multiline.
private class StoryTitlesPillButton: UIButton {
    override func layoutSubviews() {
        titleLabel?.numberOfLines = 1
        titleLabel?.lineBreakMode = .byClipping
        super.layoutSubviews()
        titleLabel?.numberOfLines = 1
    }
}

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

    // StoryTitlesHeaderBar.swift defaults to the bottom on iPhone and iPad.
    private(set) var usesFloatingBottomBar = StoryTitlesHeaderBar.prefersBottomBar
    private static var prefersBottomBar: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        let defaultPosition = "bottom"
        return (UserDefaults.standard.string(forKey: "story_toolbar_position") ?? defaultPosition) == "bottom"
        #endif
    }

    private let contentTopGuide = UILayoutGuide()
    private let contentBottomGuide = UILayoutGuide()
    var contentTopAnchor: NSLayoutYAxisAnchor { contentTopGuide.topAnchor }
    var contentBottomAnchor: NSLayoutYAxisAnchor { contentBottomGuide.topAnchor }
    private var positionConstraints: [NSLayoutConstraint] = []
    private var pillLayoutConstraints: [NSLayoutConstraint] = []
    let leadingToolbarGroup = UIVisualEffectView()
    let trailingToolbarGroup = UIVisualEffectView()
    let mergedToolbarGroup = UIVisualEffectView()
    private(set) var usesMergedToolbar = false
    private var groupPaddingConstraints: [NSLayoutConstraint] = []
    private var minimumPillWidths: [NSLayoutConstraint] = []
    private var optionsMinimumWidthConstraint: NSLayoutConstraint?

    @objc private func toolbarPreferenceChanged() {
        guard Self.prefersBottomBar != usesFloatingBottomBar,
              let parent = headerContainer.superview else { return }
        usesFloatingBottomBar = Self.prefersBottomBar
        refreshGlassMaterial()
        measureOptionsWidths()
        NSLayoutConstraint.deactivate(positionConstraints + pillLayoutConstraints)
        buildLayout(in: headerContainer)
        configurePosition(in: parent)
        for view in [discoverPill, optionsPill, searchPill, markReadContainer] {
            view.constraints.first { $0.firstAttribute == .height && $0.secondItem == nil }?.constant = usesFloatingBottomBar ? 44 : 28
        }
        minimumPillWidths.forEach { $0.constant = usesFloatingBottomBar ? 44 : 0 }
        setSearchActive(isSearchActive)
        updateTheme()
        parent.setNeedsLayout()
        parent.layoutIfNeeded()
        relayoutPills()
    }

    private func configurePosition(in parent: UIView) {
        positionConstraints = [
            usesFloatingBottomBar
                ? headerContainer.bottomAnchor.constraint(equalTo: parent.keyboardLayoutGuide.topAnchor, constant: -8)
                : headerContainer.topAnchor.constraint(equalTo: parent.topAnchor),
            contentTopGuide.topAnchor.constraint(equalTo: usesFloatingBottomBar ? parent.topAnchor : headerContainer.bottomAnchor),
            contentBottomGuide.topAnchor.constraint(equalTo: usesFloatingBottomBar ? headerContainer.topAnchor : parent.safeAreaLayoutGuide.bottomAnchor)
        ]
        NSLayoutConstraint.activate(positionConstraints)
    }

    // StoryTitlesHeaderBar.swift anchors popovers above the capsule with room to dismiss from the bar.
    func popoverSourceRect(for source: UIView) -> CGRect {
        guard usesFloatingBottomBar else { return source.bounds }
        let top = pillBar.convert(CGPoint(x: 0, y: 4), to: source).y
        return CGRect(x: 0, y: top - 8, width: source.bounds.width, height: 1)
    }

    let pillBar = UIView()

    let discoverPill = StoryTitlesHeaderBar.makePillButton()
    let optionsPill = StoryTitlesHeaderBar.makePillButton()
    let searchPill = StoryTitlesHeaderBar.makePillButton()
    let markReadContainer = UIView()
    let markReadExpandButton = StoryTitlesHeaderBar.makePillButton()
    let markReadPill = StoryTitlesHeaderBar.makePillButton()

    /// Container for the search field, sits below the pill bar.
    let searchContainer = UIView()
    /// Cancel button (X) inside the search container.
    let searchCancelButton = StoryTitlesHeaderBar.makePillButton()

    /// On Catalyst, use `.custom` type to avoid AppKit button chrome that
    /// overrides sizing and colors. On iOS, `.system` works well with Configuration.
    private static func makePillButton() -> UIButton {
        #if targetEnvironment(macCatalyst)
        return StoryTitlesPillButton(type: .custom)
        #else
        let button = StoryTitlesPillButton(type: .system)
        button.isPointerInteractionEnabled = true
        return button
        #endif
    }

    // MARK: - Private Views

    private let pillStack = UIStackView()
    private let leadingControls = UIStackView()
    private let spacer = UIView()
    private let markReadDivider = UIView()
    private var faviconViews: [UIImageView] = []
    private var storedFavicons: [UIImage] = []
    private var discoverWidthConstraint: NSLayoutConstraint?
    private var headerHeightConstraint: NSLayoutConstraint?
    private var markReadWidthConstraint: NSLayoutConstraint?
    private var isSearchCompact = false
    private var isDailyBriefingMode = false
    private var filterText = "ALL"
    private var orderText = "NEWEST"
    private var fullOptionsWidth: CGFloat = 0
    private var compactOptionsWidth: CGFloat = 0
    private let markReadWidth: CGFloat = 98
    private var markReadMenuTitle = "all stories"
    private var markReadMenuVisibleCount = 0
    private var appliedDiscoverLayout: String?
    private lazy var optionsIconWidth = measuredPillWidth(title: nil, image: sym("chevron.down", size: 8, weight: .bold), leadingInset: 12, trailingInset: 12)
    private lazy var relatedIconWidth = measuredPillWidth(title: nil, image: discoverImage, leadingInset: 14, trailingInset: 14)
    private lazy var relatedTextWidth = measuredPillWidth(title: "RELATED SITES", image: discoverImage, leadingInset: 14, trailingInset: 12)
    private lazy var briefingTextWidth = measuredPillWidth(title: "BRIEFING SETTINGS", image: dailyBriefingPillImage(), leadingInset: 14, trailingInset: 12)
    private lazy var searchIconWidth = measuredPillWidth(title: nil, image: sym("magnifyingglass", size: 12), leadingInset: 14, trailingInset: 14)
    private lazy var searchTextWidth = measuredPillWidth(title: "SEARCH", image: sym("magnifyingglass", size: 11), leadingInset: 14, trailingInset: 14)
    private lazy var discoverImage = UIImage(named: "discover").map { resizedImage($0, to: CGSize(width: 14, height: 14)) }

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

    /// StoryTitlesHeaderBar.swift measures an unconstrained button with the same platform API as the displayed pills.
    private func measuredPillWidth(title: String?, image: UIImage?, trailingImage: Bool = false,
                                   leadingInset: CGFloat, trailingInset: CGFloat) -> CGFloat {
        let button = Self.makePillButton()
        setPillContent(button, title: title, image: image, trailingImage: trailingImage,
                       leadingInset: leadingInset, trailingInset: trailingInset, lineBreakMode: .byClipping)
        return ceil(button.intrinsicContentSize.width)
    }

    private func measureOptionsWidths() {
        let image = sym("chevron.down", size: 8, weight: .bold)
        fullOptionsWidth = measuredPillWidth(title: "\(filterText) · \(orderText)", image: image,
                                             trailingImage: true, leadingInset: 16, trailingInset: 14)
        compactOptionsWidth = measuredPillWidth(title: filterText, image: image,
                                                trailingImage: true, leadingInset: usesFloatingBottomBar ? 10 : 16,
                                                trailingInset: usesFloatingBottomBar ? 8 : 14)
    }

    private func dailyBriefingPillImage() -> UIImage? {
        UIImage(named: "briefing").map { resizedImage($0, to: CGSize(width: 14, height: 14)) }
    }

    private func applyDailyBriefingPill(compact: Bool) {
        setPillContent(
            discoverPill,
            title: compact ? nil : "BRIEFING SETTINGS",
            image: dailyBriefingPillImage(),
            leadingInset: 14,
            trailingInset: compact ? 14 : 12,
            lineBreakMode: .byClipping
        )
        discoverPill.contentHorizontalAlignment = .center
        discoverPill.accessibilityLabel = "Daily Briefing Settings"
    }

    // MARK: - Platform-Adaptive Pill API

    private var usesNativeGlass: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        if #available(iOS 26.0, *) { return usesFloatingBottomBar }
        return false
        #endif
    }

    // StoryTitlesHeaderBar.swift changes material only when the toolbar's layout mode changes, never while stories paginate.
    private func refreshGlassMaterial() {
        #if !targetEnvironment(macCatalyst)
        for group in [leadingToolbarGroup, trailingToolbarGroup, mergedToolbarGroup] {
            let effect: UIVisualEffect
            if #available(iOS 26.0, *) {
                let interactiveGlass = UIGlassEffect(style: .regular)
                interactiveGlass.isInteractive = true
                effect = interactiveGlass
            } else {
                effect = UIBlurEffect(style: .systemChromeMaterial)
            }
            let isActiveSurface = group === mergedToolbarGroup ? usesMergedToolbar : !usesMergedToolbar
            group.effect = usesFloatingBottomBar && isActiveSurface ? effect : nil
            group.layer.cornerRadius = usesFloatingBottomBar ? 22 : 0
        }
        groupPaddingConstraints.forEach { $0.constant = usesFloatingBottomBar ? 4 : 0 }
        pillStack.spacing = usesFloatingBottomBar ? 4 : 6
        #endif
    }

    /// Sets pill button content. On iOS uses UIButton.Configuration; on Catalyst uses
    /// the legacy button API since Configuration ignores contentInsets, imagePlacement,
    /// and contentHorizontalAlignment on Catalyst.
    private func setPillContent(_ button: UIButton,
                                title: String?,
                                image: UIImage?,
                                trailingImage: Bool = false,
                                imagePadding: CGFloat = 4,
                                leadingInset: CGFloat,
                                trailingInset: CGFloat,
                                lineBreakMode: NSLineBreakMode = .byClipping) {
        #if targetEnvironment(macCatalyst)
        button.configuration = nil
        button.setTitle(title, for: .normal)
        button.setImage(image?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.titleLabel?.font = pillFont
        button.titleLabel?.lineBreakMode = lineBreakMode
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: leadingInset, bottom: 0, right: trailingInset)
        button.semanticContentAttribute = trailingImage ? .forceRightToLeft : .unspecified
        if image != nil && title != nil {
            let half = imagePadding / 2
            if trailingImage {
                button.imageEdgeInsets = UIEdgeInsets(top: 0, left: half, bottom: 0, right: -half)
                button.titleEdgeInsets = UIEdgeInsets(top: 0, left: -half, bottom: 0, right: half)
            } else {
                button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -half, bottom: 0, right: half)
                button.titleEdgeInsets = UIEdgeInsets(top: 0, left: half, bottom: 0, right: -half)
            }
        } else {
            button.imageEdgeInsets = .zero
            button.titleEdgeInsets = .zero
        }
        #else
        var config = button.configuration ?? UIButton.Configuration.plain()
        config.title = title
        config.image = image
        config.imagePlacement = trailingImage ? .trailing : .leading
        config.imagePadding = image != nil && title != nil ? imagePadding : 0
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: leadingInset, bottom: 0, trailing: trailingInset)
        if title != nil {
            config.titleTextAttributesTransformer = pillFontTransformer()
            config.titleLineBreakMode = lineBreakMode
        }
        button.configuration = config
        #endif
    }

    /// Updates pill foreground/background colors for the current platform.
    private func setPillColors(_ button: UIButton, bg: UIColor?, tint: UIColor?) {
        if button.backgroundColor != bg { button.backgroundColor = bg }
        if button.tintColor != tint { button.tintColor = tint }
        #if targetEnvironment(macCatalyst)
        button.setTitleColor(tint, for: .normal)
        #else
        if var config = button.configuration {
            let configurationBackground = pillStateBackground(button, normal: bg)
            let backgroundChanged = config.background.backgroundColor != configurationBackground
            guard backgroundChanged || config.baseForegroundColor != tint else { return }
            config.background.backgroundColor = configurationBackground
            config.baseForegroundColor = tint
            button.configuration = config
        }
        #endif
    }

    // MARK: - Setup

    /// Builds the pill bar and adds it as a fixed view at the top of the parent view.
    /// Returns the headerContainer's bottomAnchor for pinning content views below.
    func setup(in parentView: UIView) {
        if #available(iOS 17.0, *) {
            parentView.keyboardLayoutGuide.usesBottomSafeArea = false
        }
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.clipsToBounds = false
        parentView.addSubview(headerContainer)
        parentView.addLayoutGuide(contentTopGuide)
        parentView.addLayoutGuide(contentBottomGuide)

        headerContainer.onBoundsChange = { [weak self] in
            self?.relayoutPills()
        }

        buildPillBar(in: headerContainer)
        buildSearchContainer(in: headerContainer)
        buildLayout(in: headerContainer)
        updateTheme()

        let heightConstraint = headerContainer.heightAnchor.constraint(equalToConstant: usesFloatingBottomBar ? 52 : 36)
        headerHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            headerContainer.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            headerContainer.trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            heightConstraint,
        ])
        configurePosition(in: parentView)
        NotificationCenter.default.addObserver(self, selector: #selector(toolbarPreferenceChanged),
            name: UserDefaults.didChangeNotification, object: nil)
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
        mergedToolbarGroup.translatesAutoresizingMaskIntoConstraints = false
        pillBar.addSubview(mergedToolbarGroup)
        mergedToolbarGroup.contentView.addSubview(pillStack)
        NSLayoutConstraint.activate([
            mergedToolbarGroup.topAnchor.constraint(equalTo: pillBar.topAnchor, constant: 4),
            mergedToolbarGroup.bottomAnchor.constraint(equalTo: pillBar.bottomAnchor, constant: -4)
        ])
        leadingControls.axis = .horizontal
        leadingControls.spacing = 6
        leadingControls.alignment = .center
        leadingControls.translatesAutoresizingMaskIntoConstraints = false
        leadingControls.setContentHuggingPriority(.required, for: .horizontal)
        leadingToolbarGroup.contentView.addSubview(leadingControls)
        pillStack.addArrangedSubview(leadingToolbarGroup)

        buildDiscoverPill()
        buildOptionsPill()
        buildSearchPill()

        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        pillStack.addArrangedSubview(spacer)

        buildMarkReadPill()
        trailingToolbarGroup.contentView.addSubview(markReadContainer)
        pillStack.addArrangedSubview(trailingToolbarGroup)
        // StoryTitlesHeaderBar.swift gives each side its own glass surface, leaving stories visible between them.
        for (group, controls) in [(leadingToolbarGroup, leadingControls as UIView), (trailingToolbarGroup, markReadContainer)] {
            group.translatesAutoresizingMaskIntoConstraints = false
            group.setContentHuggingPriority(.required, for: .horizontal)
            group.setContentCompressionResistancePriority(.required, for: .horizontal)
            groupPaddingConstraints += [
                controls.leadingAnchor.constraint(equalTo: group.contentView.leadingAnchor),
                group.contentView.trailingAnchor.constraint(equalTo: controls.trailingAnchor)
            ]
            NSLayoutConstraint.activate([
                controls.topAnchor.constraint(equalTo: group.contentView.topAnchor),
                controls.bottomAnchor.constraint(equalTo: group.contentView.bottomAnchor)
            ])
        }
        NSLayoutConstraint.activate(groupPaddingConstraints)
        refreshGlassMaterial()
    }

    private func configurePillAppearance(_ button: UIButton) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = usesFloatingBottomBar ? 22 : 14
        button.layer.cornerCurve = .continuous
        button.layer.borderWidth = 1.0 / UIScreen.main.scale
        button.clipsToBounds = !usesNativeGlass
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.lineBreakMode = .byClipping
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        // StoryTitlesHeaderBar.swift keeps icon-only controls directly tappable inside each glass group.
        let minimumWidth = button.widthAnchor.constraint(greaterThanOrEqualToConstant: usesFloatingBottomBar ? 44 : 0)
        minimumWidth.isActive = true
        minimumPillWidths.append(minimumWidth)
        if button === optionsPill {
            optionsMinimumWidthConstraint = minimumWidth
        }
        addCatalystHighlight(button)
    }

    /// On Catalyst, `.custom` buttons have no automatic press highlight,
    /// so add manual alpha dimming on touch events.
    private func addCatalystHighlight(_ button: UIButton) {
        #if targetEnvironment(macCatalyst)
        button.addTarget(self, action: #selector(pillTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(pillTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        #else
        // StoryTitlesHeaderBar.swift gives each pressed action a visible highlight within the shared glass surface.
        button.configurationUpdateHandler = { [weak self] button in
            guard let self, var configuration = button.configuration else { return }
            let background = self.pillStateBackground(button, normal: button.backgroundColor)
            guard configuration.background.backgroundColor != background else { return }
            configuration.background.backgroundColor = background
            button.configuration = configuration
        }
        #endif
    }

    private func pillStateBackground(_ button: UIButton, normal: UIColor?) -> UIColor? {
        if usesFloatingBottomBar, button.isEnabled, button.isHighlighted {
            return toolbarForegroundColor?.withAlphaComponent(0.16)
        }
        return normal ?? .clear
    }

    @objc private func pillTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.08) { sender.alpha = 0.5 }
    }

    @objc private func pillTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2) { sender.alpha = 1.0 }
    }

    private func buildDiscoverPill() {
        let discoverImage = UIImage(named: "discover").map { resizedImage($0, to: CGSize(width: 14, height: 14)) }
        setPillContent(discoverPill, title: "RELATED SITES", image: discoverImage,
                       leadingInset: 14, trailingInset: 12, lineBreakMode: .byClipping)
        configurePillAppearance(discoverPill)
        discoverPill.accessibilityLabel = "Related Sites"
        discoverPill.setContentCompressionResistancePriority(.required, for: .horizontal)
        leadingControls.addArrangedSubview(discoverPill)

        NSLayoutConstraint.activate([
            discoverPill.heightAnchor.constraint(equalToConstant: usesFloatingBottomBar ? 44 : 28)
        ])
    }

    private func buildOptionsPill() {
        setPillContent(optionsPill, title: "ALL \u{00B7} NEWEST",
                       image: sym("chevron.down", size: 8, weight: .bold),
                       trailingImage: true, leadingInset: 16, trailingInset: 14)
        configurePillAppearance(optionsPill)
        measureOptionsWidths()
        optionsPill.setContentCompressionResistancePriority(.required, for: .horizontal)
        leadingControls.addArrangedSubview(optionsPill)

        NSLayoutConstraint.activate([
            optionsPill.heightAnchor.constraint(equalToConstant: usesFloatingBottomBar ? 44 : 28)
        ])
    }

    private func buildSearchPill() {
        setPillContent(searchPill, title: "SEARCH",
                       image: sym("magnifyingglass", size: 11),
                       leadingInset: 14, trailingInset: 14)
        configurePillAppearance(searchPill)
        searchPill.accessibilityLabel = "Search stories"
        searchPill.setContentCompressionResistancePriority(.required, for: .horizontal)
        leadingControls.addArrangedSubview(searchPill)

        NSLayoutConstraint.activate([
            searchPill.heightAnchor.constraint(equalToConstant: usesFloatingBottomBar ? 44 : 28)
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

        // Expand button ("+" on left) — tap shows day menu
        setPillContent(markReadExpandButton, title: nil,
                       image: sym("plus", size: 9, weight: .bold),
                       leadingInset: 12, trailingInset: 6)
        markReadExpandButton.translatesAutoresizingMaskIntoConstraints = false
        #if targetEnvironment(macCatalyst)
        markReadExpandButton.showsMenuAsPrimaryAction = true
        #else
        markReadExpandButton.addTarget(self, action: #selector(handleMarkReadExpand), for: .touchUpInside)
        #endif
        markReadExpandButton.accessibilityLabel = "Mark Read options"
        addCatalystHighlight(markReadExpandButton)
        markReadContainer.addSubview(markReadExpandButton)

        // Thin vertical divider
        markReadDivider.translatesAutoresizingMaskIntoConstraints = false
        markReadContainer.addSubview(markReadDivider)

        // Main button (mark-read icon on right) — tap marks all read
        let markReadImage = UIImage(named: "mark-read").map { resizedImage($0, to: CGSize(width: 22, height: 22)) }
        setPillContent(markReadPill, title: nil, image: markReadImage,
                       leadingInset: 15, trailingInset: 15)
        markReadPill.translatesAutoresizingMaskIntoConstraints = false
        addCatalystHighlight(markReadPill)
        markReadPill.accessibilityLabel = "Mark all read and return"
        #if !targetEnvironment(macCatalyst)
        markReadPill.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(handleMarkReadLongPress(_:))))
        #endif
        markReadContainer.addSubview(markReadPill)

        // Tap on main button fires markReadTapHandler
        markReadPill.addTarget(self, action: #selector(handleMarkReadTap), for: .touchUpInside)

        let widthConstraint = markReadContainer.widthAnchor.constraint(equalToConstant: markReadWidth)
        widthConstraint.priority = UILayoutPriority(999) // StoryTitlesHeaderBar.swift allows UIStackView to hide this compound control.
        markReadWidthConstraint = widthConstraint
        NSLayoutConstraint.activate([
            markReadContainer.heightAnchor.constraint(equalToConstant: usesFloatingBottomBar ? 44 : 28),
            widthConstraint,

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
        ])

        updateMarkReadMenu(title: "all stories")
    }

    @objc private func handleMarkReadTap() {
        markReadTapHandler?()
    }

    @objc private func handleMarkReadExpand() {
        presentMarkReadMenu(from: markReadExpandButton)
    }

    @objc private func handleMarkReadLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        presentMarkReadMenu(from: markReadPill)
    }

    private func presentMarkReadMenu(from button: UIButton) {
        guard button.isEnabled else { return }
        var responder: UIResponder? = headerContainer
        while let current = responder, !(current is UIViewController) { responder = current.next }
        guard let owner = responder as? UIViewController,
              let navigation = owner.navigationController ?? owner as? UINavigationController,
              navigation.presentedViewController == nil else { return }

        let menu = MenuViewController()
        // StoryTitlesHeaderBar.swift uses MenuViewController's sized icons because its cells center images at intrinsic size.
        menu.addFeedListTitle("Mark \(markReadMenuTitle) as read", iconName: "mark-read", selectionShouldDismiss: true) { [weak self] in
            self?.markReadHandler?(0)
        }
        if markReadMenuVisibleCount > 0 {
            let title = markReadMenuVisibleCount == 1 ? "Mark this story as read" : "Mark these \(markReadMenuVisibleCount) stories read"
            menu.addFeedListTitle(title, iconName: "mark-read", selectionShouldDismiss: true) { [weak self] in
                self?.markReadVisibleHandler?()
            }
        }
        for days in [1, 3, 7, 14] {
            menu.addFeedListTitle("Older than \(days) \(days == 1 ? "day" : "days")", iconName: "clock", selectionShouldDismiss: true) { [weak self] in
                self?.markReadHandler?(days)
            }
        }

        // StoryTitlesHeaderBar.swift anchors outside the interactive glass so a menu never morphs the entire footer.
        let buttonRect = button.convert(button.bounds, to: headerContainer)
        let sourceRect = usesFloatingBottomBar
            ? CGRect(x: buttonRect.minX, y: popoverSourceRect(for: headerContainer).minY, width: buttonRect.width, height: 1)
            : buttonRect
        menu.show(from: navigation, barButtonItem: nil, sourceView: headerContainer,
                  sourceRect: sourceRect, permittedArrowDirections: usesFloatingBottomBar ? .down : .up)
    }

    // MARK: - Search Container

    private func buildSearchContainer(in container: UIView) {
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.isHidden = true
        container.addSubview(searchContainer)

        #if targetEnvironment(macCatalyst)
        searchCancelButton.setImage(sym("xmark", size: 10, weight: .bold)?.withRenderingMode(.alwaysTemplate), for: .normal)
        searchCancelButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        #else
        var cancelConfig = UIButton.Configuration.plain()
        cancelConfig.image = sym("xmark", size: 10, weight: .bold)
        cancelConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        searchCancelButton.configuration = cancelConfig
        #endif
        searchCancelButton.translatesAutoresizingMaskIntoConstraints = false
        searchCancelButton.accessibilityLabel = "Close search"
        addCatalystHighlight(searchCancelButton)
        searchContainer.addSubview(searchCancelButton)

        NSLayoutConstraint.activate([
            searchCancelButton.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -8),
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
            field.topAnchor.constraint(equalTo: searchContainer.topAnchor, constant: 4),
            field.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: -4),
        ])
    }

    // MARK: - Layout

    private func buildLayout(in container: UIView) {
        let pillEdgeInset: CGFloat = usesFloatingBottomBar ? 16 : 8
        let searchEdgeInset: CGFloat = usesFloatingBottomBar ? 16 : 0

        pillLayoutConstraints = [
            mergedToolbarGroup.leadingAnchor.constraint(equalTo: pillBar.leadingAnchor, constant: searchEdgeInset),
            mergedToolbarGroup.trailingAnchor.constraint(equalTo: pillBar.trailingAnchor, constant: -searchEdgeInset),
            pillBar.leadingAnchor.constraint(equalTo: container.safeAreaLayoutGuide.leadingAnchor),
            pillBar.trailingAnchor.constraint(equalTo: container.safeAreaLayoutGuide.trailingAnchor),
            usesFloatingBottomBar
                ? pillBar.bottomAnchor.constraint(equalTo: container.bottomAnchor)
                : pillBar.topAnchor.constraint(equalTo: container.topAnchor),
            pillBar.heightAnchor.constraint(equalToConstant: usesFloatingBottomBar ? 52 : 36),

            pillStack.leadingAnchor.constraint(equalTo: pillBar.leadingAnchor, constant: pillEdgeInset),
            pillStack.trailingAnchor.constraint(equalTo: pillBar.trailingAnchor, constant: -pillEdgeInset),
            pillStack.topAnchor.constraint(equalTo: pillBar.topAnchor, constant: 4),
            pillStack.bottomAnchor.constraint(equalTo: pillBar.bottomAnchor, constant: -4),

            spacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 0),

            searchContainer.leadingAnchor.constraint(equalTo: pillBar.leadingAnchor, constant: searchEdgeInset),
            searchContainer.trailingAnchor.constraint(equalTo: pillBar.trailingAnchor, constant: -searchEdgeInset),
            usesFloatingBottomBar
                ? searchContainer.bottomAnchor.constraint(equalTo: pillBar.topAnchor)
                : searchContainer.topAnchor.constraint(equalTo: pillBar.bottomAnchor),
            searchContainer.heightAnchor.constraint(equalToConstant: 36),
        ]
        NSLayoutConstraint.activate(pillLayoutConstraints)
    }

    // MARK: - Theme

    func updateTheme() {
        guard let tm = ThemeManager.shared else { return }
        headerContainer.overrideUserInterfaceStyle = usesFloatingBottomBar ? (tm.isDarkTheme ? .dark : .light) : .unspecified

        let barBg = tm.color(fromLightRGB: 0xE3E6E0, sepiaRGB: 0xF3E2CB, mediumRGB: 0x333333, darkRGB: 0x222222)
        searchContainer.layer.cornerRadius = usesFloatingBottomBar ? 18 : 0
        markReadContainer.layer.borderWidth = usesFloatingBottomBar ? 0 : 1 / UIScreen.main.scale
        markReadContainer.layer.cornerRadius = usesFloatingBottomBar ? 22 : 14
        markReadContainer.clipsToBounds = !usesNativeGlass
        for button in [discoverPill, optionsPill, searchPill] {
            button.layer.cornerRadius = usesFloatingBottomBar ? 22 : 14
            button.layer.borderWidth = usesFloatingBottomBar ? 0 : 1 / UIScreen.main.scale
            button.clipsToBounds = !usesNativeGlass
        }
        pillBar.backgroundColor = usesFloatingBottomBar ? .clear : barBg
        searchContainer.backgroundColor = usesFloatingBottomBar ? barBg?.withAlphaComponent(0.95) : barBg

        let pillBg = tm.color(fromLightRGB: 0xE3E6E0, sepiaRGB: 0xEADFD0, mediumRGB: 0x444444, darkRGB: 0x2A2A2A)
        let borderColor = tm.color(fromLightRGB: 0xCED0CC, sepiaRGB: 0xD4C8B8, mediumRGB: 0x555555, darkRGB: 0x3A3A3A)
        let tint = toolbarForegroundColor

        // StoryTitlesHeaderBar.swift applies the final style once so page refreshes cannot flash opaque pills over glass.
        let inactivePillBg: UIColor? = usesFloatingBottomBar ? .clear : pillBg
        for pill in [discoverPill, optionsPill] {
            pill.layer.borderColor = borderColor?.cgColor
            setPillColors(pill, bg: inactivePillBg, tint: tint)
        }

        applySearchPillColors(active: isSearchActive)
        searchPill.layer.borderColor = searchPillBorderColor(active: isSearchActive)

        // Mark read compound pill
        markReadContainer.backgroundColor = inactivePillBg
        markReadContainer.layer.borderColor = borderColor?.cgColor
        markReadDivider.backgroundColor = borderColor

        for btn in [markReadExpandButton, markReadPill] {
            btn.tintColor = tint
            #if targetEnvironment(macCatalyst)
            // No configuration on Catalyst
            #else
            if var config = btn.configuration, config.baseForegroundColor != tint {
                config.baseForegroundColor = tint
                btn.configuration = config
            }
            #endif
        }

        searchCancelButton.tintColor = tint
    }

    func setDailyBriefingMode(_ enabled: Bool) {
        isDailyBriefingMode = enabled
        appliedDiscoverLayout = nil
        for fv in faviconViews { fv.removeFromSuperview() }
        faviconViews.removeAll()
        discoverWidthConstraint?.isActive = false
        discoverWidthConstraint = nil

        if enabled {
            applyDailyBriefingPill(compact: false)
            discoverPill.isHidden = false
            optionsPill.isHidden = false
            searchPill.isHidden = false
            markReadContainer.isHidden = false
        } else {
            let discoverImage = UIImage(named: "discover").map { resizedImage($0, to: CGSize(width: 14, height: 14)) }
            setPillContent(discoverPill, title: "RELATED SITES", image: discoverImage,
                           leadingInset: 14, trailingInset: 12, lineBreakMode: .byClipping)
            discoverPill.accessibilityLabel = "Related Sites"
            discoverPill.isHidden = false
            optionsPill.isHidden = false
            searchPill.isHidden = false
            markReadContainer.isHidden = false
        }

        relayoutPills()
        updateTheme()
    }

    // MARK: - State Updates

    /// Updates the options pill text to reflect current order and read filter.
    func updateOptionsPill(order: String, readFilter: String) {
        filterText = readFilter == "unread" ? "UNREAD" : "ALL"
        orderText = order == "oldest" ? "OLDEST" : "NEWEST"
        measureOptionsWidths()
        if headerContainer.bounds.width <= 0 { applyOptionsTitle(compact: false) }
        relayoutPills()
    }

    private func applyOptionsTitle(compact: Bool, iconOnly: Bool = false) {
        let fullTitle = "\(filterText) · \(orderText)"
        let title: String? = iconOnly ? nil : (compact ? filterText : fullTitle)
        let leadingInset: CGFloat = iconOnly ? 12 : (compact && usesFloatingBottomBar ? 10 : 16)
        let trailingInset: CGFloat = iconOnly ? 12 : (compact && usesFloatingBottomBar ? 8 : 14)
        optionsPill.accessibilityLabel = fullTitle
        #if targetEnvironment(macCatalyst)
        if optionsPill.title(for: .normal) != title { optionsPill.setTitle(title, for: .normal) }
        optionsPill.contentEdgeInsets = UIEdgeInsets(top: 0, left: leadingInset, bottom: 0, right: trailingInset)
        #else
        guard var config = optionsPill.configuration else { return }
        guard config.title != title || config.contentInsets.leading != leadingInset || config.contentInsets.trailing != trailingInset || config.titleLineBreakMode != .byClipping else { return }
        config.title = title
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: leadingInset, bottom: 0, trailing: trailingInset)
        config.imagePadding = iconOnly ? 0 : 4
        config.titleTextAttributesTransformer = pillFontTransformer()
        config.titleLineBreakMode = .byClipping
        optionsPill.configuration = config
        optionsPill.titleLabel?.numberOfLines = 1
        #endif
    }

    /// Updates the discover pill with favicon images or "DISCOVER" text.
    /// Stores favicons and checks available width; falls back to text if too tight.
    func updateDiscoverPill(favicons: [UIImage]) {
        storedFavicons = favicons
        appliedDiscoverLayout = nil
        relayoutPills()

        // Re-check after layout pass when bounds are known
        DispatchQueue.main.async { [weak self] in
            self?.relayoutPills()
        }
    }

    /// Called from ObjC after layout changes (e.g. rotation) to re-check pill fit.
    func relayoutPills() {
        trailingToolbarGroup.isHidden = markReadContainer.isHidden
        let barWidth = headerContainer.bounds.width - headerContainer.safeAreaInsets.left - headerContainer.safeAreaInsets.right
        let availableWidth = barWidth - (usesFloatingBottomBar ? 32 : 0)
        guard availableWidth > 0 else { return }

        // StoryTitlesHeaderBar.swift keeps separate glass groups when compact controls and a clear gap fit.
        let leadingCount = [discoverPill, optionsPill, searchPill].filter { !$0.isHidden }.count
        let minimumMarkReadWidth = ceil(26 + 1 / UIScreen.main.scale + 52)
        let compactControlsWidth = (discoverPill.isHidden ? 0 : max(44, relatedIconWidth)) +
            (optionsPill.isHidden ? 0 : max(44, optionsIconWidth)) +
            (searchPill.isHidden ? 0 : max(44, searchIconWidth)) +
            (markReadContainer.isHidden ? 0 : minimumMarkReadWidth)
        let splitWidth = compactControlsWidth + CGFloat(max(0, leadingCount - 1)) * leadingControls.spacing + 16 + 16
        let shouldMerge = usesFloatingBottomBar && availableWidth < splitWidth
        if usesMergedToolbar != shouldMerge {
            usesMergedToolbar = shouldMerge
            refreshGlassMaterial()
        }

        let visibleCount = [discoverPill, optionsPill, searchPill, markReadContainer].filter { !$0.isHidden }.count
        // StoryTitlesHeaderBar.swift counts only visible stack gaps, including the flexible spacer, and actual compound width.
        let gapsAndEdges = usesFloatingBottomBar
            ? CGFloat(max(0, leadingCount - 1)) * leadingControls.spacing + 16 + 8
            : CGFloat(visibleCount) * 6 + 16
        // StoryTitlesHeaderBar.swift reserves a centered 52-point checkmark target independently of the + button.
        var fixedWidth = gapsAndEdges + (markReadContainer.isHidden ? 0 : (usesFloatingBottomBar ? minimumMarkReadWidth : markReadWidth))
        let minimumDiscoverWidth = discoverPill.isHidden ? 0 : max(usesFloatingBottomBar ? 44 : 0, relatedIconWidth)
        let minimumSearchWidth = searchPill.isHidden ? 0 : max(usesFloatingBottomBar ? 44 : 0, searchIconWidth)
        let optionsSpace = availableWidth - fixedWidth - minimumDiscoverWidth - minimumSearchWidth
        let compactOptions = fullOptionsWidth > optionsSpace
        let iconOnlyOptions = compactOptions && compactOptionsWidth > optionsSpace
        applyOptionsTitle(compact: compactOptions, iconOnly: iconOnlyOptions)
        let minimumOptionsWidth = max(usesFloatingBottomBar ? 44 : 0, optionsIconWidth)
        let optionsWidth = optionsPill.isHidden ? 0 : (iconOnlyOptions ? minimumOptionsWidth : (compactOptions ? compactOptionsWidth : fullOptionsWidth))
        // StoryTitlesHeaderBar.swift restores the measured text width after an icon-only layout;
        // UIKit can otherwise retain the prior 44pt button frame when its configuration changes.
        let fittedOptionsWidth = max(usesFloatingBottomBar ? 44 : 0, optionsWidth)
        if optionsMinimumWidthConstraint?.constant != fittedOptionsWidth {
            optionsMinimumWidthConstraint?.constant = fittedOptionsWidth
        }
        if !markReadContainer.isHidden {
            let remainingWidth = availableWidth - gapsAndEdges - minimumDiscoverWidth - minimumSearchWidth - optionsWidth
            let fittedMarkReadWidth = max(minimumMarkReadWidth, min(markReadWidth, remainingWidth))
            if markReadWidthConstraint?.constant != fittedMarkReadWidth { markReadWidthConstraint?.constant = fittedMarkReadWidth }
            fixedWidth = gapsAndEdges + fittedMarkReadWidth
        }

        let discoverDisplay = UserDefaults.standard.string(forKey: "discover_display") ?? "with_icons"
        let faviconWidth = CGFloat(min(storedFavicons.count, 5)) * 14 + 36
        let prefersFavicons = !isDailyBriefingMode && discoverDisplay == "with_icons" && !storedFavicons.isEmpty
        // StoryTitlesHeaderBar.swift restores Search text as soon as it fits beside the compact discovery icon.
        let compactSearch = fixedWidth + optionsWidth + minimumDiscoverWidth + (searchPill.isHidden ? 0 : searchTextWidth) > availableWidth
        layoutSearchPill(compact: compactSearch)
        let searchWidth = searchPill.isHidden ? 0 : (compactSearch ? minimumSearchWidth : searchTextWidth)
        let discoverSpace = availableWidth - fixedWidth - optionsWidth - searchWidth

        if discoverPill.isHidden {
            discoverWidthConstraint?.isActive = false
            appliedDiscoverLayout = nil
            return
        }
        if isDailyBriefingMode {
            let compact = briefingTextWidth > discoverSpace
            let layout = compact ? "briefing-icon" : "briefing-text"
            guard appliedDiscoverLayout != layout else { return }
            appliedDiscoverLayout = layout
            applyDailyBriefingPill(compact: compact)
        } else {
            let showFavicons = prefersFavicons && faviconWidth <= discoverSpace
            let showText = !showFavicons && relatedTextWidth <= discoverSpace
            let layout = showFavicons ? "favicons" : (showText ? "related-text" : "related-icon")
            guard appliedDiscoverLayout != layout else { return }
            appliedDiscoverLayout = layout
            layoutDiscoverPill(showFavicons: showFavicons, showText: showText)
        }
    }

    // MARK: - Search Pill Adaptive Layout

    private func layoutSearchPill(compact: Bool) {
        guard compact != isSearchCompact else { return }
        isSearchCompact = compact
        setPillContent(searchPill, title: compact ? nil : "SEARCH",
                       image: sym("magnifyingglass", size: compact ? 12 : 11),
                       leadingInset: 14, trailingInset: 14)
        // StoryTitlesHeaderBar.swift preserves active search colors when replacing its content configuration.
        applySearchPillColors(active: isSearchActive)
    }

    // MARK: - Discover Pill Adaptive Layout

    private func layoutDiscoverPill(showFavicons: Bool, showText: Bool) {
        // Remove old favicon views
        for fv in faviconViews { fv.removeFromSuperview() }
        faviconViews.removeAll()

        // Remove old width constraint
        discoverWidthConstraint?.isActive = false
        discoverWidthConstraint = nil

        let favicons = storedFavicons

        if showFavicons {
            // Favicon mode: icon + up to 5 favicons
            let discoverImage = UIImage(named: "discover").map { resizedImage($0, to: CGSize(width: 14, height: 14)) }
            setPillContent(discoverPill, title: nil, image: discoverImage,
                           leadingInset: 14, trailingInset: 12)
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
        } else if showText {
            // Text mode: icon + "RELATED SITES"
            let discoverImage = UIImage(named: "discover").map { resizedImage($0, to: CGSize(width: 14, height: 14)) }
            setPillContent(discoverPill, title: "RELATED SITES", image: discoverImage,
                           leadingInset: 14, trailingInset: 12, lineBreakMode: .byClipping)
            discoverPill.contentHorizontalAlignment = .center
        } else {
            // Compact mode: icon only (like search pill)
            let discoverImage = UIImage(named: "discover").map { resizedImage($0, to: CGSize(width: 14, height: 14)) }
            setPillContent(discoverPill, title: nil, image: discoverImage,
                           leadingInset: 14, trailingInset: 14)
            discoverPill.contentHorizontalAlignment = .center
        }
    }

    /// Shows or hides the discover pill based on feed type and user preference.
    func updateDiscoverVisibility(isRiver: Bool, isEverything: Bool, isSocial: Bool, isSaved: Bool, isRead: Bool, isWidget: Bool, isInfrequent: Bool) {
        let discoverDisplay = UserDefaults.standard.string(forKey: "discover_display") ?? "with_icons"
        if discoverDisplay == "hidden" {
            discoverPill.isHidden = true
            relayoutPills()
            return
        }

        // Hide on all special views regardless of river mode
        let shouldHide = isEverything || isSocial || isSaved || isRead || isWidget || isInfrequent
        discoverPill.isHidden = shouldHide
        relayoutPills()
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
        markReadMenuTitle = title
        markReadMenuVisibleCount = showVisibleOption ? visibleCount : 0
        #if targetEnvironment(macCatalyst)
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
        #endif
    }

    /// Shows or hides the search field below the pill bar with animation.
    /// Slides the search container in/out by expanding/collapsing the header height.
    func setSearchActive(_ active: Bool) {
        let changed = isSearchActive != active
        isSearchActive = active

        let height: CGFloat = (usesFloatingBottomBar ? 52 : 36) + (active ? 36 : 0)

        if active {
            searchContainer.isHidden = false
            searchContainer.alpha = 1
        }

        // Skip animation when state isn't changing to avoid animating
        // unrelated pending constraint changes (e.g. initial layout).
        if changed {
            let duration: TimeInterval = active ? 0.25 : 0.4

            UIView.animate(withDuration: 0.3, delay: 0, options: active ? .curveEaseOut : .curveEaseIn) {
                self.headerHeightConstraint?.constant = height
                self.headerContainer.superview?.layoutIfNeeded()
            } completion: { _ in
                if !active {
                    self.searchContainer.isHidden = true
                }
            }

            // Animate the pill highlight via cross-dissolve on the button
            UIView.transition(with: searchPill, duration: duration, options: .transitionCrossDissolve) {
                self.applySearchPillColors(active: active)
            }

            // Animate border color via Core Animation (not covered by UIView.transition)
            let targetBorder = self.searchPillBorderColor(active: active)
            let borderAnim = CABasicAnimation(keyPath: "borderColor")
            borderAnim.fromValue = searchPill.layer.borderColor
            borderAnim.toValue = targetBorder
            borderAnim.duration = duration
            borderAnim.timingFunction = CAMediaTimingFunction(name: active ? .easeOut : .easeIn)
            searchPill.layer.add(borderAnim, forKey: "borderColor")
            searchPill.layer.borderColor = targetBorder
        } else {
            headerHeightConstraint?.constant = height
            applySearchPillColors(active: active)
            searchPill.layer.borderColor = searchPillBorderColor(active: active)
            if !active {
                searchContainer.isHidden = true
            }
        }
    }

    private var toolbarForegroundColor: UIColor? {
        guard let tm = ThemeManager.shared else { return nil }
        if usesFloatingBottomBar {
            return tm.color(fromLightRGB: 0x30352F, sepiaRGB: 0x493C2E, mediumRGB: 0xF2F2EE, darkRGB: 0xF2F2EE)
        }
        return tm.color(fromLightRGB: 0x555555, sepiaRGB: 0x6A5A4A, mediumRGB: 0xAAAAAA, darkRGB: 0xAAAAAA)
    }

    /// Applies both background and foreground colors to the search pill.
    private func applySearchPillColors(active: Bool) {
        guard let tm = ThemeManager.shared else { return }

        if active {
            let activeBg = tm.color(fromLightRGB: 0x4A89DC, sepiaRGB: 0x4A7EC0, mediumRGB: 0x4A78B0, darkRGB: 0x3A6898)
            setPillColors(searchPill, bg: activeBg, tint: .white)
        } else {
            let pillBg = tm.color(fromLightRGB: 0xE3E6E0, sepiaRGB: 0xEADFD0, mediumRGB: 0x444444, darkRGB: 0x2A2A2A)
            setPillColors(searchPill, bg: usesFloatingBottomBar ? .clear : pillBg, tint: toolbarForegroundColor)
        }
    }

    private func searchPillBorderColor(active: Bool) -> CGColor? {
        guard let tm = ThemeManager.shared else { return nil }

        if active {
            return tm.color(fromLightRGB: 0x3B72C0, sepiaRGB: 0x3B68A8, mediumRGB: 0x3A6090, darkRGB: 0x2A5078)?.cgColor
        } else {
            return tm.color(fromLightRGB: 0xCED0CC, sepiaRGB: 0xD4C8B8, mediumRGB: 0x555555, darkRGB: 0x3A3A3A)?.cgColor
        }
    }

    private func updateSearchPillHighlight(active: Bool) {
        applySearchPillColors(active: active)
        searchPill.layer.borderColor = searchPillBorderColor(active: active)
    }
}
